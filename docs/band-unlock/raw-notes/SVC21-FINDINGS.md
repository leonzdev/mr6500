# swiapp QMI / svc21 reverse-engineering — session findings (2026-07-05)

Continuation of `RE-PROMPT.md`. Goal was: reverse `swiapp` to learn the QMI protocol of
the modem-EFS service (**QMI service 21, QRTR node 3 port 9**) so we can delete
`/policyman/persisted_items/` and unlock NR n41.

**Headline result: the RE-PROMPT's core premise is WRONG. `swiapp` is NOT a client of svc21.**
So reversing `swiapp` cannot yield the svc21 protocol. Separately, svc21 was probed live and
its message set + partial request structures were recovered, but a working file op could not be
reached by black-box probing (needs the real QMI IDL). No device state was changed.

---

## 1. How swiapp's QMI actually works (the literal question)

`swiapp` uses Qualcomm's **qmi_client framework** (not raw hand-rolled QMI):
- Imports: `qmi_client_init` ×7 (7 service clients), `qmi_client_send_msg_sync` **×76 call sites**,
  `qmi_client_notifier_init` ×7, `qmi_client_get_service_list`, `qmi_idl_get_service_id`,
  `qmi_client_message_decode` ×30, `qmi_client_release`. PLT stubs: send_msg_sync @0x2f7a0,
  client_init @0x2f8e4, idl_get_service_id @0x2ee70.
- **QMI-over-QRTR wire format** (confirmed by live strace of a swiapp launch): userspace opens an
  `AF_QIPCRTR(42) SOCK_DGRAM` socket and `sendto()`s a `sockaddr_qrtr{sq_family=42, sq_node=3,
  sq_port=<service port>}`. Message bytes = `flags(1) txn(2 LE) msgid(2 LE) len(2 LE) TLVs`;
  each TLV = `type(1) len(2 LE) value`. Response has flags bit `0x02`, indication `0x04`.
  Result TLV `0x02` = `{u16 result; u16 error}` (result 0 = success).
- At startup swiapp connects to node-3 services: **NAS(port65) DMS(81) WMS(75) UIM(68) WDS(70)
  AT(73) DSD(80) svc227(57) PBM etc.** — used for band pref, band capability, device/status.
  **It never touches port 9 (svc21).**

### swiapp's NV backup/restore is LOCAL files, not modem EFS
The functions the RE-PROMPT hoped were svc21 clients are a **local file layer**:
- `fmopengen`(fcn.0015f2d4), `fmlist`(fcn.0015ffec), `fmread/fmwrite/fmseek/fmremove` — all in
  `fmuser.c`, operating on **`/mnt/userrw/netgear/...`** via `fopen/fread/fwrite` (46 fopen, 431
  fwrite, 12 fread in the binary). `efs_stat` here is a local stat wrapper, not modem EFS.
- `nvrestorefromefsprocess`(fcn.000aa2a4) — the "cannot open file %s" function — reads a **local**
  NV-backup blob. Its 9 raw `sendto()` calls are **logging** to swiapp's two log sockets
  (`SWIAPP`, `SWIEVENT`; see the boot stderr `flogstart: logging to socket(SWIAPP)`), paired and
  with no matching `recvfrom` — they are not QMI transactions. It is only reached as a
  "File missing, using backup copy" fallback (caller fcn.000ab1a4 → fcn.000ad054).

**Conclusion:** swiapp's modem band programming goes through **standard QMI (NAS/DMS)**; its
NV persistence is **local files**. It has no svc21 code path. `RE-PROMPT.md` Approach A/B are moot.

Tooling that made this tractable: the device has **`strace`** (`/usr/bin/strace`). A swiapp
launch was captured via `strace -f -e trace=network -x` (see `scripts/svc21-probes/strace-capture.sh`)
— it decodes `AF_QIPCRTR` and shows every `sendto`/`recvfrom` node:port. Host RE used `radare2`
(binary is **Thumb-2**, PIE, computed string refs — needs `aaa`, not `aa`; plain ARM `objdump`
mis-decodes it).

---

## 2. svc21 (node3:port9) protocol — recovered by live probing

Probed directly with a perl QMI-over-QRTR client (`scripts/svc21-probes/*`, and `/tmp/q.pl` on
device). The service has **exactly 4 messages**; every other id 0x0000-0x0040 returns error
`0x39` (service "not supported"):

| msg    | request                                                                 | observed |
|--------|-------------------------------------------------------------------------|----------|
| 0x001e | none                                                                    | **SUCCESS**, returns TLV `0x10` = 7 bytes `05 00 00 00 00 c0 03` (info/version; `0x03c0`=960 maybe a max size) |
| 0x001f | mandatory TLV01 = **u16** (exactly 2 bytes)                             | value→err `0x2a` (service-specific, likely "invalid handle/id") |
| 0x0020 | TLV01 = **{u16 len; char path[len]}** + TLV02=u16 + TLV03=u32 + a 4th   | reaches MISSING_ARG through 01+02+03; 4th arg is value-constrained (unsatisfiable by zero-probing) |
| 0x0021 | TLV01 = path-like buffer (length-coupled)                              | all path encodings tried → MALFORMED/ARG_TOO_LONG; struct not recovered |

