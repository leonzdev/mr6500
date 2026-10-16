# RFC-edit path for n78 + PLAN (2026-07-06) — the remaining live avenue

## ★★★ PHASE 1 RESULT (2026-07-06): SECURE BOOT IS ENFORCED → AVENUE CLOSED ★★★
Ran the recoverable test below. Flipped ONE inert zero-padding byte in `modem.b09` (@0x12C000,
0x00→0x01; sha1 346b358c…→119395a9…), synced, rebooted. **The modem refused to load, in a hard
restart loop:**
```
subsys-pil-tz mss: modem: loading from 0x90800000 to 0xa0000000
subsys-pil-tz mss: modem: Failed to bring out of reset(rc:-22)   # -EINVAL = PIL/TZ auth reject
subsys-pil-tz mss: modem: Failed to map memory
subsys-pil-tz: subsys_powerup(): pil_boot failed for modem
```
node-3 QMI services = 0 (modem dead). Because the flipped byte was cosmetic alignment padding, an
integrity/signature check is the ONLY thing that could have killed it → **the modem PIL verifies the
image signature at every load, and it is ENFORCED.** Restored `modem.b09` from `/mnt/userrw/modem.b09.orig`
(sha1 back to 346b358c…), rebooted → `modem: Brought out of reset` + `pil_boot is successful`, bands back
to stock `{2,5,12,14,29,30,66,77,258,260}`. Device fully healthy.

**Verdict: editing the RFC (Phase 2/3 below) is NOT viable — it needs Qualcomm/Netgear's signing key,
which nobody has. Combined with `N78-WRITE-EXPERIMENT.md` (EFS edits have no effect), this closes the
LAST software avenue. n78/n41 cannot be enabled on this AT&T MR6500 by any software means.** Phases 2–3
below are retained for the record only; do not pursue without a signing key or a secure-boot exploit
(eFuse is blown, so even EDL/firehose is signature-gated). ↓↓↓

---

Read this with `N78-WRITE-EXPERIMENT.md` (proved the EFS gate is a dead end) and `RFC-BAND-VIABILITY.md`
(per-board RF analysis). This doc captures the ONE avenue still open and the exact recoverable test to run.

## Why this avenue exists (the reframe)
`N78-WRITE-EXPERIMENT.md` proved the modem derives its band capability LIVE from the RF driver's
`base="hardware"` set = **RFC config** (in the SIGNED modem firmware) ∩ RFNV cal. Editing EFS
(`limited_bands`) does nothing. So the only way to widen capability is to change the RFC itself.

**Key physics insight — n78 is uniquely reachable:** n78 = 3300–3800 MHz is a **subset of n77** =
3300–4200 MHz, and this board runs n77 today. So the RF front-end (antenna/PA/LNA/filters) can PHYSICALLY
do n78's frequencies — n78 is disabled only because the RFC *declares* n77 and not n78 for this AT&T
variant (a config choice in a signed file), NOT a hardware limit. Therefore: **if the modem image is
editable, adding n78 to the RFC (reusing the n77 RF path) would very likely just work.** (Contrast n41 =
2496–2690 MHz: board has LTE b7 at ~2.5 GHz FDD but the TDD n41 path is uncertain; RFC analysis showed n41
as freq-only/no path for mr6500. So n41 stays the long shot; **n78 is the target.**)

## Where the RFC lives (recon 2026-07-06)
- Active modem firmware = **`/firmware/image/modem.b00`–`b09`** (split MPSS ELF; b00=hdr, b01/b02=hash+sig
  segments, b03=804KB, b09=2,475,128 B — the big code/data segment where the `rfc_hwid895_…` symbols live).
  These files are on **ubi1 ubifs mounted rw** (`/dev/ubi1_0 on /firmware ... rw ... assert=read-only`).
  (mtd20 "modem" is the UBI backing this; the 128MB dump `modem_mtd20.bin` on host is that whole UBI.)
- So the RFC is *physically* editable (the files are on a writable fs).

## THE WALL = secure boot (the decider)
The MPSS image is signed; the modem boot authenticator (MBA/PIL) verifies each segment's hash against the
signed hash table at load. Edit any hashed byte → hash mismatch → modem refuses to load — IF secure boot
is enforced. AT&T 12.x units have the eFuse tripped, so it's *probably* enforced. Re-signing needs
Qualcomm/Netgear's private key (nobody has it). **But whether the modem image is actually re-verified at
each load is an unproven assumption — and it's directly, recoverably testable. That test decides the whole
avenue.** dmesg didn't clearly show PIL/MBA auth lines (inconclusive), so we must test empirically.

---

## ★ PLAN

### PHASE 1 — Secure-boot enforcement test (recoverable) ← DO THIS FIRST
Goal: does the modem PIL verify the modem-image signature? (= is RFC editing viable?)

