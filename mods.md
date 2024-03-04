# A list of planned / completed mods
## Open the door
The stock system has SELinux in enforcing mode. Check with `sestatus`.

With SELinux in enforcing mode, you don't have access to certain locations even as the root user.

To disable SELinux, edit `/etc/selinux/config` then change line `SELINUX=` to `SELINUX=disabled`

Reboot, and SELinux should be disabled:
```bash
/ # sestatus
SELinux status:                 disabled
```

## Persavations
No one wants to lose root access. Things to perserve
* Firmware version. Meaning - disable auto update
* Root telnet
### Disable update
`dx` entry `Oma.DMAccountServerAddress1` is used as the server URL for auto update. [Source](https://www.reddit.com/r/Dish5G/comments/10mqgzq/mr6400_firmware_warning/)

Value for stock ATT MR6500 is `https://xdm.wireless.att.com:443/oma`. The value is stored in NVRAM so flashing a firmware doesn't override it.

To disable auto update, set it to garbage or an empty string:
```bash
dx -c Oma.DMAccountServerAddress1 ""
```

## SSH

## Band expansion

## TTL
This is trivial

