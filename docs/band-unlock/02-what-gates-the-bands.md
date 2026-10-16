# 02 — What actually gates the bands

The single most important result of this project: **the modem's band capability is derived *live*
from the RF driver, not stored in any editable software layer.** We reached it by eliminating every
software layer one at a time.

## The measurement

Everything is judged against one ground-truth query: **QMI DMS Get Band Capability (`0x0045`)**,
read on-device over QRTR. For this AT&T unit it returns, unchanging:

- **LTE:** `{1, 2, 3, 4, 5, 7, 12, 14, 29, 30, 46, 48, 66}` (TLV `0x10` mask `0x0000A0003000285F`)
- **NR5G:** `{2, 5, 12, 14, 29, 30, 66, 77, 258, 260}` (TLV `0x13` list)

If a change doesn't move *this*, it didn't unlock anything. Note it already includes **n77 and b48**
(C-band/CBRS) — AT&T ships those.

## The elimination chain

Each layer below was tested and ruled out as the gate:

1. **Netgear `ntgnv` band tables** (`/mnt/userrw/ntgnv/BAND_INFO*`, `SA_BAND_INFO`, `FN_FR1_BANDS_*`).
   `swiapp` reads `BAND_INFO_V2` and programs the modem via QMI NAS
   `SET_SYSTEM_SELECTION_PREFERENCE`. `AT!BAND=?`/`AT!BAND?` mirror these. **Ruled out:** they're an
   *input to a preference*, and the modem clamps preferences to its capability (step 4). Editing them
   can't add a band the modem doesn't already advertise.

2. **Active mcfg carrier config** (`/firmware/image/modem_pr/mcfg/…`). The active config-id
   (`PDC GET_SELECTED 0x0022`) resolved to **T-Mobile's** `mcfg_sw.mbn` — yet capability still lacked
   T-Mobile's core bands (n41/n71). **Ruled out:** mcfg does not drive capability. Also, an
   exhaustive mask-scan of the mcfg files never found the AT&T mask.

3. **`policyman/persisted_items/limited_bands`** (a cache in `efs2`). Its enforced NR mask equals the
   DMS set exactly, so it *looked* like the gate — the community's leading theory. **Disproven by
   direct experiment:** we patched n78 into it on raw NAND, it survived reboot, `policyman` read the
   patched value — and DMS capability **did not change.** Full writeup: [03](03-efs-limited-bands-experiment.md).
   `limited_bands` only *mirrors* the live set; it doesn't drive it.

4. **QMI NAS band preference** (`SET_SYSTEM_SELECTION_PREFERENCE 0x0033`). Setting a wider LTE mask
   (adding B25/B26, which reuse B2/B5 RF) returned `SUCCESS` but the read-back (`0x0034`) showed the
   extra bands **silently stripped** back to the AT&T set. **Ruled out:** the preference layer cannot
   widen capability; the modem enforces capability as a hard gate above it.

5. **`swiapp` NV backup/restore / svc21 (modem-EFS QMI service).** Reverse-engineering plus live
   `strace` showed `swiapp`'s "fm"/`nvrestore` layer writes **local files under `/mnt/userrw`**, not
   modem EFS, and **no AP process ever talks to svc21** (port 9). svc21 is a dormant diagnostic
   service with no resident client. **Ruled out** as a path. Details: [06](06-write-paths.md).

## What's left standing: `base="hardware"`

With every software layer eliminated, the source is the RF driver's own capability report. In
`policyman` terms this is the **`base="hardware"`** set, and it is:

```
base="hardware"  =  RFC  ∩  RFNV
```

- **RFC** = the **RF-Card configuration** — a data structure compiled into the **signed `modem`
  partition** (`mtd20`) that declares, per board variant, which bands each RF path supports. This is
  the real band whitelist. See [04](04-rfc-band-viability.md).
- **RFNV** = per-unit **RF calibration** (in `efs2`): factory-measured PA/LNA/antenna tables. A band
  only works if it's both *declared* (RFC) and *calibrated* (RFNV) for a physical RF path that
  exists on the board.

The `policyman` **rules** are permissive (Netgear opened `hardware_band_filtering.xml` to
0-255 / 0-511), so the rules are *not* the wall — they pass through whatever `base="hardware"`
reports. The wall is `base="hardware"` itself.

## Why this is the wall, concretely

- To widen capability you must change the RFC. The RFC is in a **signed** image, and the modem
  **refuses to load if any byte changes** — proven in [05](05-secure-boot-test.md). Re-signing needs
  Qualcomm/Netgear's private key.
- Even *with* a signed RFC edit, a band also needs valid **RFNV cal** for a **physical RF path**.
  For this board only **n78** has a physical path (it's a subset of the working n77 path); **n41,
  n71, n25** have no RF path at all, so no software or firmware change can bring them up.

**Conclusion:** the missing bands are gated at the modem's live RF-capability layer, sourced from a
signed file plus per-unit calibration bound to physical hardware. This is why no app-, NV-, mcfg-, or
cache-level edit has ever worked — for anyone.
