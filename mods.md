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

## SSH

## Band expansion

## TTL
This is trivial

