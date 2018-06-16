#!/bin/bash

#Global Variables
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TWEAKCONFIG="$DIR/config/gputweak.json"
NVSMI='/usr/bin/nvidia-smi'
NVSET='/usr/bin/nvidia-settings'
ROCSMI='/usr/bin/rocm-smi'
TEST=0
VERBOSE=0
DISPLAY=10
PCI_REGEX='/\(VGA compatible\|3D controller\).*\(AMD\|\NVIDIA\)/s/^\(..\):\(..\).\(.\).*/0x\1:0x\2:0x\3/p'
SYSID_REGEX='\s(VGA compatible|3D controller).*(AMD|NVIDIA)'

function usage
{
    exit 0
}

function parse_args
{
    local _ARGS=()
    local _PCIIDS=""

    while [ "$1" ]
    do
        case "$1" in
            "-v" )
                VERBOSE=1
            ;;
            "--test")
                TEST=1
                PCI_REGEX='s/^\(..\):\(..\).\(.\).*/0x\1:0x\2:0x\3/p'
                SYSID_REGEX=''
                _PCIIDS=$(printf "f0:00.0\nf1:00.0")
            ;;
        esac
        shift
    done
    
    set -- "${args[@]}"

    start_tweak "${VERBOSE}" "${_PCIIDS}"
    exit 0
}

function start_tweak
{
    if [ -z "$2" ]; then
        #GET PCI ID FOR ALL NVIDIA/AMD GPU
        local _PCIIDS=$(lspci | sed -n -e "${PCI_REGEX}")
    else
        local _PCIIDS=$(sed -n -e "${PCI_REGEX}" <<< "$2")
    fi

    if [ -z "$_PCIIDS" ]; then
        printf "No recongnizable AMD / NVIDIA Device\r\n"
        exit 0
    fi

    while read -r _PCIID; do
        local _PCIBUS=$(parse_pciid "${_PCIID}" "lspci")

        #GET SYSTEM ID
        local _IDS=$(lspci -vnn | grep -E "${_PCIBUS}${SYSID_REGEX}" -A1 | grep -Eo '([0-9a-z]{4}:[0-9a-z]{4})')
        local _IDS=(${_IDS[@]})

        local _SYSTEM_ID=${_IDS[0]}
        local _SUBSYSTEM_ID=${_IDS[1]}

        if [ "${TEST}" = 1 ]; then
            if [ $(($DISPLAY%2)) -eq 0 ]; then
                #Test NVIDIA
                local _SYSTEM_ID="10de:1b81"
                local _SUBSYSTEM_ID="10de:119d"
            else
                #TEST AMD
                local _SYSTEM_ID="1002:67df"
                local _SUBSYSTEM_ID="1462:3417"
            fi
        fi

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
        local _DRIVER=$(jq -r ".[] | select(.system_id==\"${_SYSTEM_ID}\" and .subsystem_id==\"${_SUBSYSTEM_ID}\") | .driver" "${TWEAKCONFIG}")
        local _TWEAKS=$(jq -r ".[] | select(.system_id==\"${_SYSTEM_ID}\" and .subsystem_id==\"${_SUBSYSTEM_ID}\") | .tweaks" "${TWEAKCONFIG}")
      
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
                tweak_amd "${_PCIID}" "${_TWEAKS}"
                ;;
            "nvidia" )
                tweak_nvidia "${_PCIID}" "${_TWEAKS}"
                ;; 
        esac
        DISPLAY=$((DISPLAY+1))
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
        "rocm" )
            _RESULT=$(printf "%x" "${_PCIID_ARRAY[0]}")
            ;;
    esac
    echo "${_RESULT}"
}

function tweak_amd
{
    local _PCIID=$1
    local _TWEAKS=$2
    local _GPUID=$(parse_pciid "${_PCIID}" "rocm")
    local _COUNT=$(echo ${_TWEAKS} | jq ". | length")
    
    for (( i=0; i<${_COUNT}; i++ ))
    do
        local _CMD=$(echo ${_TWEAKS} | jq -r ".[${i}]")
        local _REALCMD=$(sed "s/@GPUID@/${_GPUID}/g;s/@ROCSMI@/${ROCSMI//\//\\/}/g" <<< "${_CMD}")
        
        if [ "$VERBOSE" = 1 ]; then
            printf "Running : ${_REALCMD}\r\n"
        fi

        #/bin/bash -c "${_REALCMD}"
        #wait
    done
}

function tweak_nvidia
{
    local _PCIID=$1
    local _TWEAKS=$2

    local _PCIBUS=$(parse_pciid "${_PCIID}" "lspci")
    local _COUNT=$(echo ${_TWEAKS} | jq ". | length")

    #Prepare temporary tweak file for xinit
    local _TWEAK_CFG=$(mktemp /tmp/tweak-XXXXXXXX.sh)
    printf "#!/bin/bash\r\n" >> ${_TWEAK_CFG}

    for (( i=0; i<${_COUNT}; i++ ))
    do
        local _CMD=$(echo ${_TWEAKS} | jq -r ".[${i}]")
        local _REALCMD=$(sed "s/@PCI_BUS@/${_PCIBUS}/g;s/@NVSET@/${NVSET//\//\\/}/g;s/@NVSMI@/${NVSMI//\//\\/}/g" <<< "${_CMD}")
        
        printf "${_REALCMD}\r\n" >> ${_TWEAK_CFG}

        if [ "$VERBOSE" = 1 ]; then
            printf "Running : ${_REALCMD}\r\n"
        fi
    done

    start_xorg "${_PCIID}" "${_TWEAK_CFG}"
}

function start_xorg
{
    local _PCIID=$1
    local _TWEAK_CFG=$2

    local _PCIBUS_XORG=$(parse_pciid "${_PCIID}" "xorg")


    local _XORG_CFG=$(mktemp /tmp/xorg-XXXXXXXX.conf)
    sed -e s,@GPU_BUS_ID@,"${_PCIBUS_XORG}",    \
        -e s,@SET_GPU_DIR@,"${DIR}", \
        config/nvidia-xorg.conf >> "${_XORG_CFG}"

    if [ "${VERBOSE}" = 1 ]; then
        printf "xinit ${_TWEAK_CFG} --bus="${PCIID}" --run-forever --  :${DISPLAY} -once -config ${_XORG_CFG} > /dev/null 2>&1 &\r\n"
    fi

    #RUN XINIT AND TWEAK
    #xinit "${_TWEAK_CFG}" --bus="${PCIID}" --run-forever --  :"${DISPLAY}" -once -config "${_XORG_CFG}" > /dev/null 2>&1 &
    #wait

    #CLEANUP
    rm -f "${_XORG_CFG}"
    rm -f "${_TWEAK_CFG}"
}

function main
{
    parse_args "$@"
    exit 0
}

main "$@"
