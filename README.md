# mr6500
Poking around the Netgear Nighthawk M6 Pro 5G WiFi 6 Mobile Router (MR6500)

The Nighthawk M6 Pro mobile router has multiple models. See: https://www.rvmobileinternet.com/netgear-releases-unlocked-all-carrier-nighthawk-m6-pro-5g-mobile-hotspot/.

For MR6500 there are multiple variants: https://wirelessjoint.com/viewtopic.php?t=4072
```
---------------------------------------------------------------------
for the AT&T varaint (1A1NAS)
Chipset Qualcomm® Snapdragon™ X65 5G Modem-RF System
5G Technology Sub-6GHz + mmWave
5G Bands 2/5/12/14/29/30/66/77
4G Technology LTE CAT20
4G Bands 1/2/3/4/5/7/12/14/29/30/46/48/66
---------------------------------------------------------------------
and the same model but the variant
(100PAS) unlocked
Chipset Qualcomm® Snapdragon™ X65 5G Modem-RF System
5G Technology Sub-6GHz+mmWave
5G Bands 2/5/7/12/14/25/29/30/38/41/48/66/71/77/78/260/261
4G Technology LTE CAT20
4G Bands 1/2/3/4/5/7/12/13/14/25/26/28/29/30/40/41/46/48/66/71
3G Bands N/A
---------------------------------------------------------------------
(100EUS)
Chipset Qualcomm® Snapdragon™ X65 5G Modem-RF System
5G Technology Sub-6GHz
5G Bands 1/2/3/5/7/8/20/28/38/40/41/71/77/78
4G Technology LTE CAT20
4G Bands 1/2/3/4/5/7/8/12/13/14/20/28/38/40/41/42/66
3G Bands 1/2/5/8
```

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

