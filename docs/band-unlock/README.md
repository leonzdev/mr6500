# Netgear MR6500 (Qualcomm SDX65) band-unlock — findings

**TL;DR — you cannot software-unlock the missing 5G/LTE bands on the AT&T MR6500.**
We proved it two independent ways by direct experiment on the device, not by guesswork.
The band list the modem advertises is derived *live* from the **signed** modem firmware's RF
configuration, and that firmware is **signature-enforced at every boot**. There is no editable
cache, NV item, or config file that widens it, and the one file that would (the RF config) can't be
changed without Qualcomm/Netgear's private signing key.

This repo documents the full investigation: what gates the bands, every avenue we tried, the two
experiments that closed the case, and the only theoretical paths left (none of them practical).

---

## The question and the answer

- **Question:** Can the AT&T-variant MR6500 be made to use bands it ships locked out of — primarily
  **5G n41** (T-Mobile 2.5 GHz) and **n78** (C-band 3.5 GHz) — by editing software/NV on the device?
- **Answer: No.** For this AT&T unit the modem's real band capability is
  `{LTE 1,2,3,4,5,7,12,14,29,30,46,48,66}` and `{NR n2,5,12,14,29,30,66,77,258,260}`, and nothing we
  can write on the device moves it.

### Why (the one-paragraph version)
The modem's advertised capability (QMI **DMS Get Band Capability**, msg `0x0045`) is computed at
runtime from the RF driver's `base="hardware"` set = **RFC** (the RF-card config, compiled into the
**signed** `modem` partition) **∩ RFNV** (per-unit RF calibration in `efs2`). The Netgear/Qualcomm
software layers above it (mcfg carrier config, Netgear `ntgnv` band tables, `policyman`
`limited_bands` cache, `AT!BAND`, QMI band preferences) can only *narrow or mirror* that set — they
cannot widen it. Editing them is silently clamped or simply ignored. The only file that could widen
it is the RFC, and it lives inside a signed image the modem refuses to load if a single byte changes.

---

## The reframe — what the community believed vs. what's true

The whole community (including the top expert, Rich Hathaway) has chased the wrong layer for years.
Two widely-held theories, both **disproven here**:

| Belief | Reality (proven) |
|---|---|
| "The band lock is a stale `policyman/persisted_items/limited_bands` cache — clear/edit it and bands widen." | Editing `limited_bands` on-device (raw NAND write, survived reboot) had **zero effect** on capability. It only *mirrors* the live RF set; it doesn't drive it. → [03](03-efs-limited-bands-experiment.md) |
| "A 'Golden Copy / FSG' holds the band config and auto-restores it; a Netgear-signed Firehose programmer can overwrite it to unlock bands." | There is **no FSG partition** here; the 'golden' data is inside `efs2`, and band capability comes from the **signed RFC**, not an editable golden copy. The ~hourly 'revert' is the modem re-syncing caches from the live RF source. → [07](07-mr6550-fsg-nextstep.md) |

Both walls trace back to the same root: **capability = signed RFC ∩ per-unit RF cal**, enforced live.

---

## Contents

| # | Page | What it covers |
|---|---|---|
| 01 | [Platform & access](01-platform-and-access.md) | The device, SDX65 internals, root telnet, full MTD map, on-device + host tooling, QMI-over-QRTR, file-transfer gotchas |
| 02 | [What gates the bands](02-what-gates-the-bands.md) | The core diagnosis by elimination: mcfg → ntgnv → limited_bands → NAS pref → **live `base="hardware"` = RFC ∩ RFNV** |
| 03 | [EFS `limited_bands` experiment](03-efs-limited-bands-experiment.md) | The on-device NAND write that disproved the "stale cache" theory |
| 04 | [RFC band viability](04-rfc-band-viability.md) | Per-board RF analysis of the `modem` partition — which bands are physically routable (n78 yes; n41/n71/n25 no) |
| 05 | [Secure-boot enforcement test](05-secure-boot-test.md) | **The headline experiment** — a one-byte flip that proves the modem image is signature-enforced |
| 06 | [Write paths](06-write-paths.md) | Every way to write the device (on-device `nandwrite` works; DIAG/svc21/EDL all gated or keyless) and why none help |
| 07 | [MR6550 FSG — the next step](07-mr6550-fsg-nextstep.md) | If you get a genuine MR6550: how to extract its FSG, and why a transplant still hits the signing + per-unit-cal walls |
| 08 | [Community / forum context](08-community-context.md) | Rich Hathaway, jcbasi's FSG theory, `mrCONFIG`/`sierrakeygen`, and how our results confirm/correct them |

