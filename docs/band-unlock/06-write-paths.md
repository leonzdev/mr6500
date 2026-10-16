# 06 — Write paths (how you *can* and *can't* write this device)

A map of every way to write persistent state on the MR6500, what each can reach, and why none of
them unlock bands. The short version: **writing was never the hard part — the signed RFC is.** Raw
notes: `raw-notes/FDT-FLASHER-FINDINGS.md`, `raw-notes/EDL-FSG-RECON.md`, `raw-notes/SVC21-FINDINGS.md`.

## Summary table

| Path | Reaches | Gated? | Useful for bands? |
|---|---|---|---|
| On-device `flash_erase`+`nandwrite` on `/dev/mtd2` | `efs2` (RFNV, policyman) | **No** — works cleanly | No — EFS isn't the gate ([03](03-efs-limited-bands-experiment.md)) |
| Edit files on `/firmware` (ubifs `rw`) | `modem.b0*` (RFC) on disk | No (write) / **Yes (load)** | No — modem won't boot the edited image ([05](05-secure-boot-test.md)) |
| DIAG-over-QRTR `node3:port17`, legacy NV `0x26/0x27` | some NV items | No | No — can't reach policyman/RFC |
| DIAG EFS2 subsystem `0x13` | modem EFS files | **Yes** — `BAD_SEC_MODE` | Gated (needs diag auth) |
| QMI svc21 "Modem embedded file system service" (port 9) | modem EFS files | No resident client; schema unknown | Dead end (no route, and EFS isn't the gate) |
| EDL / Sahara + Firehose (`fdt` → QSaharaServer + fh_loader) | any partition, raw | **Programmer must be Netgear-signed** | Only if you also have a signed *content* to write |

## On-device NAND write — WORKS (but doesn't help)

`flash_erase /dev/mtd2 <off> 1` + `nandwrite -s <off> /dev/mtd2 <block>` writes `efs2` cleanly; the
edit survives reboot with no OOB/CRC corruption (proven in [03](03-efs-limited-bands-experiment.md)).
This retired a huge amount of prior worry about EFS2 OOB/CRC and the "hourly auto-restore." It's
genuinely useful for editing RFNV items — it just can't add a band, because band capability comes
from the signed RFC, not EFS.

## `/firmware` is writable — but the *load* is gated

`modem.b0*` sits on `/dev/ubi1_0` mounted `rw`, so you can overwrite it. But the modem's PIL
**re-verifies the signature at every load** ([05](05-secure-boot-test.md)), so an edited image simply
won't boot. Writable-on-disk ≠ loadable.

## DIAG over QRTR — partially open, EFS locked

DIAG works on `node3:port17`. **Legacy NV read `0x26` / write `0x27` are UNGATED.** But the **EFS2
subsystem (`0x13`) returns `BAD_SEC_MODE`**, and legacy SPC unlock (`0x25`) returns `BAD_CMD`. The
`0x46` password path rejects zeros; this is modern (likely ECDSA) diag authentication — uncrackable
without the key. This is exactly why the community uses EDL/9008 instead of DIAG for EFS work.

## svc21 (modem-EFS QMI service) — a dead end, fully investigated

Much early effort assumed `swiapp` used QMI svc21 (port 9) to edit modem EFS, and that reversing it
would reveal the unlock. **It doesn't:**
- Reversing `swiapp` (radare2; it's Thumb-2 PIE) + live `strace` showed its NV backup/restore ("fm"
  layer, `fmuser.c`) writes **local files under `/mnt/userrw`**, not modem EFS. Its `nvrestore`
  `sendto`s are **logging** to its own sockets, not QMI.
- A full boot-window capture of ~19 QMI daemons found **zero svc21/port-9 traffic** anywhere.
  `swiapp` talks to NAS/DMS/WMS/UIM/WDS/AT/DSD — never port 9.
- svc21 is a **dormant diagnostic service** for QXDM/QPST EFS Explorer over USB-DIAG, with no
  resident client, so its protocol can't be captured — only obtained from the modem IDL. Black-box
  probing of its 4 messages never reached a successful file op.

Even if svc21 worked, it would only edit EFS — which [03](03-efs-limited-bands-experiment.md) proved
isn't the gate. So this whole branch is void.

## EDL / Firehose (`fdt`) — the write path is *solved*, and it's not the blocker

Reverse-engineering `fdt.exe` (Netgear's flasher) showed it's only an orchestrator: for SDX65 it
shells out to stock QPST — `QSaharaServer.exe -s 13:prog_firehose_sdx55.mbn` (Sahara uploads the
**signed** Firehose programmer), then `fh_loader.exe --sendxml=…` (raw partition writes driven by a
plaintext, user-editable `rawprogram` XML). `fdt` imposes **no partition whitelist and no per-image
signature check** — which partitions get written is just XML. So in EDL (where the modem OS isn't
running to auto-restore) you can write *any* partition, including `efs2`.

**But two things remain:**
1. You need the **signed `prog_firehose_sdx55.mbn`** (it's a plain file in the `fdt` flash package —
   re-sourceable; the community's "missing piece" for Sahara). `fdt` itself holds no crypto; the
   `.secc.cwe` firmware is AES-ECB whole-file with the key in the bootloader, not in `fdt`.
2. Writing raw `efs2` doesn't help (not the gate), and writing an edited **`modem`** partition
   doesn't help either — the **PIL still verifies its signature at load** ([05](05-secure-boot-test.md)).
   EDL lets you *write* the bytes; it does not let you *sign* them.

## The takeaway

Every write path either (a) reaches only EFS/NV, which isn't the gate, or (b) reaches the signed
`modem` image, which won't load once modified. There is no write path that both reaches the RFC and
survives signature verification. That is the wall, restated from the write side.