1. **Back up `modem.b09` two ways** (survive reboot):
   - To host: device serves, host pulls (device outbound is broken — see gotchas):
     device: `pkill -f 'nc -l -p 9099'; setsid sh -c 'dd if=/firmware/image/modem.b09 | nc -l -p 9099' </dev/null >/dev/null 2>&1 &`
     host:  `nc 192.168.3.1 9099 > modem_b09.orig` ; verify size **2475128** + sha1.
   - On-device persistent: `cp /firmware/image/modem.b09 /mnt/userrw/modem.b09.orig` (mtd31 "userrw" is persistent+writable; confirm the copy's sha1 matches).
2. **Confirm /firmware is writable:** `touch /firmware/image/.wt && rm /firmware/image/.wt && echo WRITABLE`.
   If not, `mount -o remount,rw /firmware` (or, worst case, edit via UBI — riskier).
3. **Flip ONE byte in a benign ASCII string** inside modem.b09 (cosmetic if the hash isn't checked; still
   breaks the hash if it is). Find one: `strings -t d /firmware/image/modem.b09 | grep -iE 'CRMBuilds|modem_proc|/b/' | head`. Pick an offset in the middle of such a string, then:
   `perl -e 'open(F,"+<","/firmware/image/modem.b09")||die;seek(F,OFF,0);read(F,$b,1);printf "was 0x%02x\n",ord($b);seek(F,OFF,0);print F chr(ord($b)^0x01);close F'`
   Verify the on-disk byte changed (re-read it). `sync`.
4. **Reboot**, reconnect (poll ping; `echo 1|sudo tee /sys/bus/pci/rescan` if USB drops).
5. **Verdict:** after modem init (~30–60s), does modem QMI work?
   `qrtr-lookup | awk '$4==3'` shows modem services AND `perl /tmp/q.pl <DMS_port> 0045` returns a valid cap?
   - **Modem loads + QMI works → signature NOT enforced → RFC editing is VIABLE → Phase 2.**
   - **Modem dead (no node-3 services / DMS no response) → enforced → restore + STOP (need signing key).**
6. **Restore regardless:** `cp /mnt/userrw/modem.b09.orig /firmware/image/modem.b09; sync; reboot`; confirm
   modem back + sha1 restored. (Only skip restore if Phase 1 passed AND you go straight to Phase 2 editing.)

### PHASE 2 — (only if Phase 1 passes) Edit the RFC to declare n78
Deep RE of the RFC data in modem.b09: find the **active mr6500 bid's** NR band-support list/mask and the
per-band RF-device/path table, then add n78 mapped to the **n77 RF path** (device/port/sub_band entries
n78 needs, cloned from n77). This is the hard part; may want a Fable-5 subagent on `modem_mtd20.bin`/`modem.b09`
to map the RFC struct (start from symbols `rfc_hwid895_de_2xmagnus_bid1_mr6500_dv2_att_ag_sub_band_array_NR5G_77`
and `..._freq_array_NR5G_41`, and the board's supported-band table). Also may need matching RFNV cal for n78
(efs2, editable) — clone n77's if the driver requires a cal entry.

### PHASE 3 — Verify
Reboot; `perl /tmp/q.pl <DMS_port> 0045` → NR list should gain **78** (`4e00`). If present, set NR band pref
via QMI NAS SSP / AT!BAND to actually camp n78 and test throughput.

---

## Context / gotchas for continuity (not fully in other docs)
- **Access:** telnet 192.168.3.1:23 = passwordless root; `python3 ~/mr6500-checkpoint/scripts/dev.py '<cmds>'`.
  Device has perl, `nandwrite`, `flash_erase`, `ubiupdatevol`, `qrtr-lookup`; NO `nanddump`; MEMREADOOB =
  "not supported" (can't read NAND OOB from AP). `/tmp` clears on reboot; `/mnt/userrw` persists.
- **File transfer:** host `nc` is OpenBSD (`-l -p` = source-port bug, don't use to listen — use python recv
  `scratchpad/recv.py` OR reverse direction). Device can't route OUTBOUND to host 192.168.3.4 ("no route to
  host"), so **device must SERVE, host PULLS**: device `dd … | nc -l -p 9099`, host `nc 192.168.3.1 9099 > f`.
- **On-device modem-EFS write WORKS** (proven): `flash_erase /dev/mtd2 <off> 1` + `nandwrite -s <off> /dev/mtd2 <file>`; no OOB/CRC problem. (But EFS edits don't change capability — see N78 experiment.)
- **QRTR ports reassign every boot** — always `qrtr-lookup` for the current DMS port (svc2) before querying.
  DMS band cap = `perl /tmp/q.pl <port> 0045`; NR list is TLV 0x13; n78 present iff `4e00` in the list.
- **Current device state:** healthy; benign n78 bit left set in `limited_bands` NR masks (blocks 2 & 30,
  byte9=0x30) — ignored by modem, harmless. Modem/QMI fine.
- **Host backups:** `efs2_now.bin` (23MB pre-patch efs2, sha1 88374ddd…), `modem_mtd20.bin` (128MB modem UBI,
  sha1 6754f136…), `efs2_backup.bin` (older efs2), `swiapp.bin`, fdt/QPST/QXDM/mrCONFIG in ~/Downloads.
- **Board id:** RFC has mr6500 variants bid1 `dv2_att`, bid3 `dv33_att`, bid11 `att_pc2`; this unit's active
  bid is TBD (read at Phase 2). base="hardware" today = {2,5,12,14,29,30,66,77,258,260} (the AT&T set).
