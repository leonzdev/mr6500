# USB
The usb interface can be configured to run in different mode. Telnet to 5510 and use AT command to get mode and change mode.

First, enter password with
```bash
AT!ENTERCND="..."
```

Then list available modes
```bash
at !udpid=?
at !udpid=?
APP   BOOT
68E1, 68E0
68E2, 68E0
90DB, 9008
```

Get current mode
```bash
at !udpid?
at !udpid?
!UDPID: 
APP : 68E2
BOOT: 68E0
```

Change mode
```bash
at !udpid=68E2
at !udpid=68E2
OK
at !udpid?
at !udpid?
!UDPID: 
APP : 68E2
BOOT: 68E0
```

## Modes
68E1 - RNDIS mode. Port 5510, 23 (if enabled) are available
68E2 - ADB mode.

Device IDs can be used to distinguish devices under different mode. Source: [https://wirelessjoint.com/viewtopic.php?t=3654](https://wirelessjoint.com/viewtopic.php?t=3654)
```
modem
USB\VID_0846&PID_68E2&REV_0504&MI_03
USB\VID_0846&PID_68E2&MI_03

Diag
USB\VID_0846&PID_68E2&REV_0504&MI_02
USB\VID_0846&PID_68E2&MI_02

RNDIS
USB\VID_0846&PID_68E2&REV_0504&MI_00
USB\VID_0846&PID_68E2&MI_00

ADB
USB\VID_0846&PID_68E2&REV_0504&MI_04
USB\VID_0846&PID_68E2&MI_04

USB Composite device
USB\VID_0846&PID_68E2&REV_0504
USB\VID_0846&PID_68E2
```
