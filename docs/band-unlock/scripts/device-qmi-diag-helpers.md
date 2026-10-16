# Device-side perl helpers (run ON the device via telnet; device has perl, no python)
# Push to /tmp on the device, e.g. with dev.py heredoc or nc. See RE-PROMPT.md for q.pl and draw.pl.
# QMI-over-QRTR: AF_QIPCRTR=42, modem=node 3. QMI msg (over QRTR) = flags(1) txn(2LE) msgid(2LE) len(2LE) TLVs.
# Ports (qrtr-lookup): DMS=81 NAS=65 WDS=70 UIM=68 PDC=25 svc21(modem-EFS)=9 DIAG(MODEM:CMD)=17 AT=73
# Verify unlock:  perl /tmp/q.pl 81 0045   (DMS Get Band Capability; TLV 0x13 = NR band list)
# Read NAS band pref/masks: perl /tmp/q.pl 65 0034  (TLV 0x15/0x23=LTE, 0x2c/0x2d=NR pref, 0x2e=wide NR list)
# DIAG version test:  perl /tmp/draw.pl 17 00
# DIAG legacy NV read (ungated), item N: pack cmd 0x26 + item(2LE) + 128*00 + 0000
# EFS2 subsys (gated, returns BAD_SEC_MODE 0x15):  perl /tmp/draw.pl 17 4b1300000000