QMI error decoding used (0x02 TLV `{result,error}`): `0x01`=MALFORMED_MSG, `0x11`=MISSING_ARG,
`0x13`=**ARG_TOO_LONG** (NOT "invalid arg" — this was the key to reading the length-prefixed path
field on 0x0020), `0x39/0x3a`=not-supported/refused, `0x2a`=service-specific.

Method notes that matter for anyone continuing:
- **Use unique txn ids and verify the echoed txn** in the reply — reusing txn=1 with rapidly
  reopened sockets causes stale responses to land on the wrong probe (that produced spurious
  "INVALID_ARG vs MALFORMED" inconsistencies until fixed).
- 0x0020's TLV01 is definitively `{u16 path_len_LE; path bytes}` (no NUL needed). Confirmed by the
  length-vs-content error transitions (2 zero-bytes→MISSING_ARG, `0x4142`→ARG_TOO_LONG,
  10 zero-bytes→MALFORMED, correct `len+path`→MISSING_ARG).
- 0x0020, 0x0021 need multiple TLVs with **coupled values** (e.g. a length/count field that must
  match a data field). Black-box guessing does not converge — the real IDL is required.

**No file op ever returned SUCCESS.** Only the read-only 0x001e succeeded, so nothing was written
or deleted. Band capability re-read identical before/after (NR list still 2,5,12,14,29,30,66,77,
258,260 — no n41). Device left unchanged.

---

## 2b. Boot-time capture (2026-07-05 later) — NO AP process uses svc21

Hunted for a real svc21 client to capture genuine bytes. Result: **there is none on the AP.**
Evidence (all showed zero svc21/node3:port9 data):
- `swiapp` startup (strace) — QMI to NAS/DMS/etc., never port 9.
- `time_daemon` startup (strace) — uses the **Time service (svc13)**, not svc21.
- `init_mss` — not a QMI client at all (just `/dev/subsys_modem` PIL loader; 0 QRTR sockets).
- 20 QMI daemons, 70s steady state — 0 svc21 (only a few DMS sends; stack is quiet with no SIM).
- **Full reboot + boot capture**: wrapped `qrtr_ns.service` with strace via a *self-reverting*
  systemd drop-in (auto-removes itself so any boot problem self-heals; telnet survives QMI
  breakage). Then a 19-daemon `sendto` capture across the fresh-boot/modem-bringup window — again
  **0 sends to port 9**.
- The `qrtr` kernel tracepoints only cover the name-service and never fired (userspace `qrtr-ns`);
  strace of userspace `qrtr-ns` also captured no per-service lookups → QMI service discovery on
  this build doesn't traverse an observable NEW_LOOKUP, so that angle can't identify clients either.

**Conclusion:** svc21 "Modem embedded file system service" is a **dormant diagnostic/provisioning
service** with no resident AP client — it exists for QXDM/QPST's EFS Explorer (over USB-DIAG) and
tools like it. So there is **no client traffic to capture**; the protocol can only come from the
modem's QMI IDL or from QXDM itself.

Method notes for anyone continuing: QRTR service ports are **reassigned every boot** (DMS was 81,
became 78 after a reboot; svc21 stayed 9) — always re-run `qrtr-lookup` after a reboot before
probing. The self-reverting strace-wrapper-via-systemd-drop-in pattern (see
`scripts/svc21-probes/`) is a safe way to trace any daemon from its boot startup. Caveat: strace
launched via `setsid` for a manual daemon relaunch leaves an **orphan holding the process
singleton** — kill it by exact PID afterward or the systemd supervisor can't take over.

## 3. Where to go next (svc21 IDL is the missing piece)

Black-box probing has plateaued; the exact request structs of 0x0020/0x0021 need the QMI IDL.
Options, best first:
1. **Find a real svc21 client on the device and strace it** to capture genuine request bytes.
   On this Qualcomm AP no obvious client was found (swiapp isn't one). Worth a **system-wide /
   boot-time QRTR capture** (many Qualcomm daemons init at boot) to see if *anything* speaks to
   node3:port9. If nothing does, svc21 is only exercised modem-internally and this route is dead.
2. **Extract the svc21 QMI IDL from the modem firmware** (`/firmware/image/modem.b0*`, the MPSS).
   The IDL (message ids + TLV field descriptors) is definitive, but production Qualcomm builds are
   usually QSHRINK-stripped of strings — feasibility unverified. Would be a substantial RE task.
3. **Reconsider whether svc21 is even usable.** Its actual file ops may be access-gated (the
   `0x3a`-style "refused" responses when a message gets more complete hint at this, like DIAG
   EFS's `BAD_SEC_MODE`). If so, svc21 is a dead end like DIAG.
4. **Pivot to the EDL/firehose route** (RE-PROMPT/TODO #1, never fully assessed): the user flashed
   the 100PAS firmware via `fdt`/download mode; if that's a signed firehose programmer, a targeted
   EFS2 edit becomes possible without cracking svc21.

## Device access recap (unchanged, still valid)
- telnet 192.168.3.1:23 = root shell; device has `perl` + **`strace`**.
- `python3 ~/mr6500-checkpoint/scripts/dev.py '<cmds>'` runs shell over telnet.
- `perl /tmp/q.pl <port> <msgid_hex> [TT=hexval ...]` probes QMI; `perl /tmp/q.pl 81 0045` = DMS
  band capability (verify target: NR list gains 41).
- Full mtd2 backup remains at `~/mr6500-checkpoint/efs2_backup.bin`.
