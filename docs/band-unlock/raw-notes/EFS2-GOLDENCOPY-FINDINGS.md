# EFS2 golden-copy / band-capability analysis (2026-07-05) — blocker #2

Target: `efs2_backup.bin` (23,592,960 B = 0x1680000, RAW `efs2`/mtd2 dump, **main data area only, no NAND OOB/spare**).
Goal: pinpoint the authoritative band-capability source, the exact NR-mask edit for n41, RF viability, and craftability.

TL;DR: The NR band masks are found and decoded (edit bytes given below). But editing them is **proven-clamped**: the
real gate is the **`/policyman/persisted_items/limited_bands` cache**, which is the RF-driver `base="hardware"` report
frozen into EFS and never regenerated. **No copy anywhere in the 23 MB dump — 62 pref copies + 2 cache copies + all
log history — ever contains n41/n48/n71/n78.** RF calibration exists in efs2 but is compressed sparse binary with no
recoverable per-band schema, so n41 physical viability can't be proven from efs2 alone (the make-or-break is still RF).
A clean targeted edit is **not craftable** from this OOB-less dump; see §5.

---

## 0. EFS2 record framing (decoded, so every number below is trustworthy)

The mmode NV items are stored as a serialized directory. Each record:

```
[A][B] 64 dc 00 00 00  <name>  6e ff 01  <value>
        ^^^^^ 5-byte magic         ^^^^^ 3-byte value marker
  A = len(name)+5     B = len(value)+3
```
Verified against many records (e.g. `allow_cs_page_during_mt_volte_call` A=0x27=34+5; `custom_emerg_info`
B=0x0f=12+3). **Band bit layout (confirmed against known values):** band *N* → bit *(N-1)*, little-endian byte
order, i.e. byte *k* carries bands *8k+1 … 8k+8*. LTE pref = 8 bytes (bands 1-64) + a `lte_bandpref_ext_65_256`
of 24 bytes (bands 65-256). NR pref/cache = 64 bytes (512 bits, bands 1-512, no ext needed).

Sanity check: `lte_bandpref = 5f 28 00 30 00 a0 00 00` → {1,2,3,4,5,7,12,14,29,30,46,48}; its `..._ext` byte0=0x02 →
b66. Full LTE = {1-5,7,12,14,29,30,46,48,66} = **exactly** the enforced DMS LTE capability. Framing/layout locked.

---

## 1. The NR band mask ("5G_bandpref") + exact edit to add n41/n48/n71/n78

There is **no literal `5G_bandpref` string** in this firmware. The NR masks are the mmode NV items:

| item (`/nv/item_files/modem/mmode/…`) | copies | 64-byte value → bands |
|---|---|---|
| `nr_band_pref` (NR **SA**) | 62 valid | **all zeros** (empty ⇒ "no SA override / allow all capable") |
| `nr_nsa_band_pref` (NR **NSA**) | 62 valid | **{2,5,12,14,29,30,66,77,260}** |

First copies: `nr_band_pref` name @ **0x4f67a**, `nr_nsa_band_pref` name @ **0x4f6d0** (value @ **0x4f6e3**).
All 62 copies of each are identical (log history + backups). `nr_nsa_band_pref` value:

```
current: 12 28 00 30 00 00 00 00 02 10 00...00 [byte32]=08 00...   → {2,5,12,14,29,30,66,77,260}
```

**Bit positions to ADD:** n41→byte5 bit0 (0x01) · n48→byte5 bit7 (0x80) · n71→byte8 bit6 (0x40) · n78→byte9 bit5 (0x20).

**Exact edited `nr_nsa_band_pref` value (only 3 bytes change):**
```
byte5: 00 → 81   byte8: 02 → 42   byte9: 10 → 30
edited: 1228003000 81 0000 4230 000000000000000000000000000000000000000000000000 08 000000...
        → {2,5,12,14,29,30,41,48,66,71,77,78,260}
```
(Do the same 3-byte edit to `nr_band_pref` if you also want SA n41: bytes5/8/9 → 81/40/20.)

**But this edit alone does nothing** — see §2/§4 (proven on-device: pref masks are intersected with the cache).

---

## 2. The AUTHORITATIVE capability source = the RF-driver "hardware" report, frozen into `limited_bands`

The policyman rule chain (all greppable in the dump) resolves NR bands like this:

