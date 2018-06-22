#!/usr/bin/env bash
VERBOSE=""
NOUPDATE=""

function usage
{
    echo "Usage: install.sh [-v|--verbose] [-h|--help] [--noupdate]"
    echo " -v | --verbose   : output verbose"
    echo " -h | --help      : Print this help"
    echo " --noupdate       : Don't run apt-get update"
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
    apt-get install -y jq

    #Put script in opt
    printf "Create gputweak executable\n"
    WORKDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    mkdir -p /opt/gputweak
    cp -r ${WORKDIR}/* /opt/gputweak
    rm -rf /usr/bin/gputweak
    ln -s /opt/gputweak/gputweak /usr/bin/gputweak

    #Setup main xorg.conf
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
    cp -r ${WORKDIR}/config/systemd/* /etc/systemd/system
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

