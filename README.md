## Gputweak Script

This is a gputweak helper script using nvidia-smi, nvidia-settings and rocm-smi.  
Script will be able to find GPU automatically and use the define tweak inside config/gputweak.json base on GPU product and vendor ID.  

## Requirement

- Ubuntu 16.04 or above
- jq library installed ( apt-get install -y jq )
- Install either official NVIDIA driver or AMDGPU driver, FGLRX is not supported.

## Install

This will install script in /opt/gputweak and enable startup script
Note that /etc/systemd/system/default.target will be change to script custom.target
/etc/X11/xorg.conf will be created for dummy monitor and locked using chattr 


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
  --reset          : reset and remove all tweak, will ignore other options
  --config         : specify gputweak config file, overwrite default. check config/gputweak.json for example
  --user           : read gputweak config file from /home/{user}/.gputweak/gputweak.json
```

## Run at startup
Copy all file and folder inside config/systemd to /etc/systemd/system. 
If you run install.sh above, you can skip this.

```bash
sudo cp -r config/systemd/* config/systemd/system
```

Set custom.target as default target then reboot

```bash
sudo rm -f /etc/systemd/system/default.target
sudo ln -s /etc/systemd/system/custom.target /etc/systemd/system/default.target
```

## Create GPU tweak config

You can add more tweak config in config/gputweak.json. Below are the step

1. Find your GPU ID check from your console using "lspci -vnn", then take note of the product and vendor id for both system and subsytem one.  
![pci_id](https://raw.githubusercontent.com/wiryonolau/gputweak/master/img/pci_id.jpg)

2. Then add another json object inside the config with this format
```
[
    {
        "description": "Put the description of your GPU here" (optional),
        "driver" : "specify the driver type, either amdgpu or nvidia, the script have to use this value (required)",
        "system_id": "see image above on how to obtain, if not available use 0000:0000 (required)",
        "subsystem_id": "see image above on how to obtain, if not available use 0000:0000 (required)",
        "tweaks" : [
            "a list of tweak you want to run (required)"
        ]
    }
]
```

Example tweak for AMDGPU, setting fan and core clock
```
[
    {
        "system_id" : "..."
        "subsystem_id" : "..."
        "tweaks" : [      
            "@ROCSMI@ -d @GPUID@ --setfan 180",
            "@ROCSMI@ -d @GPUID@ --setsclk 3"
        ]
    }
]
```

Example tweak for NVIDIA
```
[
    {
        "system_id" : "..."
        "subsystem_id" : "..."
        "tweaks" : [
            "@NVSET@ -a [gpu:0]/GPUFanControlState=1",
            "@NVSET@ -a [fan:0]/GPUTargetFanSpeed=70",
            "@NVSET@ -a [gpu:0]/GPUPowerMizerMode=1",
            "@NVSET@ -a [gpu:0]/GPUGraphicsClockOffset[3]=-200",
            "@NVSET@ -a [gpu:0]/GPUMemoryTransferRateOffset[3]=450",
            "@NVSMI@ -i @PCI_BUS@ -pm 1",
            "@NVSMI@ -i @PCI_BUS@ -pl 100"
        ]
    }
]
```

Predefine variable for tweaks are
- @NVSMI@ : will be replace by nvidia-smi executable path 
- @NVSET@ : will be replace by nvidia-settings executable path
- @PCI_BUS@ : will be replace by GPU pci bus address ( for NVIDIA card )
- @ROCSMI@ : will be replace by rocm-smi executable path
- @GPUID@ : will be replace by GPU id base on pci bus ( for AMD card )

3. Run the script directly

```
gputweak -v
```

## Notes
There is no safety mechanism when deploying tweak, so it's best to check the maximum clock, memclock, fan, etc before run this automatically.  
For AMD card currently there is no overclock mechanism available in Linux, you still require to update the BIOS directly.  
Script can be run manually if you need to reset or apply or test new setting.

## Disclaimer
Use this script at your own risk. We're not responsible for any damage this script cause to your system / GPU.

## Donate
Donation are welcome 

BTC - bc1qur8aeernt2s7982sffyz7yv6882vgewsqdkyjg ( Segwit )  
BTC - 3Kcs5hWVQRUGtJKv3DjKbkzbGTEtFEQkUx ( Compatible )  
ETH - 0x9beb9B182a273Da689b08228385137440fEb8D6B  
