# RFC (RF-card) band-viability analysis — mtd20 "modem" partition (2026-07-05)

Read-only settle of the make-or-break: does the AT&T MR6500 board's RF hardware physically support the
missing bands? Source: `modem_mtd20.bin` (128MB UBI dump of mtd2 0="modem"; sha1 6754f136…). The modem
firmware's **RFC (RF-card) config carries readable symbols** naming per-board, per-band RF structures.

## Method
The RFC is **multi-board**: symbols like `rfc_hwid895_de_2xmagnus_bid1_mr6500_dv2_att_ag_<TYPE>_NR5G_<band>`.
Board variants seen: **mr6500** (bid1 `dv2_att`, bid3 `dv33_att`, bid11 `att_pc2`), mr6550 (bid14/17),
mr6150 (bid9/15), mr6110 (bid2/5). `<TYPE>` distinguishes a mere **frequency definition** (`freq_array`)
from a real **RF path/calibration** array (`sub_band_array`, `trx_sub_band_array`, `tx_path_info`,
`lna_gain_state_array`, `res_alloc_info`, `_ca_N`). A band is physically routable only if it has the
path/cal arrays, not just a freq_array. Validated on controls (bands enabled TODAY): n66/n77/n78 → PATH ✓.

## Result — mr6500 (AT&T) board NR5G bands
| band | mr6500 RFC | note |
|---|---|---|
| n77 | **PATH** (8 syms, `trx_sub_band_array_nr5g_77`) | enabled today |
| n78 | **PATH** (`sub_band_array_nr5g_78_ca_9`) | **RF-viable but currently cache-disabled → an achievable new band** |
| n66 | PATH | enabled today |
| n40 | PATH (`nr5g_band40_lna_gain_state_array`) | RF-viable |
| n28 | PATH (`nr5g_band28_lna_gain_state`) | RF-viable |
| **n41** | **freq_array ONLY — no path array found on mr6500** | present in the frequency plan, but no `sub_band_array`/`lna_gain`/`tx_path` tagged to mr6500 → **leans NOT routable** |
| **n48** | **ABSENT** (0 mr6500 symbols) | not in this board's RFC at all |
| **n71** | **ABSENT** (0) | not in this board's RFC |
| **n25** | **ABSENT** (0) | not in this board's RFC |

For contrast, n41 **path** arrays (`sub_band_array_NR5G_41`, `trx_sub_band_array_NR5G_41`) DO exist —
but only under **mr6550 / mr6150 / mr6110** boards, never mr6500.

## Verdict (with honest caveat)
- **Definitive:** n48, n71, n25 are **not in the AT&T MR6500 board's RF config** → hardware-absent, not
  unlockable by any software/EFS/firmware edit.
- **Definitive positive:** **n78** (and n40, n28) have real RF paths on this board and are only disabled by
  the stale `limited_bands` cache → a cache-clear/EFS edit could genuinely enable them (esp. **n78**, a
  C-band that shares the existing n77 front-end).
- **n41 (the primary T-Mobile target): leans NO, not proven.** It has a `freq_array` (so it's in the
  frequency plan) but no RF-path array is tagged to any mr6500 bid — while n77/n78 clearly are. CAVEAT:
  symbol→board association is imperfect (RF-path arrays aren't always board-tagged; e.g. the enabled n66
  also shows only a freq_array near "mr6500"), so absence isn't 100% proof. A definitive answer needs a
  proper parse of the RFC data structure (which band-configs the mr6500 board object actually references).

## Implication for the user's goal (T-Mobile)
T-Mobile's key bands: **n41 (leans no), n71 (absent), n25 (absent)** → this AT&T board is very unlikely to
work as a T-Mobile 5G device regardless of any unlock. The clearly-achievable new band is **n78** (C-band,
not a T-Mobile mid-band). This matches Rich's "bands can be injected/seen but won't stay/work" — for the
T-Mobile bands, the RF front-end paths aren't present.

## To settle n41 definitively
Parse the RFC config object for the active mr6500 bid (read which `rf_device`/band-config entries its NR
band list references) — deep but tractable RE of the modem image. Or, empirically, clear the cache and
watch whether the regenerated `limited_bands` includes n41 (needs the EDL write path).
