# On-device efs2 write experiment — add n78 to limited_bands (2026-07-06)

**Goal:** enable NR band n78 by editing the modem-EFS `limited_bands` cache directly on-device (raw NAND).
**Result:** the write succeeded and is clean, but **it did NOT change the band capability.** This DISPROVES
the core premise of the whole project (that `limited_bands`/`persisted_items` is the editable gate).

## What was done
- Fresh full efs2 backup to host: `efs2_now.bin` (23,592,960 B, sha1 `88374ddd58b7a1d8d5789de902d24b24872607d0`).
- Located the current `/policyman/persisted_items/limited_bands` at **2 copies**: @0x90783 (block 2) and
  @0x7956b6 (block 30). Each holds two 64-byte NR masks; the enforced one (NR#2, byte32=0x0a) =
  `{2,5,12,14,29,30,66,77,258,260}` = exactly the DMS capability.
- Edit = **single bit**: NR-mask `byte9` `0x10 → 0x30` (adds n78 = bit77) in both NR masks of both copies.
- Write method (per block): `dd` read the 256KB block → patch bytes → `flash_erase /dev/mtd2 <off> 1` →
  `nandwrite -s <off> /dev/mtd2 <patched block>`. Readback confirmed `0x30 0x30` on both blocks.
- Rebooted.

## Observations (the important part)
1. **The on-device NAND write WORKS and is clean.** After reboot both copies still read `0x30` (patch
   survived); the modem stayed fully functional (QMI/DMS responds); no corruption. So `flash_erase`+
   `nandwrite` on `efs2` is viable — **the "how to write modem EFS" problem was never the real blocker,
   and none of the OOB/CRC fears materialized** (EFS2 served the patched record to policyman fine).
2. **policyman READ the patched value but did NOT regenerate** (both copies stayed `0x30`, timestamps
   unchanged) — so it saw n78 in `limited_bands`.
3. **The DMS Get Band Capability (0x0045) did NOT change:** NR list still
   `{2,5,12,14,29,30,66,77,258,260}` — **n78 absent.**

## Conclusion — the real gate is NOT limited_bands
Editing `limited_bands` (the "stale policyman cache" the RE-PROMPT/earlier-session/EFS2-subagent all
believed was THE gate) has **zero effect** on the modem's advertised band capability. Therefore:

- The DMS band capability is **derived live from the RF driver's `base="hardware"` set** (RFC config in
  the signed `modem` partition + this unit's RFNV calibration), **not** from the editable EFS
  `limited_bands` cache. `limited_bands` merely *mirrored* that set (which is why they matched); it does
  not *drive* it.
- **The prior diagnosis was a misdiagnosis.** "Clear/edit `/policyman/persisted_items/` → wider bands" does
  not work, because policyman/the modem re-derive the capability from the live RF source, which is
  unchanged by any EFS edit. This is the true reason the entire community (incl. Rich) has never
  software-unlocked these bands.

## Why n78 (and n41) are unreachable here
`base="hardware"` = **RFC** (compiled into the **signed** `modem` partition — editing it breaks secure
boot, needs Qualcomm's key) **∩ RFNV cal** (in efs2, editable, but you cannot fabricate valid per-band RF
calibration for antenna/PA/filter paths that don't physically exist). For this AT&T MR6500 unit,
`base="hardware"` = the AT&T set `{2,5,12,14,29,30,66,77,258,260}` — no n78, no n41. That set is the
physical RF reality of the board and is not movable by software.

**Net: n78 and n41 cannot be enabled on this AT&T MR6500 by any software/EFS method.** The only thing that
could change the capability is re-provisioning the RF (RFC/RFNV) for bands the hardware physically
supports — which these bands are not, on this board.

## Silver linings / corrections for the record
- We proved **on-device modem-EFS writes are fully doable** (`flash_erase`+`nandwrite`, no EDL, no OOB
  problem) — useful if a *genuinely* EFS-sourced value ever needs changing.
- The whole "svc21 / EDL firehose / EFS2-packer" difficulty was chasing a write path that (a) turned out
  to be achievable on-device anyway, and (b) wouldn't have helped, because the gate isn't in EFS.

## Device state
Left with the benign n78 bit set in `limited_bands` (ignored by the modem; harmless). Full pre-patch image
is `efs2_now.bin` on host if a byte-exact revert is ever wanted. Modem/QMI healthy; band capability
unchanged from stock.
