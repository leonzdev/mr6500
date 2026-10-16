# 07 — MR6550 "FSG": how to obtain it, and why a transplant still won't unlock bands

This is the one avenue left with any theoretical chance, and the honest analysis of it. If you get a
genuine **MR6550** in hand, here's exactly how you'd extract its "FSG," and — informed by the
secure-boot result ([05](05-secure-boot-test.md)) — why copying it to a 6500 hits the same walls,
plus the *one* experiment actually worth doing.

## First, a terminology correction

There is **no `fsg` partition** on this SDX65 NAND platform (confirmed — see the full MTD map in
[01](01-platform-and-access.md); no `fsg`/`modemst1`/`modemst2`/`golden`). "FSG / Golden Copy" is
borrowed from the eMMC/GPT world. On this hardware the "golden copy" is really:

- **`efs2` (`mtd2`)** — the modem EFS: RFNV calibration + `policyman` items, with redundancy internal
  to its log structure (and possibly mirrored in `sec`/`mtd26` and `ntgrpersist`/`mtd34`), and
- **the signed `modem` image (`mtd20`)** — which is where the band *declarations* (RFC) actually live.

So "obtain the FSG" concretely means **dump `mtd2` and `mtd20`** (plus `sec`/`ntgrpersist` for
completeness) off the 6550.

## How to extract it from a genuine MR6550

### Method A — root shell + `dd` (easiest; no signed programmer needed)
The 6550 almost certainly has the same passwordless root telnet the 6500 has (same QTI Linux; the
GENALL firmware that opens root came from the 6550 line). If so:
1. `cat /proc/mtd` to confirm the numbers on that unit.
2. Dump the golden set: `efs2` (mtd2) and `modem` (mtd20), plus `sec` (mtd26) and `ntgrpersist`.
3. Transfer with the **device-serves / host-pulls** trick (the device can't route outbound; host
   `nc` is OpenBSD — see [01](01-platform-and-access.md)):
   - 6550: `dd if=/dev/mtd2 2>/dev/null | nc -l -p 9099`
   - PC:   `nc <6550-ip> 9099 > efs2_6550.bin` — then verify size + sha1.
   Repeat for mtd20, mtd26, mtd34.

**Reading needs no key.** Only *writing back to the 6500* would need the signed Firehose programmer.

### Method B — EDL + signed Firehose read-back (bit-exact, authoritative)
Put the 6550 in EDL/9008 (test point, or a `reboot edl`-style trigger from root), Sahara-load the
signed `prog_firehose_sdx55.mbn` (from the `fdt` flash package — see [06](06-write-paths.md)), then
`fh_loader --read` each partition to a file. Use this if Method A's live dump looks incomplete.

Either way the deliverable is a set of partition `.bin` images.

## Why a transplant still won't deliver the bands

The secure-boot test changes the calculus the forum has been working under. Three walls:

1. **RFNV calibration is per-unit and per-physical-RF-path.** The 6550's `efs2` holds *that 6550's*
   cal for *that 6550's* transceivers/PA/antenna. Write it onto your 6500 and you've given the 6500
   **invalid cal for different silicon** (wrong power/gain tables). Calibration is factory-measured
   per device and **cannot be transplanted** between units. For a band whose RF path the 6500
   physically lacks (n41/n71/n25 — [04](04-rfc-band-viability.md)), there's nothing to calibrate at
   all; no FSG fixes that.

2. **Band capability lives in the signed `modem` image, and that's signature-enforced
   ([05](05-secure-boot-test.md)).** Copying the 6550's *`efs2`* onto the 6500 doesn't change the
   6500's RFC → capability stays 6500. To get the 6550's band declarations you'd have to flash the
   6550's **`modem`** partition, and it must pass the 6500's secure boot — the exact wall the
   byte-flip hit.

3. **The "reverts within an hour" isn't defeated by a foreign FSG.** That revert is the modem
   re-syncing its EFS caches from the live `base="hardware"` source (RFC ∩ cal), which on your 6500
   is unchanged by anything copied from a 6550.

## The one experiment actually worth a genuine 6550

Reframe from "copy the FSG" to two concrete tests:

- **The genuine unknown — does the 6550's *signed `modem` image* boot on the 6500?** If Netgear
  shares a signing root-of-trust across the two products and the image has no hardware-ID gate,
  flashing the 6550's `mtd20` (in EDL, via the signed programmer) could put the 6550's RFC on 6500
  hardware. Then the **only** band with a real shot is **n78** — because it reuses the n77 path the
  6500 already has *and is already calibrated for* (n78 ⊂ n77, [04](04-rfc-band-viability.md)).
  n41/n71 still won't work (no RF path). This is untested and is the actual crux. It fits Rich's
  experience that even full 6550-firmware flashes don't make non-approved bands stick (cal mismatch).

- **Zero-risk, high-value — use the 6550 purely as a reference dump.** Diff its `mtd20` RFC and
  `efs2` against the 6500's (we already have the 6500's `modem_mtd20.bin`). That reveals exactly
  which declarations/cal differ, and whether n78 is a *pure declaration gap* (promising) vs. also a
  *cal gap* (dead) — without risking either device. **Do this first.**

## Bottom line

Obtaining the FSG is easy (`dd` `mtd2` + `mtd20` off a rooted 6550). But per the secure-boot result,
an FSG *transplant* runs into the signing wall **plus** a per-unit-cal wall, so it won't be the clean
"copy golden copy → bands unlock" the forum imagines. The only move with a real chance is flashing
the 6550's *signed `modem` image* and checking whether (a) it boots past secure boot and (b) n78
lights up on the shared n77 path — and dumping the 6550 as a reference to diff first is the smart,
free first step.
