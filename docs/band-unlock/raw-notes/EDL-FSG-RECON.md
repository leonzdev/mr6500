# On-device recon + efs2 golden-copy analysis (2026-07-05) — after fdt.exe RE

Follows FDT-FLASHER-FINDINGS.md. Goal: locate the FSG/golden copy, its storage/reachability, the
CWE-decrypt key, and any flash artifacts on the device.

## Partition layout (device is raw NAND, MTD — NO GPT/UFS, no by-name symlinks)
`/proc/mtd` (36 partitions): sbl, mibib, **efs2 (mtd2, 0x1680000 = 23.5MB)**, tz, tz_devcfg, ddr, apdp,
xbl_config, xbl_ramdump, multi_image, multi_image_qti, aop, qhee, abl, uefi, toolsfv, loader_sti, boot,
scrub, logfs, **modem (mtd20, 0x8040000 = 128MB)**, misc, devinfo, recovery, fota, recoveryfs,
**sec (mtd26, 1MB)**, ipa_fw, usb_qti, system(ubi0 rootfs), pad1, userrw(ntgnv), hdata, cust,
ntgrpersist, ntgfota(mtd35, 353MB).

**There is NO dedicated `fsg`/`fsc`/`modemst`/`golden` partition.** The modem EFS *and* its golden/backup
copies live inside **`efs2` (mtd2)** — which we already have fully dumped as `efs2_backup.bin` (23MB).
Band-capability data (RFNV, policyman) is in efs2; the modem firmware default config is in `modem` (mtd20).

## efs2 golden/backup structure (from efs2_backup.bin)
- The AT&T LTE band mask `5f28003000a0` appears at **85 offsets** across the dump; `limited_bands`
  filename ×131, `policyman` ×242. EFS2 is log-structured so old versions accumulate, PLUS there are
  golden/backup copies — this is the forum's "backed up in multiple secure places / auto-restores." To
  change bands permanently you must change the copy the modem *restores from*, not just the live one.
- RFNV present: `rfnv` ×59, `/nv/item_files` ×15721.
- **policyman rules are PERMISSIVE** (Netgear-edited): the NR SA band filter is
  `<nr5g_sa_bands> 0-10 14-16 18-24 26-27 29-32 34-37 39-44 46-51 53-72 74 76-89 94-255 </nr5g_sa_bands>`
  which INCLUDES n41(39-44), n48(46-51), n71(53-72), n78(76-89); `<lte_bands> 0-255 </lte_bands>`;
  and an explicit `<nr5g_sa_bands base="hardware" />`. So the missing bands are NOT filtered out by the
  rules — the restriction is the **"hardware" base set / the golden copy** the rules resolve against.

## Reachability / tooling
- Device has `nandwrite`, `flash_erase`, `ubiupdatevol` (standard MTD tools). efs2/modem/sec are
  root-owned char devices → raw-writable in principle, BUT a plain write corrupts EFS2's NAND-OOB
  metadata and the running modem re-flushes its RAM cache over it (per FINDINGS.md).
- **No on-device CWE updater binary and no firehose/programmer artifacts on the device.** So the
  `.secc.cwe` AES-ECB decryption lives in the **bootloader** (uefi/abl/sbl/tz partitions — all dumpable
  from the device via nandwrite/dd or firehose read); the signed `prog_firehose_sdx55.mbn` only ever
  existed in the external fdt flash package.

## Where this leaves the two questions the user posed
- **"Can fdt write arbitrary partitions?" → YES** (see FDT-FLASHER-FINDINGS.md): fdt.exe delegates to
  `fh_loader.exe` with no whitelist/sig-check; arbitrary partition (incl. efs2) write is possible with the
  signed `prog_firehose_sdx55.mbn`, in EDL (modem OS not running → bypasses auto-restore). **The write
  path is NOT the blocker.**
- **"Is the FSG in the firmware?" → No separate FSG.** The golden copy is per-device in efs2 (we have it).
  The generic MR6550 `.secc.cwe` would only hold DEFAULT/template config, not this unit's AT&T golden copy.

## Remaining blockers (honest)
1. **Source the signed `prog_firehose_sdx55.mbn`** (+ QSaharaServer/fh_loader + XMLs) — it ships with the
   community fdt flash package the user already used once. Sourcing problem, not technical.
2. **Craft a valid modified efs2 golden copy** that changes ALL restore copies and keeps valid EFS2
   structure/OOB — the unsolved "EFS2 editing" problem (this is where even Rich is stuck as of Jun 2026).
3. **RF viability of n41 on the AT&T board** — silicon supports it (NAS SSP TLV 0x2e lists n41/48/71/77/78)
   and Rich can inject+verify bands transiently (leans "RF-capable, golden copy reverts it"), but not proven.
