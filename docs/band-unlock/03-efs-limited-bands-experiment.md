# 03 — The EFS `limited_bands` experiment (disproved the "stale cache" theory)

**Result:** editing `policyman/persisted_items/limited_bands` on-device is clean and survives reboot,
but has **zero effect** on the modem's band capability. This disproves the leading community theory
(that the lock is a stale, editable cache) and is what pointed us at the signed RFC as the real gate.
Raw notes: `raw-notes/N78-WRITE-EXPERIMENT.md`, `raw-notes/EFS2-GOLDENCOPY-FINDINGS.md`.

## Background — why `limited_bands` looked like the gate

`efs2` (`mtd2`) contains `policyman`'s persisted items. The item `limited_bands` holds two 64-byte
NR band masks and LTE masks. Its enforced NR mask decoded to **exactly** the DMS capability set
`{2,5,12,14,29,30,66,77,258,260}`, and firmware comments literally say *"Remove EFS
`/policyman/persisted_items/` whenever adding/modifying this XML."* So it was the obvious suspect:
edit it (or clear it and let `policyman` regenerate) → wider bands. Rich Hathaway's "bands revert
after ~an hour" also fit a cache story.

### Band-mask bit layout (decoded)
64-byte field, **band _N_ → bit _(N-1)_, little-endian**. To add **n78** you set bit 77 →
NR-mask `byte9`: `0x10 → 0x30`. (For reference, adding n41/n48/n71 would touch `byte5 00→81`,
`byte8 →42/40`.)

## What we did

1. Fresh full `efs2` backup to host: **`efs2_now.bin`** (23,592,960 B, sha1 `88374ddd…`) — makes the
   edit byte-reversible.
2. Located `limited_bands` at **two copies** in the log-structured EFS: block 2 (`@0x90783`) and
   block 30 (`@0x7956b6`). Each holds two NR masks; the enforced one (NR#2, `byte32=0x0a`) matched
   the DMS set.
3. **Single-bit edit** in both NR masks of both copies: `byte9 0x10 → 0x30` (adds n78).
4. Write method, per 256 KB block: `dd` the block out → patch the bytes → `flash_erase /dev/mtd2
   <off> 1` → `nandwrite -s <off> /dev/mtd2 <patched block>`. Within-block offsets:
   block 2 = `67569` & `67633`; block 30 = `87844` & `87908`.
5. Read back → both blocks showed `0x30`. **Rebooted.**

## Observations (the important part)

1. **The on-device NAND write WORKS and is clean.** After reboot both copies still read `0x30` (patch
   survived); the modem stayed fully functional; no corruption. The `MEMREADOOB`/CRC/OOB fears never
   materialized — EFS2 served the patched record to `policyman` fine. **So "how to write modem EFS"
   was never the real blocker** (contradicting a lot of prior worry — see [06](06-write-paths.md)).
2. **`policyman` read the patched value but did not regenerate** (copies stayed `0x30`, timestamps
   unchanged) — so it *saw* n78 in `limited_bands`.
3. **DMS `0x0045` did not change** — NR list still `{2,5,12,14,29,30,66,77,258,260}`, **n78 absent.**

## Conclusion

`limited_bands` is **not** the gate. The modem re-derives its advertised capability *live* from the
RF driver's `base="hardware"` (the signed RFC ∩ RFNV cal); `limited_bands` merely *mirrors* that set,
which is why they matched. Editing the mirror changes nothing.

This is the true reason the entire community — including Rich — has never software-unlocked these
bands by clearing/editing `persisted_items`: the modem overwrites/ignores it from the live RF source
on every derivation. It re-frames the whole project and led directly to the RFC investigation
([04](04-rfc-band-viability.md)) and the secure-boot test ([05](05-secure-boot-test.md)).

## Silver lining

We now know **on-device modem-EFS writes are fully doable** (`flash_erase`+`nandwrite`, no EDL, no
OOB problem) — useful if a *genuinely* EFS-sourced value (e.g. an RFNV item) ever needs changing.
The device was left with the benign n78 bit set (ignored by the modem, harmless); `efs2_now.bin` is
the byte-exact pre-patch image if a revert is ever wanted.
