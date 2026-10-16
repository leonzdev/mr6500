# Bands
Try to add more LTE / 5G bands

This requires access to NV ram, probably using QPST

Currently available bands
```bash
at !band=?
at !band=?
Index, Name,         GW_Mask          LTE_1-64         LTE_65-128       NSA_1-64         NSA_65-128       NSA_257-320      SA_1-64          SA_65-128        SA_257-320       Mode
00, 4G+5G,           0000000000000000 0000A0003000285F 0000000000000002 0000000030002812 0000000000001002 0000000000000008 0000000000000000 0000000000000000 0000000000000000 1
01, 4G,              0000000000000000 0000A0003000285F 0000000000000002 0000000000000000 0000000000000000 0000000000000000 0000000000000000 0000000000000000 0000000000000000 1

                                      0000800000000000 - LTE B48    
                                      0000200000000000 - LTE B46    
                                      0000000020000000 - LTE B30    
                                      0000000010000000 - LTE B29    
                                      0000000000002000 - LTE B14    
                                      0000000000000800 - LTE B12    
                                      0000000000000040 - LTE B7     
                                      0000000000000010 - LTE B5     
                                      0000000000000008 - LTE B4     
                                      0000000000000004 - LTE B3     
                                      0000000000000002 - LTE B2     
                                      0000000000000001 - LTE B1     
                                                       0000000000000002 - LTE B66    
                                                                        0000000020000000 - NR5G N30    
                                                                        0000000010000000 - NR5G N29    
                                                                        0000000000002000 - NR5G N14    
                                                                        0000000000000800 - NR5G N12    
                                                                        0000000000000010 - NR5G N5     
                                                                        0000000000000002 - NR5G N2     
                                                                                         0000000000001000 - NR5G N77    
                                                                                         0000000000000002 - NR5G N66    
                                                                                                          0000000000000008 - NR5G N260   
```

Currently selected bands
```bash
at !band?
at !band?
Index, Name,         GW_Mask          LTE_1-64         LTE_65-128       NSA_1-64         NSA_65-128       NSA_257-320      SA_1-64          SA_65-128        SA_257-320       Mode
00, 4G+5G,           0000000000000000 0000A0003000285F 0000000000000002 0000000030002812 0000000000001002 0000000000000008 0000000000000000 0000000000000000 0000000000000000 1
```

On many Qualcomm devices bands modification can be done by editing `carrier_policy.xml` or other configuration files in EFS NV.
  * https://tech.ssut.me/qualcomm-modem-configuartion-mbn-with-carrier-policy-description/
  * https://mt-tech.fi/en/modify-oneplus-7-pro-5g-8-and-8-pro-nr-lte-a-band-combos/

On MR6500 in EFS, `policyman/persisted_items/limited_bands` and `rat_mask` both contain the band masks. However, they are refreshed on reboot.
  * Source: https://xdaforums.com/t/guide-enabling-volte-vowifi-deprecated.4023529/post-81403537
  * Doubt it - I rebooted the device and those item's update time did not change
    * TODO: maybe put in a SIM card and reboot?

However for MR6500, it seems that the restriction is coded in modem firmware
  * https://wirelessjoint.com/viewtopic.php?t=4119
  * TODO: use QXDM to confirm
    * https://xdaforums.com/t/guide-enabling-volte-vowifi-deprecated.4023529/post-81403537
    * This post seems helpful with alternatives to QXDM (SCAT): https://mt-tech.fi/en/how-to-get-4g-supported-ca-combinations-from-your-android-phone/
  * Resources on reverse qualcomm baseband firmware
    * https://bkerler.github.io/2019/11/15/bring-light-to-the-darkness/

May need to reverse engineer the firmware(s) 
  * Maybe helpful tools: https://github.com/mzakocs/qualcomm_baseband_scripts/blob/main/README.md
  * https://research.checkpoint.com/2021/security-probe-of-qualcomm-msm/

## Update: investigated end-to-end, both TODOs above answered

Full writeup: [`docs/band-unlock/`](../docs/band-unlock/README.md). Short version:

- **"`limited_bands`/`rat_mask` refreshed on reboot, doubt it drives anything" — confirmed, by direct
  experiment.** Patched n78 into `limited_bands` on raw NAND (`flash_erase`+`nandwrite` on
  `/dev/mtd2`); it survived reboot and `policyman` read it, but **QMI DMS band capability (`0x0045`)
  did not change.** It's a mirror of the live RF capability, not the source. →
  [03](../docs/band-unlock/03-efs-limited-bands-experiment.md)
- **"restriction is coded in modem firmware, TODO: use QXDM to confirm" — confirmed, without QXDM.**
  Capability is computed live as `RFC (in the signed modem partition) ∩ RFNV cal`. Proved the RFC
  can't be edited: flipped one inert padding byte in `/firmware/image/modem.b09`, and the modem
  **refused to boot** (`pil_boot failed for modem` in dmesg) — secure boot verifies the image
  signature on every load. Restored from backup, device fine again. →
  [05](../docs/band-unlock/05-secure-boot-test.md)
- RF-path analysis of the `modem` partition shows **n78 is physically reachable** (it's a subset of
  n77, which this board already runs) but **n41/n71/n25 have no RF path on the mr6500 board at all**
  — hardware-absent, not just disabled. → [04](../docs/band-unlock/04-rfc-band-viability.md)
- **Net: not software-unlockable** on this AT&T unit; needs Qualcomm/Netgear's signing key, which
  nobody has. The one untested idea with any theoretical legs — flashing a genuine MR6550's *signed*
  modem image onto a 6500 to get n78 via the shared n77 path — is written up as a next step:
  [07](../docs/band-unlock/07-mr6550-fsg-nextstep.md).

