# 08 — Community / forum context

How our results line up with the state of the art in the modding community (primarily the
wirelessjoint forum, thread `t=4119` and neighbors, read via a real browser — the site is
Cloudflare-gated). Short version: **the top experts have not solved this, our findings explain
*why*, and they correct two of the community's leading theories.**

## The key voices

- **Rich Hathaway** (kcphonestores / mifis.us — the recognized MR6500/SDX65 expert):
  - Can *add/see* all MR6550 bands (n41/n71/n78/n28) on a 6500, but they **"revert back to factory
    values no matter what is written,"** auto-restoring — *"the longest it ever worked for me was
    about an hour."*
  - Sep 2025: changing to 6550 firmware "does not change bands because we cannot write the secure
    parts and the important things … are backed up and re-written upon cold boot from those secure
    parts."
  - His unlock method is a **full MR6550 firmware flash via fastboot/bootloader** — explicitly **not**
    `fdt`, not `spk`/`cwe`. (⚠️ the owner here flashed GENALL via `fdt`, a different/partial load —
    possibly why bands stayed locked.)
  - Dec 2025 he speculated adding non-approved bands "should be working now that I can write secure
    parts" (untested, needed 6550/5200 dumps), but the latest word —
    **Jun 2026: "No you cannot do that at this time"** re: enabling n78 on a 6500.

- **jcbasi** (best mechanistic explanation): a **"Golden Copy System (FSG)"** protects the config; the
  modem **validates against it ~hourly and auto-restores**; it's backed up across **multiple secure
  partitions**; only a **Netgear-signed Firehose programmer (EDL/QFIL for SDX Lemur)** can write it.
  Conclusion: no permanent band unlock survives reboot/validation without that signed programmer.

## Community tools seen (none succeed)

- **`mrCONFIG`** (w1lliam) — `-bos`/`-sabo` band ops; fails with "FW limitation / Band settings
  Error."
- **`sierrakeygen`** — Sierra unlock codes; didn't work on this build.
- **QPST / QXDM** — the standard Qualcomm tools; EFS work needs diag/SPC auth this unit rejects
  (`BAD_SEC_MODE`).
- **`fdt.exe`** — Netgear's flasher; orchestrates Sahara + Firehose but needs the signed programmer
  and can't sign content ([06](06-write-paths.md)).

## Where our findings confirm the community

- **"Secure parts are re-written on cold boot" (Rich) / "validates and auto-restores" (jcbasi)** ↔ our
  [03](03-efs-limited-bands-experiment.md): EFS edits are ignored because capability is re-derived
  live from the signed RF source.
- **"Only a signed programmer can write the secure parts" (jcbasi)** ↔ our [05](05-secure-boot-test.md):
  the `modem` image is signature-enforced at load; you cannot substitute modified secure content
  without the key.
- **"Bands seen but won't stay/work" (Rich)** ↔ our [04](04-rfc-band-viability.md): most missing
  bands have no physical RF path on the AT&T board; even declared, they can't calibrate.

## Where our findings *correct* the community

1. **It's not a "stale cache" you can clear.** The popular "delete `policyman/persisted_items` → bands
   widen" recipe is wrong — proven by direct experiment ([03](03-efs-limited-bands-experiment.md)).
   The modem re-derives from the live RF source; the cache only mirrors it.
2. **The "FSG" isn't a magic band-config store you can transplant.** There's no `fsg` partition
   ([01](01-platform-and-access.md)), the band declarations are in the **signed `modem` image**, and
   RF **calibration is per-unit** — so copying a 6550's "FSG" onto a 6500 can't work cleanly
   ([07](07-mr6550-fsg-nextstep.md)). The community over-indexes on the FSG as the lock; the real
   lock is *signed RFC ∩ per-unit cal, enforced live.*
3. **Writing modem EFS was never the blocker.** On-device `flash_erase`+`nandwrite` works fine
   ([03](03-efs-limited-bands-experiment.md)); the effort spent chasing EDL/svc21/EFS2-packer write
   paths was aimed at the wrong layer.

## Net

The community consensus ("no permanent unlock without a signed SDX-Lemur Firehose programmer + a
genuine 6550 FSG") is *directionally* right about the difficulty but *mislocates the lock*. Our
experiments pin it precisely: **band capability = signed RFC ∩ per-unit RF calibration, enforced live
by the modem at every derivation and every boot.** That's why nobody — including the experts — has a
working, persistent software unlock, and why the only remaining shot (n78 via a 6550's *signed modem
image*, [07](07-mr6550-fsg-nextstep.md)) is narrow, untested, and hardware-limited.

### Reference threads
`t=4119` (Rich's firmware port), `t=4090` (n78 unlock), `t=3626` (band locking / EFS DM-command
method), `t=4224` (root/IMEI). Rich contact: kcphonestores@gmail.com / customersupport@mifis.us.
