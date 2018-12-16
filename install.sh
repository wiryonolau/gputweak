#!/usr/bin/env bash
VERBOSE=""
NOUPDATE=""
NOXORG=""

function usage
{
    echo "Usage: install.sh [-v|--verbose] [-h|--help] [--noupdate]"
    echo " -v | --verbose   : output verbose"
    echo " -h | --help      : Print this help"
    echo " --noupdate       : Don't run apt-get update"
    echo " --noxorg         : Don't replace xorg"
}

function parse_args
{
    local _ARGS=()

    while [ "$1" ]
    do
        case "$1" in
            "-v" | "--verbose" )
                VERBOSE=1
            ;;
            "-h" | "--help")
                usage
                exit 0
                ;;
            "--noupdate" )
                NOUPDATE=1
            ;;
            "--noxorg" )
                NOXORG=1
            ;;
        esac
        shift
    done
    
    set -- "${args[@]}"

    start_install
    exit 0
}

function start_install
{
    if [[ $EUID -ne 0 ]]; then
       printf "This script must be run as root\n" 
       exit 1
    fi

    #Install jq (bash json parser) library
    if [ -z "${NOUPDATE}" ]; then
        apt-get update
    fi
    apt install -y jq

    #Install opencl-headers for testing
    apt install -y opencl-headers

    #Put script in opt
    printf "Create gputweak executable\n"
    WORKDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    mkdir -p /opt/gputweak
    cp -r ${WORKDIR}/* /opt/gputweak
    rm -rf /usr/bin/gputweak
    ln -s /opt/gputweak/gputweak /usr/bin/gputweak

    #Build AMDGPU OPENCL device detector
    if [[ -z "/opt/gputweak/amdgpu-devices.c" ]]; then
        /usr/bin/wget https://laanwj.github.io/assets/2016/05/06/opencl-ubuntu1604/devices.c -O /opt/gputweak/amdgpu-devices.c 
    fi
    /usr/bin/gcc /opt/gputweak/amdgpu-devices.c -o /opt/gputweak/amdgpu-devices -O2 /opt/amdgpu-pro/lib/x86_64-linux-gnu/libOpenCL.so

    #Setup main xorg.conf
    if [ -z "${NOXORG}" ]; then
        printf "Setup xorg.conf\n"
        if [[ ! -z "/etc/X11/xorg.conf" ]]; then
            NOW=$(date +%s)
            chattr -i /etc/X11/xorg.conf
            cp /etc/X11/xorg.conf "/etc/X11/xorg.conf.${NOW}"
        fi
        cp /opt/gputweak/config/xorg.conf /etc/X11/xorg.conf
        chattr +i /etc/X11/xorg.conf

    #Enable systemd startup
    printf "Setup systemd startup script\n"
    systemctl disable gputweak.service
    cp ${WORKDIR}/config/systemd/* /etc/systemd/system
    rm -f /etc/systemd/system/default.target
    ln -s /etc/systemd/system/custom.target /etc/systemd/system/default.target
    systemctl enable gputweak.service

    systemctl daemon-reload
    printf "Setup done\n"
}

function main
{
    parse_args "$@"
    exit 0
}

main "$@"

