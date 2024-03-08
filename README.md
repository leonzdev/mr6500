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

[ATT variant](https://www.netgear.com/home/mobile-wifi/hotspots/mr6500/) MR6500-1A1NAS
FCC ID: PY321100529

## Access
Console access can be enabled in addition to the touch screen and webui.


Port 5510 is open with telnet access for AT commands. Commands are pretty standard across recent Netgear cellular routers: https://github.com/0xBAADF0OD/netgear_mr6400/blob/main/netgear-AT-commands/README.md


**On old firmwares (10.x)** port 23 can be opened with telnet for a root shell.

## Firmware
ATT variant on new (12.x) firmwares have many functionalities locked down, such as: root shell via telnet, ability to SIM unlock, etc. Downgrading to 10.x is also blocked.

To workaround the limitations and gain root shell access, you can flash the MR6550-100PAS firmware to MR6500-1A1NAS. 

Guide: https://tinyurl.com/mrCONFIGTools

Tool & firmware: https://tinyurl.com/MRToolKits

* Download `fdt` tool
* Download firmware 
* Connect the router to a Windows machine via USB, put it in download mode, and flash via `fdt`

Firmware I put on my MR6500: [MR6550-100PAS_23115682_NTGX65_12.01.20.00_00_Generic_01.28_00.secc.cwe](https://mega.nz/folder/uWAHgSgJ#WKZ5fP7i6b4DU0rg7nAWPQ/file/LeZQWJxR)

## Software teardown
After gaining the root telnet access, telnet to port 23 to poke around!

### Device info
```bash
/ # cat /proc/cpuinfo
processor       : 0
model name      : ARMv7 Processor rev 5 (v7l)
BogoMIPS        : 38.40
Features        : half thumb fastmult vfp edsp neon vfpv3 tls vfpv4 idiva idivt vfpd32 lpae evtstrm 
CPU implementer : 0x41
CPU architecture: 7
CPU variant     : 0x0
CPU part        : 0xc07
CPU revision    : 5

Hardware        : Qualcomm Technologies, Inc. SDXLEMUR (Flattened Device Tree)
Revision        : 0000
Serial          : 0000000000000000

/ # cat /proc/meminfo
MemTotal:         666220 kB
MemFree:          169448 kB
MemAvailable:     370432 kB
Buffers:              64 kB
Cached:           196288 kB
SwapCached:            0 kB
Active:           218304 kB
Inactive:          71068 kB
Active(anon):      93696 kB
Inactive(anon):     1296 kB
Active(file):     124608 kB
Inactive(file):    69772 kB
Unevictable:          32 kB
Mlocked:              32 kB
SwapTotal:        333108 kB
SwapFree:         333108 kB
Dirty:                 0 kB
Writeback:             0 kB
AnonPages:         93088 kB
Mapped:            49984 kB
Shmem:              1972 kB
KReclaimable:      19632 kB
Slab:             112968 kB
SReclaimable:      19632 kB
SUnreclaim:        93336 kB
KernelStack:        4048 kB
PageTables:         3636 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:      666216 kB
Committed_AS:    2211352 kB
VmallocTotal:     608580 kB
VmallocUsed:       21780 kB
VmallocChunk:          0 kB
Percpu:               96 kB
CmaTotal:          45056 kB
CmaFree:               0 kB

/ # cat /proc/mtd
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

/ # mount
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
cgroup on /sys/fs/cgroup/net_cls type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/debug type cgroup (rw,nosuid,nodev,noexec,relatime,debug)
ubi0:systemrw on /systemrw type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
tmpfs on /var/volatile type tmpfs (rw,relatime)
configfs on /sys/kernel/config type configfs (rw,nosuid,nodev,noexec,relatime)
debugfs on /sys/kernel/debug type debugfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /tmp type tmpfs (rw,nosuid,nodev)
ubi0:systemrw on /etc/data/mobileap_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/mobileap_firewall.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/ipa_config.txt type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:persist on /persist type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=4)
ubi0:systemrw on /etc/data/wlan_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:usrfs on /data type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=1)
/dev/ubi1_0 on /firmware type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=1,vol=0)
ubi0:systemrw on /etc/data/ipa/IPACM_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/l2tp_cfg.xml type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/dhcp_hosts type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/hosts type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/usb/boot_hsusb_comp type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/adb_devid type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi0:systemrw on /etc/data/usb/softap_w_dun type ubifs (rw,relatime,bulk_read,assert=read-only,ubi=0,vol=3)
ubi3:hdata on /mnt/hdata type ubifs (ro,relatime,sync,bulk_read,assert=read-only,ubi=3,vol=0)
adb on /dev/usb-ffs/adb type functionfs (rw,relatime)
diag on /dev/ffs-diag type functionfs (rw,relatime)
ubi2:userrw on /mnt/userrw type ubifs (rw,relatime,sync,bulk_read,assert=read-only,ubi=2,vol=0)
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
### Software Info
```bash
/ # uname -a
Linux sdxlemur 5.4.210-perf #1 PREEMPT Sat May 6 06:01:25 UTC 2023 armv7l GNU/Linux
/ # cat /proc/cmdline
rw rootwait console=ttyMSM0,115200,n8 androidboot.hardware=qcom msm_rtb.filter=0x237 androidboot.console=ttyMSM0 lpm_levels.sleep_disabled=1 firmware_class.path=/lib/firmware/updates service_locator.enable=1 net.ifnames=0 atlantic_fwd.rx_ring_size=512 atlantic_fwd.rx_linear=1 pcie_ports=compat pci=pcie_bus_perf rootfstype=ubifs rootflags=bulk_read root=ubi0:rootfs ubi.mtd=29 androidboot.serialno=xxxxxxxx androidboot.baseband=msm androidboot.force_normal_boot=1
```

### Resources
Mirrow for QPST and QXDM tools: https://mirrors.lolinet.com/software/windows/Qualcomm/

QXDM5: https://mega.nz/folder/W3YV0IAD#43JFdo2uvM5ayCE7Seunhw

Band enabling discussion: https://wirelessjoint.com/viewtopic.php?t=4119
