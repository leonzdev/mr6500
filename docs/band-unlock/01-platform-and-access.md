# 01 — Platform & access

## The device

- **Netgear MR6500**, AT&T variant `MR6500-1A1NAS`. A USB/WiFi 5G mobile hotspot.
- Modem SoC: **Qualcomm SDX65 / sdxlemur** (Snapdragon X65 modem-RF).
- Application processor runs **QTI Linux** (BusyBox userland, `armv7l`), with **SELinux disabled**.
- Unlocked sibling: **MR6550-100PAS** — same SoC family, has n41/n71/n77/n78/b48 etc. The owner had
  already flashed the MR6550 "GENALL" (`MPSS.DE.2.0-…-OLYMPIC_GENALL_PACK`) modem firmware onto the
  6500, which is why root telnet is open. **Even on that generic all-carrier firmware, the band
  capability stayed AT&T-only** — an important early clue (see [02](02-what-gates-the-bands.md)).

## Getting in

The device is USB-attached and presents an RNDIS network interface:

- Host iface (example): `enx00a0c6000000` = **192.168.3.4/24**; the **device = 192.168.3.1**.
- Open services on the device:
  - **`telnet :23` = passwordless ROOT shell** ← primary access.
  - `:5510` = Netgear `atfwd` AT-command port (limited; `AT!ENTERCND` password = `A710`, found in
    `swiapp`).
  - `:22` SSH, `:80` http (web UI).
- The device hijacks DNS and installs a default route, which breaks host internet. Fix on the host:
  `sudo resolvectl dns <iface> ""; resolvectl domain <iface> ""`.
- If the USB link latches/drops after gadget surgery: `echo 1 | sudo tee /sys/bus/pci/rescan`, or
  power-cycle (runtime changes are non-persistent).

> ⚠️ **Do not touch the USB gadget / configfs.** Reconfiguring the UDC composition (adding
> `gsi.mbim`, clearing UDC) bricked the USB link once and required a physical power-cycle. `usbd`
> re-binds stock composition ~2 s after UDC is cleared, so half-measures leave it dead. Read
> capability over the already-working **QMI-over-QRTR** path instead (below).

## Full MTD (NAND) partition map

Raw NAND, 64 KB (`0x40000`) erase blocks. There is **no `fsg` / `modemst1` / `modemst2` / `golden`
partition** — that eMMC/GPT convention doesn't exist here. The modem EFS is a single `efs2` MTD
partition; redundancy is internal to its log structure.

```
mtd0  "sbl"            mtd12 "qhee"           mtd24 "fota"
mtd1  "mibib"          mtd13 "abl"            mtd25 "recoveryfs"
mtd2  "efs2"    23.5MB  ← modem EFS (RFNV cal + policyman + limited_bands)
mtd3  "tz"            mtd14 "uefi"           mtd26 "sec"      1MB  ← secure data
mtd4  "tz_devcfg"     mtd15 "toolsfv"        mtd27 "ipa_fw"
mtd5  "ddr"          mtd16 "loader_sti"     mtd28 "usb_qti"
mtd6  "apdp"         mtd17 "boot"           mtd29 "system"   ~300MB
mtd7  "xbl_config"   mtd18 "scrub"          mtd30 "pad1"
mtd8  "xbl_ramdump"  mtd19 "logfs"          mtd31 "userrw"   ~42MB ← Netgear ntgnv (persists)
mtd9  "multi_image"  mtd20 "modem"   128MB  ← SIGNED MPSS image (RFC = the band gate)
mtd10 "multi_image_qti" mtd21 "misc"        mtd32 "hdata"
mtd11 "aop"          mtd22 "devinfo"        mtd33 "cust"
                     mtd23 "recovery"       mtd34 "ntgrpersist" ← Netgear persistent
                                            mtd35 "ntgfota"  ~345MB
```

