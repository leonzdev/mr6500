# 05 — Secure-boot enforcement test (the definitive experiment)

**Result: secure boot is ENFORCED.** Changing a single byte of the modem firmware makes the modem
refuse to boot. This proves the RFC (the band gate, [02](02-what-gates-the-bands.md)/[04](04-rfc-band-viability.md))
**cannot be edited** without Qualcomm/Netgear's private signing key — closing the last software
avenue. Plan + verdict also in `raw-notes/RFC-EDIT-PLAN.md`.

## The question this settles

The band whitelist (RFC) lives in the split MPSS ELF `/firmware/image/modem.b00`–`b09`, and those
files sit on a **writable** ubifs (`/dev/ubi1_0 on /firmware … rw`). So the RFC is *physically*
editable on disk. The only thing standing between us and an n78 edit was one unknown:

> Does the modem's PIL/MBA boot loader actually re-verify the image signature every time it loads
> the modem — or is verification skipped/absent on this unit?

`dmesg` didn't clearly show auth lines, so it had to be tested empirically. The test was designed to
be **recoverable** and to give a **trustworthy positive** (see "Why the byte choice matters").

## Method (recoverable by construction)

1. **Backed up `modem.b09` three ways**, all sha1 `346b358c263fbe0c218b7ccd1dced963f7a6eb45`:
   - host pull → `modem_b09.orig`
   - persistent on-device → `/mnt/userrw/modem.b09.orig` (survives reboot)
   - the original in place
2. **Chose an inert target byte.** `modem.b09` is 2,475,128 B and nearly all binary. It contains a
   **26 KB run of zero-padding** at `0x12991c`–`0x130000` (aligns exactly to `0x130000`). Picked
   offset **`0x12C000`** — deep inside that pad (9,956 B from the start, 16,384 B from the end),
   value `0x00`.
3. **Flipped one byte:** `0x00 → 0x01` via perl in-place write. Verified: file size unchanged
   (2,475,128), window read-back `00 00 00 00 01 00 00 00 …` (exactly one byte changed), and sha1
   now `119395a9932221624b23d6c7bbe0ac1afc4ba631` (≠ original → the on-disk content really changed).
   `sync`.
4. **Rebooted** and watched `dmesg` + QRTR.

### Why the byte choice matters
The flipped byte is **cosmetic alignment padding** — not code, not a pointer, not a length field, not
RFC data. So it can have **no functional effect** on the modem. Therefore:
- If the modem still boots → the change was tolerated (signature not enforced, or that byte not
  hashed).
- If the modem dies → the *only* thing an inert byte can trip is an **integrity/signature check**.
  A dead modem is thus a **high-confidence "enforced"** verdict, not a random crash.

## What happened

The modem **failed to load, in a hard restart loop** (`dmesg`):

```
subsys-pil-tz 4080000.qcom,mss: modem: loading from 0x90800000 to 0xa0000000
subsys-pil-tz 4080000.qcom,mss: modem: Failed to bring out of reset(rc:-22)
subsys-pil-tz 4080000.qcom,mss: modem: Failed to map memory
subsys-pil-tz: subsys_powerup(): pil_boot failed for modem
```

- The AP retried the modem subsystem every ~15 s (at 23/34/49/64 s uptime), failing every time.
- **Node-3 QMI services = 0** — the modem never came up; DMS was unreachable.
- `rc:-22` = `-EINVAL`, consistent with the TrustZone PIL authentication call
  (`pas_auth_and_reset`) rejecting the image.

## Verdict

**The modem PIL/TrustZone verifies the signed image at every load, and it is enforced.** One inert
padding byte → integrity rejection → Q6 never comes out of reset. Editing the RFC to add n78 (or
anything) breaks this signature; re-signing needs a key nobody outside Netgear/Qualcomm has. The
eFuse is blown on these AT&T 12.x units, so this extends to EDL/Firehose too — even the flashing
programmer must be signed.

**→ RFC editing is not viable. The n78-via-firmware avenue is closed.**

## Clean recovery (proof it's reversible)

Restored from the persistent backup and rebooted:

```
cp /mnt/userrw/modem.b09.orig /firmware/image/modem.b09   # sha1 back to 346b358c…
sync; reboot
```

Post-restore `dmesg`: `modem: Brought out of reset` + `pil_boot is successful from modem`. DMS
`0x0045` NR bands back to the stock `{2,5,12,14,29,30,66,77,258,260}`. **Device fully healthy.**
(The `/mnt/userrw/modem.b09.orig` copy was left in place as a safety net.)

## Combined conclusion

Two independent experiments now close the case:
- [03](03-efs-limited-bands-experiment.md): editing the EFS cache has no effect (the gate isn't there).
- **This test:** editing the signed firmware where the gate *is* → the modem won't boot.

**n78 and n41 cannot be enabled on this AT&T MR6500 by any software or on-device method — proven by
direct test, not assumption.**
