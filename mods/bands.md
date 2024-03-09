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
  * https://xdaforums.com/t/guide-enabling-volte-vowifi-deprecated.4023529/post-81403537

However for MR6500, it seems that the restriction is coded in modem firmware
  * https://wirelessjoint.com/viewtopic.php?t=4119
  * TODO: use QXDM to confirm
    * https://xdaforums.com/t/guide-enabling-volte-vowifi-deprecated.4023529/post-81403537

May need to reverse engineer the firmware(s) 
  * Maybe helpful tools: https://github.com/mzakocs/qualcomm_baseband_scripts/blob/main/README.md
  * https://research.checkpoint.com/2021/security-probe-of-qualcomm-msm/

