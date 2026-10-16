# 04 — RFC band viability (which bands the hardware can physically do)

Once we knew the gate was the **RFC** (RF-Card config in the signed `modem` partition), the question
became: *for bands the AT&T board doesn't advertise, is the RF front-end physically capable, or is it
truly absent?* This decides whether any signed-RFC change could ever help. Raw notes:
`raw-notes/RFC-BAND-VIABILITY.md`. Analysis input: `modem_mtd20.bin` (128 MB `modem` UBI, sha1 `6754f136…`).

## Method

The RFC carries human-readable per-board / per-band symbols of the form:

```
rfc_hwid895_de_2xmagnus_bidN_<board>_ag_<TYPE>_NR5G_<band>
```

- Multiple boards are present in the one firmware: **mr6500** (`bid1 dv2_att`, `bid3 dv33_att`,
  `bid11 att_pc2`), **mr6550** (`bid14/17`), **mr6150**, **mr6110**.
- **Crucial distinction:** a band is only *physically routable* if it has **RF-PATH arrays**
  (`sub_band_array` / `trx_sub_band_array` / `lna_gain_state` / `tx_path_info` / `_ca_N`) — not just
  a **`freq_array`** (which merely declares a frequency range, no antenna/PA/LNA/filter path).
- Validated the method on **controls** (bands enabled today): n66, n77, n78 all show PATH arrays. ✓

## Result — per band, for the mr6500 (AT&T) board

| Band | Status on mr6500 board | Meaning |
|---|---|---|
| **n77, n78, n66, n40, n28** | RF-PATH arrays present | Physically routable |
| **n78** (3300–3800 MHz) | PATH present, **cache-disabled** | **The one achievable new band** (C-band; shares the n77 front-end) |
| **n48, n71, n25** | **0 mr6500 symbols** | **Hardware-absent** — unlockable by nothing |
| **n41** (2496–2690 MHz) | **`freq_array` only, no PATH** on any mr6500 bid | **Leans not-routable** (path arrays exist only under mr6550/6150/6110) |

## The key physics insight: n78 ⊂ n77

**n78 (3300–3800 MHz) is a strict subset of n77 (3300–4200 MHz)**, and **n77 works on this board
today.** So the RF front-end (antenna tuning, PA, LNA, filters) can *physically* pass n78's
frequencies — n78 is disabled only because the RFC *declares* n77 and not n78 for the AT&T variant. It
is a **config choice in a signed file, not a hardware limit.** That makes n78 the single band where a
(hypothetical) signed RFC edit — adding n78 mapped onto the existing n77 RF path — would very likely
just work, reusing the n77 calibration.

## The contrast: n41 and the T-Mobile bands

- **n41** is the primary T-Mobile 5G target, but it has no RF-path array tagged to any mr6500 bid
  (only a frequency declaration). It *leans* not-routable. Caveat: the symbol→board association isn't
  perfect (even enabled n66 shows only a `freq_array` near the mr6500 symbols), so this is
  "very likely no," not "proven no." Settling it definitively would require parsing the RFC data
  structure to see which band-configs the mr6500 *board object* references.
- **n71 (600 MHz) and n25** are hardware-absent (0 symbols) — no path, full stop.

**Implication:** this AT&T MR6500 is very unlikely to work as a T-Mobile 5G device (n41 leans no;
n71/n25 absent). This matches Rich Hathaway's report that added bands are "seen but won't
stay/work." **The only clearly-achievable new band is n78** — and even that needs a signed RFC,
which the next page shows is unreachable.

## Bottom line

Physical RF capability is *not* the same as the advertised list, but for the missing bands the news
is mostly bad: n41/n71/n25 aren't physically there, and the one band that *is* there (n78) is locked
behind the signed RFC. So band viability alone leaves exactly one candidate (n78) that then dies on
the secure-boot wall — see [05](05-secure-boot-test.md).
