# Filesystem
Look into the system

MTD
```bash
bash-3.2# cat /proc/mtd
dev:    size   erasesize  name
mtd0: 00280000 00040000 "sbl"
mtd1: 00280000 00040000 "mibib"
mtd2: 01680000 00040000 "efs2"
mtd3: 001c0000 00040000 "tz"
mtd4: 00100000 00040000 "tz_devcfg"
mtd5: 00180000 00040000 "ddr"
mtd6: 00100000 00040000 "apdp"
mtd7: 00100000 00040000 "xbl_config"
mtd8: 00100000 00040000 "xbl_ramdump"
mtd9: 00100000 00040000 "multi_image"
mtd10: 00100000 00040000 "multi_image_qti"
mtd11: 00100000 00040000 "aop"
mtd12: 00100000 00040000 "qhee"
mtd13: 00100000 00040000 "abl"
mtd14: 00380000 00040000 "uefi"
mtd15: 00180000 00040000 "toolsfv"
mtd16: 00180000 00040000 "loader_sti"
mtd17: 01280000 00040000 "boot"
mtd18: 00100000 00040000 "scrub"
mtd19: 00100000 00040000 "logfs"
mtd20: 08040000 00040000 "modem"
mtd21: 001c0000 00040000 "misc"
mtd22: 00180000 00040000 "devinfo"
mtd23: 00080000 00040000 "recovery"
mtd24: 00080000 00040000 "fota"
mtd25: 00080000 00040000 "recoveryfs"
mtd26: 00100000 00040000 "sec"
mtd27: 00100000 00040000 "ipa_fw"
mtd28: 00100000 00040000 "usb_qti"
mtd29: 12c80000 00040000 "system"
mtd30: 034c0000 00040000 "pad1"
mtd31: 02840000 00040000 "userrw"
mtd32: 03940000 00040000 "hdata"
mtd33: 008c0000 00040000 "cust"
mtd34: 01040000 00040000 "ntgrpersist"
mtd35: 15980000 00040000 "ntgfota"
```

UBI 
```bash
bash-3.2# ubinfo
UBI version:                    1
Count of UBI devices:           5
UBI control device major/minor: 10:121
Present UBI devices:            ubi0, ubi1, ubi2, ubi3, ubi4
```

UBI to MTD mapping
```bash
bash-3.2# cat /sys/devices/virtual/ubi/ubi0/mtd_num
29
bash-3.2# cat /sys/devices/virtual/ubi/ubi1/mtd_num
20
bash-3.2# cat /sys/devices/virtual/ubi/ubi2/mtd_num
31
bash-3.2# cat /sys/devices/virtual/ubi/ubi3/mtd_num
32
bash-3.2# cat /sys/devices/virtual/ubi/ubi4/mtd_num
34
```

Mount
```bash
bash-3.2# mount
ubi0:rootfs on / type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=0)
devtmpfs on /dev type devtmpfs (rw,relatime,size=310068k,nr_inodes=77517,mode=755)
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
tmpfs on /run type tmpfs (rw,nosuid,nodev,mode=755)
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,mode=755)
cgroup2 on /sys/fs/cgroup/unified type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,name=systemd)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/debug type cgroup (rw,nosuid,nodev,noexec,relatime,debug)
cgroup on /sys/fs/cgroup/net_cls type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
ubi0:systemrw on /systemrw type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
tmpfs on /var/volatile type tmpfs (rw,relatime)
configfs on /sys/kernel/config type configfs (rw,nosuid,nodev,noexec,relatime)
debugfs on /sys/kernel/debug type debugfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /tmp type tmpfs (rw,nosuid,nodev)
ubi0:systemrw on /etc/data/mobileap_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:usrfs on /data type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=1)
ubi0:systemrw on /etc/data/mobileap_firewall.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:persist on /persist type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=4)
ubi0:systemrw on /etc/data/ipa_config.txt type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
/dev/ubi1_0 on /firmware type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=1,vol=0)
ubi0:systemrw on /etc/data/wlan_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/ipa/IPACM_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/l2tp_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/dhcp_hosts type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/hosts type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/usb/boot_hsusb_comp type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/adb_devid type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi3:hdata on /mnt/hdata type ubifs (ro,relatime,sync,bulk_read,assert=read-only,ubi=3,vol=0)
ubi0:systemrw on /etc/data/usb/softap_w_dun type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi2:userrw on /mnt/userrw type ubifs (rw,relatime,sync,bulk_read,assert=read-only,ubi=2,vol=0)
adb on /dev/usb-ffs/adb type functionfs (rw,relatime)
diag on /dev/ffs-diag type functionfs (rw,relatime)
tracefs on /sys/kernel/debug/tracing type tracefs (rw,nosuid,nodev,noexec,relatime)
/usr/web/lic.squash on /mnt/hdata/licenses type squashfs (ro,relatime)
ubi0:cachefs on /cache type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=2)
ubi0:systemrw on /etc/misc/ipq/ini/QCN9000.ini type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/ipq/ini/global.ini type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/ipq/ini/internal/QCN9000_i.ini type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/ipq/ini/internal/global_i.ini type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/wireless type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/sigma-dut type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/default_wifi_configs/2g_wireless type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/default_wifi_configs/5g_wireless type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/default_wifi_configs/6g_wireless type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/afc/afc-ipq.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/afc/location-ipq.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/pairing/device_config.json type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/pairing/pairing_config.json type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/pairing/provision_config.json type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/afc/location-ipq_enc.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/pairing/device_config_enc.json type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/pairing/token type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/ezmesh type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/wsplcd type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/repacd type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/ezlbd type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/bss-policy.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/config/map.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/templates/scheme-a.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/templates/scheme-b.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/templates/scheme-c.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/templates/scheme-d.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/wsplcd/map/templates/scheme-e.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/WCNSS_qcom_cfg.ini type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/hostapd-wlan1.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/hostapd-wlan2.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/hostapd-wlan3.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/hostapd.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/sta_mode_hostapd.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/misc/wifi/wpa_supplicant.conf type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
```