Key ones for this project:
- **`mtd20 "modem"`** — 128 MB UBI volume, mounted at `/firmware` (ubifs, `rw`). Holds the split
  MPSS ELF `/firmware/image/modem.b00`–`b09`. **The RFC (band declarations) lives here, and it's
  signed.** Dump on host: `modem_mtd20.bin` (sha1 `6754f136…`).
- **`mtd2 "efs2"`** — the modem's EFS2 filesystem (log-structured over raw NAND). Holds RFNV
  calibration, `policyman` items including `limited_bands`. Readable raw with `dd`; writable with
  `flash_erase`+`nandwrite`. Dumps: `efs2_backup.bin`, `efs2_now.bin`.
- **`mtd31 "userrw"`** — Netgear NV store `/mnt/userrw/ntgnv/` (band tables `BAND_INFO*`), also a
  handy **persistent scratch** area (survives reboot; `/tmp` does not).

## Tooling

**On the device (BusyBox + a few extras):** `dd`, `od`, `perl` (⚠️ no `Time::HiRes` — use
`select(undef,undef,undef,$sec)` for sub-second sleeps), `nandwrite`, `flash_erase`, `ubiupdatevol`,
`qrtr-lookup`, `strace`. **No `nanddump`.** The `MEMREADOOB` ioctl returns "not supported" (the
Qualcomm QPIC NAND driver hides OOB from the AP — you cannot read EFS2 spare/CRC bytes from Linux).

**On the host:** passwordless `sudo`; `qmicli`, `mbimcli`, `python3`, `perl`, `nc` (**OpenBSD**
variant — see gotcha), `radare2`, ARM `objdump`. No `adb`/`smbclient`/`socat`/`gcc`.

`scripts/dev.py '<cmds>'` runs a shell batch on the device over telnet (handles IAC negotiation +
sentinel framing). `scripts/at.py` sends AT commands to `:5510`.

## QMI-over-QRTR (how we read modem state without USB surgery)

The modem speaks **QMI over QRTR** (`AF_QIPCRTR = 42`, `SOCK_DGRAM`). **Node 3 = the modem.**
`qrtr-lookup` prints the live service→port map (⚠️ **ports are reassigned every boot** — always
re-look-up). QMI-over-QRTR has **no QMUX header**; the message is:

```
flags(1)  txn(2 LE)  msgid(2 LE)  len(2 LE)  TLVs…
```

Result TLV `0x02` = `{u16 result; u16 error}`. The band-capability query is **DMS msg `0x0045`**;
the NR band list is **TLV `0x13`** (count then u16 band numbers, LE).

Minimal perl client (recreate as `/tmp/q.pl`; usage `perl /tmp/q.pl <DMS_port> 0045`):

```perl
use Socket;
my ($AF,$node,$port,$msgid)=(42,3,shift,hex(shift));
my $msg=pack("C v v v",0,1,$msgid,0);
socket(my $s,$AF,2,0); my $dest=pack("S x2 L L",$AF,$node,$port);
send($s,$msg,0,$dest);
# select() + recv(), then unpack("H*") the reply and walk the TLVs
```

DIAG also works over QRTR (`node3 : port17`): **legacy NV read `0x26` / write `0x27` are UNGATED**,
but the **EFS2 subsystem `0x13` = `BAD_SEC_MODE`** (secure-gated) and legacy SPC `0x25` = `BAD_CMD`.

## File-transfer gotchas (important, cost us time)

- The host `nc` is **OpenBSD netcat**: `-l -p PORT` sets the *source* port, it does **not** open a
  listener. Don't use it to listen.
- The **device cannot route outbound** to the host (`192.168.3.4` → "no route to host").
- **Therefore: the device must SERVE and the host must PULL.**
  - Device: `dd if=<partition> 2>/dev/null | nc -l -p 9099`
  - Host: `nc 192.168.3.1 9099 > out.bin`
  - Verify by size + sha1 on both ends.
