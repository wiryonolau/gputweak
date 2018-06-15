#!/bin/bash

#Global Variables
NVSMI='/usr/bin/nvidia-smi'
NVSET='/usr/bin/nvidia-settings'
ROCSMI='/usr/bin/rocm-smi'
PCI_REGEX='s/^\(..\):\(..\).\(.\).*/0x\1:0x\2:0x\3/p'
SYSID_REGEX=''
VERBOSE=0

#PCI_REGEX='/\(VGA compatible\|3D controller\).*\(AMD\|\NVIDIA\)/s/^\(..\):\(..\).\(.\).*/0x\1:0x\2:0x\3/p'
#SYSID_REGEX='\s(VGA compatible|3D controller).*(AMD|NVIDIA)'

function usage
{
    exit 0
}

function parse_args
{
    local _ARGS=()

    while [ "$1" ]
    do
        case "$1" in
            "-v" )
                VERBOSE=1
            ;;
        esac
        shift
    done
    
    set -- "${args[@]}"

    start_tweak $VERBOSE
    exit 0
}

function start_tweak
{
    #GET PCI ID FOR ALL NVIDIA/AMD GPU
    local _PCIIDS=$(lspci | sed -n -e "${PCI_REGEX}")

    while read -r _PCIID; do
        local _PCIBUS_XORG=$(parse_pciid "${_PCIID}" "xorg")
        local _PCIBUS=$(parse_pciid "${_PCIID}" "lspci")

        #GET SYSTEM ID
        local _IDS=$(lspci -vnn | grep -E "${_PCIBUS}${SYSID_REGEX}" -A1 | grep -Eo '([0-9a-z]{4}:[0-9a-z]{4})')
        _IDS=(${_IDS[@]})

        local _SYSTEM_ID=${_IDS[0]}
        local _SUBSYSTEM_ID=${_IDS[1]}

        #Test
        #local _SYSTEM_ID="10de:1b81"
        #local _SUBSYSTEM_ID="10de:119d"

        if [ -z "${_SYSTEM_ID}" ] || [ -z "${_SUBSYSTEM_ID}" ]; then
            if [ "$VERBOSE" = 1 ]; then
                printf "${_PCIBUS} device not recognize\r\n"
            fi
            continue
        fi

        if [ "$VERBOSE" = 1 ]; then
            printf "Tweaking device ${_SYSTEM_ID}, ${_SUBSYSTEM_ID}\r\n"
        fi

        #Parsing JSON config
        local _DRIVER=$(jq -r ".[] | select(.system_id==\"${_SYSTEM_ID}\" and .subsystem_id==\"${_SUBSYSTEM_ID}\") | .driver" config/gputweak.json)
        local _TWEAKS=$(jq -r ".[] | select(.system_id==\"${_SYSTEM_ID}\" and .subsystem_id==\"${_SUBSYSTEM_ID}\") | .tweaks" config/gputweak.json)
      
        if [ -z "${_DRIVER}" ] || [ -z "${_TWEAKS}" ]; then
            if [ "$VERBOSE" = 1 ]; then
                printf "Device ${_PCIBUS} with id ${_SYSTEM_ID}, subsystem id ${_SUBSYSTEM_ID} doesn't require tweak\r\n"
            fi
            continue
        fi

 
        if [ "$VERBOSE" = 1 ]; then
            printf "Driver : ${_DRIVER}\r\n"
            printf "Tweaks commands : \r\n${_TWEAKS}\r\n"
        fi
 
        case "${_DRIVER}" in
            "amdgpu" )
                tweak_amd "${_TWEAKS}" "${_PCIBUS_XORG}" "${_PCIBUS}"
                ;;
            "nvidia" )
                tweak_nvidia "${_TWEAKS}" "${_PCIBUS_XORG}" "${_PCIBUS}"
                ;; 
        esac
    done <<< "${_PCIIDS}"
}

function parse_pciid
{
    local _PCIID=$1
    local _TYPE=$2
    local _PCIID_ARRAY=(${_PCIID//:/ })
    local _RESULT="${_PCIID}"

    case "${_TYPE}" in
        "xorg" )
            _RESULT=$(printf "PCI:%d:%d:%d" "${_PCIID_ARRAY[@]}")
            ;;
        "lspci" )
            _RESULT=$(printf "%02x:%02x.%0x" "${_PCIID_ARRAY[@]}")
            ;;
    esac
    echo "${_RESULT}"
}

function tweak_amd
{
    TWEAKS=$1
    #COUNTER=$(echo ${TWEAKS} | jq ". | length")
    #CMD=echo ${TWEAKS} | jq ".[${LOOP}]"
    #REALCMD=$(sed "s/@ROCSMI@/${ROCSMI//\//\\/}/g;@NVSET@/${NVSET//\//\\/}/g;s/@NVSMI@/${NVSMI//\//\\/}/g" <<< "${CMD}")
    #printf ${REALCMD}
}

function tweak_nvidia
{
    TWEAKS=$1
    PCIBUS_XORG=$2
    PCIBUS=$3

    COUNT=$(echo ${TWEAKS} | jq ". | length")

    for (( i=0; i<${COUNT}; i++ ))
    do
        CMD=$(echo ${TWEAKS} | jq -r ".[${i}]")
        REALCMD=$(sed "s/@PCI_BUS@/${PCIBUS}/g;s/@NVSET@/${NVSET//\//\\/}/g;s/@NVSMI@/${NVSMI//\//\\/}/g" <<< "${CMD}")

        if [ "$VERBOSE" = 1 ]; then
            printf "Running : ${REALCMD}\r\n"
        fi
    done
}

function start_xorg
{
    PCIBUS_XORG=$1

    CFG=$(mktemp /tmp/xorg-XXXXXXXX.conf)
    sed -e s,@GPU_BUS_ID@,"${PCIBUS_XORG}",    \
        -e s,@SET_GPU_DIR@,"${DIR}", \
        config/nvidia-xorg.conf >> "${CFG}"

    xinit ${DIR}/nvscmd --bus="${PCIID}" --run-forever --  :${DISPLAY} -once -config "${CFG}" > /dev/null 2>&1 &
    sleep 10
    rm -f "${CFG}"
    DISPLAY=$((DISPLAY+1))
}

function main
{
    parse_args "$@"
    exit 0
}

main "$@"
