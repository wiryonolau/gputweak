## Gputweak Script

Gpu tweak script using nvidia-smi, nvidia-settings and rocm-smi.

## Requirement

- Ubuntu 16.04 or above
- Install either official NVIDIA driver or AMDGPU driver, FGLRX is not supported.

## Install

This will install script in /opt/gputweak and enable startup script
Note that /etc/systemd/system/default.target will be change to script custom.target

```
sudo ./install.sh
```

## Usage

```
Usage: gputweak [-v|--verbose] [-h|--help] [OPTIONS]
 -v | --verbose   : output verbose
 -h | --help      : this message

 OPTIONS
  --test           : Test mode, no tweak is run. Using
                      NVIDIA  10de:1b81 10de:119d device
                      AMD     1002:67df 1462:3417 device
  --coolbits       : set NVIDIA coolbits, default is 12
  --nvsmi          : set nvidia-smi executable path, default /usr/bin/nvidia-smi
  --nvset          : set nvidia-settings executable path, default /usr/bin/nvidia-settings
  --rocmsmi        : set rocm-smi executable path, default /usr/bin/rocm-smi
  --reset          : reset and remove all tweak
  --config         : specify gputweak config file, overwrite default. check config/gputweak.json for example
  --noxorg         : disable xinit, for nvidia only
```

## Run at startup
copy all file and folder inside config/systemd to /etc/systemd/system. If you run install.sh above, you can skip this.

```bash
sudo cp -r config/systemd/* config/systemd/system
```

Set custom.target as default target then reboot

```bash
sudo rm -f /etc/systemd/system/default.target
sudo ln -s /etc/systemd/system/custom.target /etc/systemd/system/default.target
```

## Notes
Script can be run manually if you need to reset or apply new setting. "--noxorg" option is best to be specify for NVIDIA card on retweak.

## Disclaimer
Use this script at your own risk. We're not responsible for any damage this script cause to your system / GPU.