- Carrier policy (TMO, `base="hardware"` @0x6271fe): `<define_fullrat_config> <rf_bands base="hardware"/> <rat_capability base="hardware"/>`
  → **`base="hardware"` = the band set the RF driver reports as physically supported** (computed live from the RFC /
  RF-card config, which lives in the **`modem` partition, not efs2**, plus this unit's RF cal).
- `hardware_band_filtering.xml` (`disable_sa_mmwave` config; "Remove NR SA mmWave" comment @0x313029) is **Netgear-opened
  to pass-through**: `<nr5g_sa_bands> 0-255 </nr5g_sa_bands> <nr5g_nsa_bands> 0-511 </nr5g_nsa_bands>` (the restrictive
  original is commented out between `<!-- NTGRSTART -->`/`NTGRSTOP`). It filters nothing.
- `generic_band_restrictions.xml` (@0x3a3ba7) only `<exclude>37</exclude>` for LTE and disables some GSM; NR uses
  `base="current"` with **no exclusions**.

So the NR set = whatever `base="hardware"` returns, unmodified. The **only place that set is materialized in EFS** is the
resolved cache **`/policyman/persisted_items/limited_bands`** (full path appears exactly **2×**: @**0x90782** and
@**0x9c46b5** = current + one prior log version). Its struct (offsets relative to path start @0x90782):

| field | file offset | value | bands |
|---|---|---|---|
| LTE mask (8 B) | 0x907c0 | `5f 28 00 30 00 a0 00 00` | {1,2,3,4,5,7,12,14,29,30,46,48} |
| NR mask #1 (64 B, sub-6) | 0x907e8 | `12 28 00 30 …` | {2,5,12,14,29,30,66,77} |
| NR mask #2 (64 B, +mmW) | 0x90828 | `12 28 00 30 … [b32]=0a` | **{2,5,12,14,29,30,66,77,258,260}** |

**NR mask #2 = exactly the enforced DMS NR capability.** So `limited_bands` **is** the enforcement gate.

**Answer to "is it (a) RFNV presence, (b) an NV item, or (c) live RF driver?":** it is **(c) — computed live by the RF
driver via `base="hardware"`** (RFC in the modem partition + this board's RF cal). There is **no standalone
`rf_bc_config`/`supported_bands` NV item** in efs2 (searched: none). The **only editable EFS artifact** on the gate path
is the `limited_bands` cache — and because policyman **never regenerates it** (its persisted_items timestamps don't move),
whatever value is in that file *is* the capability. That is precisely why editing `nr_nsa_band_pref`/`lte_bandpref` is
silently clamped: the prefs get intersected with `limited_bands`, which lacks n41.

**Edit target that could actually stick:** the two NR blocks inside `limited_bands` (@0x907e8 and @0x90828), same 3-byte
edit as §1 (byte5→81, byte8→42/40, byte9→30/20; keep byte32=0x0a in block #2). Edited block #2:
`12 28 00 30 00 81 00 00 42 30 …[b32]=0a…` → {2,5,12,14,29,30,41,48,66,71,77,78,258,260}.

---

## 3. RF viability of n41 (the make-or-break) — UNPROVEN from efs2; strongest signal leans "not present"

- RF cal **is in efs2**, but as **`VTNV`-headed zlib-compressed blobs** (`/nv/item_files/rfnv/000XXXXX`, only **41
  numbered items**; bulk store `/nv/item_store/rfnv/rfnv.bl`,`rfc.bl`). Decompressed total ≈ **3.8 MB**; largest single
  item `00030007` = **1.19 MB**, plus 925 KB/446 KB/419 KB/389 KB/133 KB/81 KB tables.
- Structure of the big blob = a **sparse indexed table (~90.6 % zeros)** of fixed records — consistent with a
  per-band/per-path cal grid where only *populated* (calibrated) bands are non-zero. **But there are no band-name
  strings** (236 strings total in 3.8 MB) and **no recoverable RFNV band-index schema**, so I cannot point at "n41's
  slot" and say calibrated/empty from efs2 alone. Determining that needs the Qualcomm RFNV IDL for SDX65.
- **Strongest efs2 evidence:** a global scan of the whole 23 MB dump finds **0** NR-mask blocks containing
  n41/n48/n71/n78 — not in any of the 62 pref copies, not in either `limited_bands`, not in any log-history version.
  Every band artifact on this unit encodes the AT&T set. n41 (2.5 GHz TDD) is a T-Mobile band AT&T never ships.
- **Caveat that keeps this honest:** all that history reflects the *AT&T-era* RF report; it does **not** prove what the
  now-flashed **GENALL** firmware's RF driver would report, because the deciding RFC is in the `modem` partition (not in
  this dump) and depends on the physical RF front-end. **Verdict: efs2 cannot confirm n41 RF viability; the consistent
  absence + AT&T-irrelevance of n41 leans "no RF path," but this is not proof.** This is the make-or-break and must be
  settled by RF cal parsing or an on-device RF test, not by editing masks.

---

## 4. Authoritative vs cache vs log-history — which copies must change

- **`limited_bands` (2 log copies, @0x90782 current / @0x9c46b5 prior)** = the **enforcement cache**. It is authoritative
  for capability and is never rebuilt on its own. The `nr_*_band_pref`/`lte_bandpref` prefs are **secondary** (intersected
  with it → clamped).
- The **62 identical `nr_nsa_band_pref` copies** (and 62 `nr_band_pref`, 58+4 `lte_bandpref`) are **EFS2 log-structured
  history + the alternate/backup FS**, spread across the data region (0x0–0x1480000), *not* a separate partition. The 4
  LTE outliers (`5f28**33**00a00000` = adds b25/b26) are a stored alternate profile, still no n41.
- **No band data lives in the superblock region** (`EFSSuper` @0x1480008/0x14C0008/0x1500008, spaced 0x40000) — that's
  pure EFS2 metadata.
- **The "~hourly golden-copy auto-restore"** is the running modem flushing its **RAM NV cache** back over the partition
  (why a live raw-write reverts; why EDL / modem-off is mandatory) and the EFS2 **primary↔alternate backup**. To make a
  change stick you must edit the copy the modem **reads on boot** (the latest EFS2 log version selected via the
  superblock/log chain) **and** keep the alternate/backup consistent — or delete `persisted_items` so nothing survives to
  restore. Editing a single arbitrary copy will be reverted.

---

## 5. Editability / craftability — NOT cleanly craftable from this dump

Good news: EFS2's **logical metadata is in-band** (in the main area we have): log-page headers magic **`a0 3e b9 a7`**
(303 pages, all 4 KB-aligned), superblock magic **`EFSSuper`** (page size field = `00 10 00 00` = 4096). So the structure
is *readable*.

Blockers to a targeted band edit:
1. **No OOB/spare in the dump.** NAND OOB holds ECC + bad-block markers (+ possibly page tags). Firehose **regenerates ECC
   on write**, so a bit-patch of the main area is *physically* writable — but you can't verify OOB-resident tags aren't
   relied upon, and you can't reproduce the exact page programming without them.
2. **Which copy is live?** EFS2 selects the current version via superblock → log/cluster-chain traversal. Patching the
   wrong (stale) copy does nothing. Following the chain to the authoritative page needs a **real EFS2 parser**.
3. **Per-page CRC.** EFS2 pages carry checksums that must be recomputed after any edit.
4. **Backup/alternate + RAM-flush restore** (see §4) must be handled or the edit reverts.
5. **Tooling:** no open-source EFS2 *image packer* exists. `P1sec/QCSuper` (`--efs-shell`) and `openpst` do EFS **over
   DIAG** — **gated here** (BAD_SEC_MODE). `bkerler/edl` does **raw partition R/W over firehose** — no EFS2 semantics.
   So there is no tool that will take this OOB-less dump, edit a band, and emit a valid writable EFS2 image.

**Craftability verdict:** a surgical band-bit edit is **not realistically craftable** from this main-area-only dump.
The tractable EDL routes are (a) **delete `/policyman/persisted_items/`** and let policyman regenerate — but that only
adds n41 **iff** the RF driver now reports it (which §3 says it historically has not), or (b) rewrite the **entire** efs2
with a consistently-edited, CRC-correct, log-consistent image (large EFS2-RE effort, and still ECC/OOB-risky).

---

## 6. Single most important next step

**Settle RF viability of n41 before engineering any EFS2 write.** Concretely: transiently force the capability to include
n41 on the *live* modem (inject the §1/§2 edit into `limited_bands`/prefs via the modem's own NV path, or delete
`persisted_items` to force a regen) and then check whether the modem can actually **RF-lock / measure n41** (DMS band
capability gains n41 *and* an NR n41 measurement/attach succeeds). If n41 has no RF path, every EFS edit above is moot; if
it locks, then the (hard) full-image EFS2 rewrite in EDL becomes worth building. Everything hinges on this one RF test —
the masks are solved, the gate is identified, but the physics is unconfirmed.

### Key offsets (file offsets into efs2_backup.bin)
- `nr_nsa_band_pref` (first copy): name @0x4f6d0, value @0x4f6e3 — value `12 28 00 30 00 00 00 00 02 10 …[b32]=08`
- `nr_band_pref` (first copy): name @0x4f67a, value @0x4f689 — all-zero 64 B
- `lte_bandpref` (first copy): name @0x4f308, value @0x4f317 — `5f 28 00 30 00 a0 00 00`
- `limited_bands` persisted file: path @0x90782 (current) / @0x9c46b5 (prior); LTE @0x907c0, NR#1 @0x907e8, NR#2 @0x90828
- EFS2: log magic `a03eb9a7` ×303 (4 KB-aligned); superblocks `EFSSuper` @0x1480008/0x14C0008/0x1500008
- RF cal: `VTNV`+zlib; largest item `00030007` decompresses to 1,187,617 B (sparse, ~90 % zero)
