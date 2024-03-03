# mr6500
Poking around the Netgear Nighthawk M6 Pro 5G WiFi 6 Mobile Router (MR6500)

[ATT variant](https://www.netgear.com/home/mobile-wifi/hotspots/mr6500/)https://www.netgear.com/home/mobile-wifi/hotspots/mr6500/ MR6500-1A1NAS
FCC ID: PY321100529

## Access
Port 5510 is open with telnet access for AT commands. Commands are pretty standard across recent Netgear cellular routers: https://github.com/0xBAADF0OD/netgear_mr6400/blob/main/netgear-AT-commands/README.md

**With old version of firmware (10.x)** port 23 can be opened with telnet for a root shell.

## Firmware
ATT variant on new (12.x) firmwares have many functionalities locked down, such as: root shell via telnet, ability to SIM unlock, etc. Downgrading to 10.x is also blocked.

To workaround the limitations and gain root shell access, you can flash the MR6550-100PAS firmware to MR6500-1A1NAS. 

Guide: https://tinyurl.com/mrCONFIGTools

Tool & firmware: https://tinyurl.com/MRToolKits

* Download `fdt` tool
* Download firmware 
* Connect the router to a Windows machine via USB, put it in download mode, and flash via `fdt`

