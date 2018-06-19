#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

#Install jq (bash json parser) library
apt-get update
apt-get install -y jq

#Put script in opt
WORKDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
mkdir -p /opt/gputweak
cp -r ${WORKDIR}/* /opt/gputweak
rm -rf /usr/bin/gputweak
ln -s /opt/gputweak/gputweak /usr/bin/gputweak

#Setup main xorg.conf
if [[ ! -z "/etc/X11/xorg.conf" ]]; then
    chattr -i /etc/X11/xorg.conf
    cp /etc/X11/xorg.conf /etc/X11/xorg.conf.orig
fi
cp /opt/gputweak/config/xorg.conf /etc/X11/xorg.conf
chattr +i /etc/X11/xorg.conf

#Enable systemd startup
cp -r ${WORKDIR}/config/systemd/* /etc/systemd/system
rm -f /etc/systemd/system/default.target
ln -s /etc/systemd/system/custom.target /etc/systemd/system/default.target

systemctl daemon-reload
