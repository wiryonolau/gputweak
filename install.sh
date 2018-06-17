#!/bin/bash

#Put script in opt
WORKDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cp -r "${WORKDIR}/*" /opt/gputweak
ln -s /usr/bin/gputweak /opt/gputweak/gputweak

#Enable systemd startup
cp -r "${WORKDIR}/config/systemd/*" /etc/systemd/system
rm -f /etc/systemd/system/default.target
ln -s /etc/systemd/system/custom.target /etc/systemd/system/default.target

