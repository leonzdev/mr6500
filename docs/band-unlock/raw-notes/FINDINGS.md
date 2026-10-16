# MR6500 Band Unlock — Findings & Checkpoint

**Device:** Netgear Nighthawk M6 Pro **MR6500**, AT&T variant `MR6500-1A1NAS`, modem = Qualcomm **Snapdragon X65** (platform `sdxlemur`). Currently running the flashed **MR6550‑100PAS "Generic/GENALL" firmware** (`NTGX65_12.01.20.00`, modem `MPSS.DE.2.0-...-OLYMPIC_GENALL_PACK`).

**Goal:** enable cellular bands the AT&T SKU lacks (primarily **NR n41** for T‑Mobile; also n7/25/38/48/71/78 and some LTE).

**Status:** Root cause fully identified. The fix is known. The only blocker is *writing* the modem EFS, which is gated by modem DIAG security. See "The wall" and TODO.

---

## TL;DR (the crack)

The band limit is a **stale `policyman` cache** in the modem's EFS:
`/policyman/persisted_items/limited_bands` (+ `rat_mask`).

- The firmware's band‑restriction **rules are already permissive** (Netgear edited them, marked with `<!-- NTGRSTART -->` / `<!-- NTGRSTOP -->`). `hardware_band_filtering.xml` filters nothing (LTE `0-255`, NR SA `0-255`, NR NSA `0-511`). `generic_band_restrictions.xml` only excludes LTE b37 + some GSM from `base="current"` (the RF‑reported bands).
- The firmware's own comment says: **"Remove EFS `/policyman/persisted_items/` whenever adding, modifying or removing this XML."**
- The cache is **never regenerated** on its own (confirmed: persisted_items timestamps don't change across reboots). So it still holds the old AT&T masks from before the 100PAS flash.
- **Every runtime band interface clamps to this cache** — proven twice:
  - QMI NAS Set System Selection Preference (0x0033): setting LTE B25/B26 returns SUCCESS but the readback silently strips them.
  - `AT!BAND=` (after `AT!ENTERCND="A710"` unlock): the exact current AT&T masks are accepted (`OK`); adding n41/n78 returns `ERROR`.

**Therefore the fix is: clear/delete `/policyman/persisted_items/` in the modem EFS, then reboot.** policyman then rebuilds `limited_bands` from the permissive rules against the RF‑reported band set — which should include the wider NR bands.

**One residual unknown:** whether the AT&T unit's RF front‑end physically carries the extra NR bands. The modem's own NR list (QMI NAS SSP TLV 0x2e) is wide (includes n41/48/71/77/78), but that may be *silicon* capability vs. *device RF* capability. Clearing the cache is the definitive test — if regeneration yields the wide set, it works; if it regenerates back to AT&T, that band isn't wired in this unit's RF. (n78/n48/n25 are the most likely to be physically present since they reuse n77/b48/b2 RF paths.)

---

## Access / environment (how to reach the device)

- Host PC (`leonz-agent`, Ubuntu 26.04) has **passwordless sudo** (`/etc/sudoers.d/99-leonz-agent`).
- Device is on **USB (RNDIS)**: host iface `enx00a0c6000000` = 192.168.3.4/24; **device = 192.168.3.1**.
  - **telnet 192.168.3.1:23 → passwordless ROOT shell** (QTI Linux, BusyBox, armv7l, kernel 5.4.210). SELinux disabled.
  - **AT port 192.168.3.1:5510** (Netgear atfwd; engineering unlock `AT!ENTERCND="A710"`).
  - SSH :22 (OpenSSH 9.6), http :80.
- The hotspot **hijacks DNS** and installs a default route → breaks host internet. Fix applied: `sudo resolvectl dns enx00a0c6000000 ""; sudo resolvectl domain enx00a0c6000000 ""`. To fetch from GitHub use `curl --resolve raw.githubusercontent.com:443:185.199.111.133 ...`.
- Device also has an **Ethernet port** (user can enable, LAN‑only) as an out‑of‑band management path if USB is disrupted.
- **USB recovery:** if the USB device disappears (e.g., after gadget tinkering), `echo 1 | sudo tee /sys/bus/pci/rescan` re-detects a latched port. If the gadget UDC is left unbound, the device must be power‑cycled (changes to the USB gadget are runtime‑only; a reboot restores the stock `rndis_diag_dun_adb` composition). Do **not** touch the USB gadget again — it's fragile and unnecessary now (see below).

### Interfaces that DON'T need any of the above
The device uses **QRTR** (Qualcomm IPC Router; `AF_QIPCRTR`=42) and has **perl**. From a telnet root shell you can talk **QMI and DIAG directly to the modem** with tiny perl scripts — no USB reconfiguration, no adb, no extra tools. This is how all modem probing below was done. QMI service map (`qrtr-lookup`, modem = node 3):
`DMS=port81, NAS=port65, WDS=70, UIM=68, PDC(svc36)=25, AT(svc8)=73, "Modem embedded file system service"(svc21)=port9, DIAG(MODEM:CMD)=port17`.

---

## Evidence chain (what was proven, and how)

1. **Modem reports only AT&T bands as its capability.** `DMS Get Band Capability` (msg 0x0045) → LTE `1,2,3,4,5,7,12,14,29,30,46,48,66`; NR `n2,5,12,14,29,30,66,77` (+ mmWave 258/260). (perl: send to node3:port81.)
2. **This capability = the stale `limited_bands` cache**, not carrier config: the *active mcfg* is actually **T‑Mobile's** (matched the PDC "selected config id" `633e379d…` by SHA‑1 to `.../mcfg_sw/generic/NA/TMO/Commercial/mcfg_sw.mbn`) — yet the capability still lacks n41/n71. So carrier config does not drive it.
3. **It's not in the mcfg files** either (searched all `mcfg_sw.mbn` for the AT&T LTE mask `5f28003000a0` — not present).
4. **The gate is enforced.** NAS pref set of B25/B26 (which reuse B2/B5 RF) is silently stripped; `AT!BAND=` add of n41/n78 returns `ERROR` while current values return `OK`.
5. **Modem EFS is readable raw** from Linux: `/dev/mtd2` = `efs2`. Dumped 23 MB → found the policyman rule XMLs (permissive, Netgear‑edited) and the `limited_bands` persisted item (LTE mask `5f28003000a0`, NR mask nearby) at ~offset 591773 in the dump.
6. **Modem firmware "knows" the wide NR set** — NAS SSP (0x0034) TLV `0x2e` lists NR `1,2,3,5,7,8,12,13,14,18,20,25,26,28,29,30,34,38,39,40,41,46,48,50,51,53,65,66,70,71,74,75,76,77,78,79,...,257-261`.

---

## The wall: writing the modem EFS

Clearing `/policyman/persisted_items/` requires writing the modem's EFS. All routes assessed:

| Route | Status |
|---|---|
| **DIAG EFS2** (subsys 0x13 over QRTR node3:port17) | **Gated** — returns `BAD_SEC_MODE` (0x15) even for HELLO. Legacy SPC cmd 0x25 = `BAD_CMD`; DIAG password cmd 0x46 = wrong for zeros. This is modern signed diag‑auth, not the old SPC — effectively uncrackable without Qualcomm's key. This is why Rich/community use EDL. |
| **Legacy NV** (DIAG cmd 0x26 read / 0x27 write) | **Ungated and works**, but only reaches numbered NV items — cannot reach the `policyman` EFS *files*. |
| **Modem EFS QMI service** (svc 21, node3:port9) | **The one no‑EDL route.** `swiapp` uses it for path‑based EFS file ops (strings: `efs_stat()`, `open file %s`, EFS read/write/delete via `qmi_client_send_msg_sync`). It's **not security‑gated** (swiapp is an ordinary process). But the message protocol is **undocumented** → needs reverse‑engineering. **← TODO #2.** |
| **Raw `/dev/mtd2` write** | Infeasible cleanly — `efs2` is Qualcomm EFS2 (log‑structured) and uses NAND **OOB** for page metadata; a plain MTD rewrite corrupts it. (Note: Linux boots from `ubi0`, *not* `efs2`, so telnet survives EFS corruption and you can restore from `efs2_backup.bin` — but crafting a correct edit is the hard part.) |
| **EDL / 9008 + flasher** | Community/Rich route. User flashed 100PAS via `fdt`/"download mode" — may have partial EDL capability. **← TODO #1.** Even with EDL you still need EFS2‑aware tooling to modify the dumped partition. |
| **QXDM/QPST EFS Explorer + modem secure‑code** | Trivial *if* you have the secure‑code (likely Rich's real secret). We could not find it in the EFS dump. |

---

## Artifacts in this checkpoint folder

- `efs2_backup.bin` — full 23 MB dump of modem EFS (`/dev/mtd2`), sha1 `af7d3da5ba0b3c60f7cea8c335ae32f7ca8b225e`. **Restore image** if a write goes wrong, and the source for offline analysis of policyman/limited_bands.
- `swiapp.bin` — the 2.7 MB stripped ARM binary that implements the modem‑EFS QMI client (RE target).
- `scripts/dev.py` — host helper: run shell commands on the device over telnet:23.
- `scripts/at.py` — host helper: send AT commands to :5510.
- Device‑side perl helpers (QMI/DIAG over QRTR) are embedded in `RE-PROMPT.md`.
- See `TODO.md` and `RE-PROMPT.md`.

## Things NOT to do again (dead ends / hazards)
- Don't reconfigure the USB gadget (configfs) — it bricked the USB link once (recovered by power‑cycle). Unnecessary; use QRTR from the telnet shell instead.
- Don't expect mcfg switching (PDC) to change capability — active mcfg is already T‑Mobile's and capability is unchanged.
- Don't bother brute‑forcing DIAG security — it's signed‑auth.
