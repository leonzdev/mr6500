# MR6500 Band Unlock — TODO

The mechanism is fully diagnosed (see `FINDINGS.md`). Only the modem‑EFS write remains.
The fix: **delete `/policyman/persisted_items/` (files `limited_bands`, `rat_mask`) in the modem EFS, then reboot** → policyman regenerates `limited_bands` from the permissive rules → wider band capability. Verify with `DMS Get Band Capability` (should then list NR n41/48/71/78).

## 1) Check EDL / `fdt` capability  (do first — could make this trivial)
Figure out exactly what flashing capability the user already has, since they flashed the 100PAS firmware:
- What is the `fdt` tool exactly? What "download mode" was used (Netgear download vs. Qualcomm EDL/9008 at USB `05c6:9008`)?
- Does it use a **firehose programmer** (signed `prog_*.mbn`/`.elf`)? If yes, EDL peek/poke or partition read/write may be possible.
- If real EDL is available: the clean move is to (a) dump `efs2`, (b) modify it with an **EFS2‑aware tool** to remove `/policyman/persisted_items/`, (c) write it back. NOTE: modifying an EFS2 image needs proper tooling — raw byte edits corrupt it (NAND OOB metadata). Investigate whether `fdt`/firehose or an open EFS2 tool can do a targeted file delete, or whether erasing just the persisted_items is possible.
- Also worth checking: does the user (or Rich's threads) have the modem **secure‑code / SPC**? With it, QXDM/QPST EFS Explorer deletes the folder in seconds (and my DIAG EFS path would unlock too).

## 2) Reverse‑engineer `swiapp`'s modem‑EFS QMI service  (the no‑EDL route)
Recover the QMI protocol that `swiapp` uses on **QMI service 21** (node 3, port 9 — "Modem embedded file system service") to do path‑based EFS file ops (`efs_stat`, open, read, write, **delete/rm**), then use it to delete `/policyman/persisted_items/` from a telnet root shell. No EDL, no secret code — this service is *not* security‑gated (swiapp is an ordinary process).
**→ See `RE-PROMPT.md` for a ready‑to‑use prompt for a fresh agent session (context, environment, tools, approach, verification, safety).**

## Verification (either route)
After clearing the cache + reboot, from a telnet root shell run the QMI DMS band‑capability query (see RE-PROMPT.md, `qmi.pl 81 0045`) and confirm the NR band list now includes 41 (and ideally 48/71/78). If it still shows only the AT&T set, the AT&T unit's RF doesn't physically carry those bands (hardware limit for that band).

## Safety net
- `efs2_backup.bin` (this folder) is a full byte image of `/dev/mtd2`. If a write corrupts EFS, the device's **Linux still boots** (rootfs is `ubi0`, not `efs2`), so telnet stays up and you can restore the image. Keep it.