Raw, chronological investigation notes (superseded in places, kept for provenance) live in
[`raw-notes/`](raw-notes/): [FINDINGS.md](raw-notes/FINDINGS.md),
[EFS2-GOLDENCOPY-FINDINGS.md](raw-notes/EFS2-GOLDENCOPY-FINDINGS.md),
[FDT-FLASHER-FINDINGS.md](raw-notes/FDT-FLASHER-FINDINGS.md),
[EDL-FSG-RECON.md](raw-notes/EDL-FSG-RECON.md), [SVC21-FINDINGS.md](raw-notes/SVC21-FINDINGS.md),
[RFC-BAND-VIABILITY.md](raw-notes/RFC-BAND-VIABILITY.md),
[N78-WRITE-EXPERIMENT.md](raw-notes/N78-WRITE-EXPERIMENT.md),
[RFC-EDIT-PLAN.md](raw-notes/RFC-EDIT-PLAN.md), [RE-PROMPT.md](raw-notes/RE-PROMPT.md),
[TODO.md](raw-notes/TODO.md).

---

## Key facts quick-reference

- **Device:** Netgear MR6500, AT&T variant `MR6500-1A1NAS`. Modem SoC **Qualcomm SDX65 / sdxlemur**
  (Snapdragon X65). Unlocked sibling = **MR6550-100PAS** (has n41/n71/n77/n78/b48…).
- **Root:** `telnet 192.168.3.1 23` = passwordless root (QTI Linux, BusyBox, armv7l). Device is
  USB-attached; host iface `192.168.3.4/24`.
- **Real capability (DMS 0x0045):** LTE `{1,2,3,4,5,7,12,14,29,30,46,48,66}`,
  NR `{2,5,12,14,29,30,66,77,258,260}`. Same even on the generic "GENALL" modem firmware.
- **The gate:** live `base="hardware"` = RFC (signed `modem`/`mtd20`) ∩ RFNV (`efs2`/`mtd2`).
- **Secure boot:** **ENFORCED.** One flipped byte in `modem.b09` → `pil_boot failed`, modem won't
  load. (Test [05](05-secure-boot-test.md).)
- **Physically reachable-if-signable band:** only **n78** (⊂ n77, which works). **n41/n71/n25** have
  no RF path on this board — unreachable regardless.

## Artifact inventory (binary dumps, for analysis/restore)

> **Not included in this repo** — these are large raw partition/binary dumps (128 MB down to ~2.5 MB)
> that don't belong in a plain git push (GitHub hard-rejects anything over 100 MB, and even the
> smaller ones aren't great fits without Git LFS). Listed here with sha1 so the writeups above stay
> independently verifiable and so these are reproducible/requestable later (e.g. via a GitHub Release
> asset or LFS) without re-doing the dumps.

| File | Size | sha1 | What |
|---|---|---|---|
| `modem_mtd20.bin` | 128 MB | `6754f136…` | Full `modem` UBI (RFC lives here) |
| `modem_b09.orig` | 2,475,128 B | `346b358c…` | The MPSS code/data segment used in the secure-boot test |
| `efs2_backup.bin` | 23.5 MB | `af7d3da5…` | `efs2` (mtd2) image, pre-any-edit |
| `efs2_now.bin` | 23.5 MB | `88374ddd…` | `efs2` image just before the n78 write experiment |
| `swiapp.bin` | 2.76 MB | `5298aec7…` | `/usr/bin/swiapp` (reverse-engineered) |

Helper scripts (included in this push): [`scripts/dev.py`](scripts/dev.py) (root-shell-over-telnet
runner), [`scripts/at.py`](scripts/at.py) (AT commands),
[`scripts/device-qmi-diag-helpers.md`](scripts/device-qmi-diag-helpers.md) (the perl QMI/QRTR
one-liners), [`scripts/svc21-probes/`](scripts/svc21-probes/) (the black-box svc21 probe scripts).

---

## Status

**Investigation complete.** Not software-unlockable. The only untested thing with any theoretical
chance is flashing a **genuine MR6550's signed modem image** onto the 6500 and seeing whether (a) it
passes secure boot and (b) n78 lights up on the shared, already-calibrated n77 RF path — see
[07](07-mr6550-fsg-nextstep.md). Everything else is a dead end without Qualcomm/Netgear's signing key.
