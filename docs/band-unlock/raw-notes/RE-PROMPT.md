> ⚠️ **SUPERSEDED IN PART — read `SVC21-FINDINGS.md` first (2026-07-05 session).**
> The premise below — that **swiapp uses svc21 for path‑based EFS ops** — was tested and is **FALSE**.
> swiapp's `nvbackup`/`nvrestore`/`fm` layer works on **local `/mnt/userrw` files** (fopen/fwrite);
> `nvrestorefromefsprocess`'s raw `sendto`s are **logging**, not QMI; swiapp never contacts node3:port9.
> So Approaches A/B (reverse swiapp to get svc21) will not work. svc21 was instead probed live and
> its 4‑message set + partial structs recovered — see `SVC21-FINDINGS.md` for the real state and next steps.
> The device access facts, perl helpers, and verify query below are still accurate and useful.

# Prompt for a fresh agent session — Reverse‑engineer swiapp's modem‑EFS QMI service and unlock MR6500 bands

Copy everything below the line into a new session. It is self‑contained. Read `FINDINGS.md` in the same folder for the full evidence chain, but this prompt has what you need.

---

## Mission

On a Netgear **MR6500** hotspot (Qualcomm **X65 / sdxlemur**, running flashed MR6550‑100PAS "GENALL" firmware), unlock the software‑locked NR bands (primarily **n41**). The complete diagnosis is done: the band cap is a **stale `policyman` cache** in the modem EFS at **`/policyman/persisted_items/limited_bands`** (+ `rat_mask`). The firmware's policyman *rules* are already permissive; the cache just never regenerated after the firmware flash, and every runtime band interface (QMI NAS pref, `AT!BAND`) clamps to it. **The fix is to delete `/policyman/persisted_items/` from the modem EFS and reboot** — policyman then rebuilds `limited_bands` from the permissive rules and (if the RF supports it) the wider NR set appears.

**Your job:** get a working modem‑EFS **file delete** and use it to remove that directory, then reboot and verify. The clean, no‑EDL way is the modem's own **"Modem embedded file system service"** — QMI **service 21**, on QRTR **node 3, port 9** — which `swiapp` uses for path‑based EFS file ops (`efs_stat`, open, read, write, delete). It is **not security‑gated**. Its message protocol is undocumented; **reverse‑engineer it** from `swiapp` (static) and/or capture it live (dynamic), then replicate it.

(Why not other routes: DIAG EFS is `BAD_SEC_MODE` gated = signed diag‑auth, uncrackable; legacy NV read/write works but can't reach policyman files; raw `/dev/mtd2` write corrupts EFS2's NAND‑OOB metadata; EDL needs a flasher the user lacks.)

## Environment & access

- **Host** = this Ubuntu 26.04 PC, user `leonz-agent`, **passwordless sudo**. Tools: `arm-linux-gnueabihf-objdump`, `python3`, `perl`, `nc`, `curl`, `objdump` (x86). No radare2/gdb-multiarch (install with `sudo apt-get install -y` if wanted, e.g. `gdb-multiarch`, `radare2`).
- **Files in `~/mr6500-checkpoint/`**: `swiapp.bin` (2.7 MB stripped ARM ELF, the RE target), `efs2_backup.bin` (23 MB raw dump of modem EFS `/dev/mtd2` — offline reference + restore image; sha1 `af7d3da5ba0b3c60f7cea8c335ae32f7ca8b225e`), `scripts/dev.py`, `scripts/at.py`.
- **Device** = at **192.168.3.1** over USB (host iface `enx00a0c6000000`, 192.168.3.4). `telnet 192.168.3.1 23` → **passwordless root shell** (BusyBox, armv7l). Device has **perl** (no python). AT port at :5510 (`AT!ENTERCND="A710"` to unlock AT! writes).
- Talk to the device with `python3 ~/mr6500-checkpoint/scripts/dev.py '<shell cmds>'` (runs over telnet, handles IAC + a sentinel; `-t N` sets timeout). If the USB link ever drops: `echo 1 | sudo tee /sys/bus/pci/rescan`; if still gone, ask the user to power‑cycle the hotspot (all runtime changes are non‑persistent). **Do NOT touch the USB gadget/configfs — it bricked USB once.**
- Internet from host: hotspot hijacks DNS; use `curl --resolve raw.githubusercontent.com:443:185.199.111.133 https://raw.githubusercontent.com/...`.

## The device talks QMI + DIAG directly via QRTR + perl (no extra tooling)

`AF_QIPCRTR` = 42. Modem = QRTR node 3. Push these helper scripts to the device `/tmp` (write via `dev.py` heredoc, or `nc`) and run with on‑device `perl`.

**`/tmp/q.pl` — generic QMI‑over‑QRTR client (workhorse).** Args: `<port> <msgid_hex> [TT=hexvalue ...]` (TT = TLV type hex, value = hex bytes). Prints all responses/indications from that port for 4 s.
```perl
use strict; use Socket;
my $AF=42; my $node=3; my $DG=2;
my $port=shift; my $msgid=hex(shift);
my $tlvs="";
for my $a (@ARGV){ my ($t,$v)=split(/=/,$a,2); my $val=pack("H*",$v); $tlvs.=pack("C v",hex($t),length($val)).$val; }
my $msg=pack("C v v v",0,1,$msgid,length($tlvs)).$tlvs;   # QMI (over QRTR): flags=0,txn=1,msgid,len,TLVs
socket(my $s,$AF,$DG,0) or die "sock:$!"; my $dest=pack("S x2 L L",$AF,$node,$port);
send($s,$msg,0,$dest) or die "send:$!";
printf "SENT port=%d msg=0x%04x [%s]\n",$port,$msgid,unpack("H*",$msg);
my $end=time()+4;
while(time()<$end){ my $rin=""; vec($rin,fileno($s),1)=1; my $n=select(my $r=$rin,undef,undef,1);
  next if $n<=0; my $from=recv($s,my $b,8192,0); next unless defined $from;
  my ($f,$fn,$fp)=unpack("S x2 L L",$from); printf "  RECV %d:%d [%s]\n",$fn,$fp,unpack("H*",$b); }
```
QMI response format: byte0 flags (0x02=resp, 0x04=indication), then txn(2), msgid(2), len(2), TLVs; TLV `02 04 00 <result:2 LE> <error:2 LE>` — result 0 = success. QMI error codes seen: 0x11=MISSING_ARG, 0x13=INVALID_ARG, 0x01=MALFORMED, 0x39/0x3a = not‑supported/PDC‑specific.

**`/tmp/draw.pl` — raw datagram to a QRTR port (for DIAG).** Args: `<port> <hex>`. DIAG(MODEM:CMD)=port 17. Raw diag cmd bytes work (e.g. `perl /tmp/draw.pl 17 00` → version). NV read = cmd 0x26 + item(2 LE) + 128 zero bytes + 00 00; NV write = 0x27 similarly (both ungated). EFS2 subsys `4b 13 …` = `BAD_SEC_MODE`.
```perl
use strict; use Socket; my $AF=42; my $node=3; my $DG=2;
my $port=shift; my $hex=shift; my $msg=pack("H*",$hex);
socket(my $s,$AF,$DG,0) or die; my $dest=pack("S x2 L L",$AF,$node,$port);
send($s,$msg,0,$dest) or die; printf "SENT %d [%s]\n",$port,$hex;
my $end=time()+3;
while(time()<$end){ my $rin=""; vec($rin,fileno($s),1)=1; my $n=select(my $r=$rin,undef,undef,1);
  next if $n<=0; my $from=recv($s,my $b,8192,0); next unless defined $from;
  my ($f,$fn,$fp)=unpack("S x2 L L",$from); printf "  RECV %d:%d [%s]\n",$fn,$fp,unpack("H*",$b); }
```

**Verify‑the‑unlock query — DMS Get Band Capability:** `perl /tmp/q.pl 81 0045`. Decode the response: TLV `0x12` = LTE band list (u16 count + u16 band numbers), TLV `0x13` = NR band list. Success = NR list now contains 41 (currently it's `2,5,12,14,29,30,66,77,258,260`).

`qrtr-lookup` on the device prints the full service→port map (modem=node 3): DMS=81, NAS=65, WDS=70, UIM=68, PDC(svc36)=25, **svc21 (Modem embedded FS)=9**, DIAG(MODEM:CMD)=17, AT(svc8)=73.

## RE task: crack QMI service 21 (modem EFS file ops)

Empirical probing so far (via `q.pl 9 …`): msg **0x0020** and **0x0021** exist and return `MISSING_ARG` with no TLV; with TLV `01=<path string+null>` → `INVALID_ARG`; with `01=<u32>` → `MALFORMED`. So the request struct is not a bare path/u32 — recover the real layout.

### Concrete progress already made (radare2)
`radare2` is installed on the host. String refs are PIE‑computed (`add rN, pc`), so basic analysis misses xrefs — you MUST run `aaa` with `-e anal.timeout=200` to resolve them (basic `aa`/`aar` returns no xrefs).
- The **modem‑EFS open‑by‑path function is `fcn.000aa2a4`** (r2 name; it loads the `cannot open file %s` string at `0x001cdd40` via `add r1,pc` at `0xaa758`). This is `nvrestorefromefsprocess`, which opens a modem EFS file by path via the svc‑21 client.
- Inside it, request structs of sizes `0x190` (400), `0x6f0` (1776), and small fields (0x8, 0xc) are built — i.e. the open/read flow is a **multi‑message sequence** (likely open→iovec/read→close), not one message. Trace each `bl`/`blx` to `qmi_client_send_msg_sync` here (r2 didn't auto‑name the PLT calls in the quick pass — resolve the PLT/GOT or use `aaa` then `pdf` and follow the `bl` targets), read arg2=`r1`=msg_id at each, and reverse the request struct being filled (esp. how the path string + its length go into the request → that's the TLV encoding you replicate in `q.pl`).
- Recommended: open in **Ghidra** (better struct/decomp than r2 for this) — `swiapp.bin` is here. Decompile `fcn.000aa2a4` and the write/delete siblings (find via `EFS write failed for session %d`@0x1ed87c, `nvefsbackupdelete`@0x1d0224 — resolve their xrefs with `aaa`).

### Approach A — static (disassemble swiapp)
`swiapp` imports `qmi_client_init`, `qmi_client_send_msg_sync` (76 call sites), `qmi_client_send_msg_async`. Sections (VMA==FileOff for both): `.text` @0x2fbe0, `.rodata` @0x17b0a8. It does path‑based EFS ops; relevant log strings and their file offsets (== VMA): `fmlist: efs_stat() error %d` @0x2504cb (=2426315), `nvrestorefromefsprocess: cannot open file %s` @1891683, `EFS write failed for session %d` @2021500, plus `nvefsbackupdelete`, `APSS Bad EFS read status on EFS item %d`.
Goal: find the function that logs `efs_stat()`/`open file %s`/EFS write, and read off:
  1. the **service‑21 QMI client** (which `qmi_client_init` created it — trace the service object),
  2. the **msg_id** passed to `qmi_client_send_msg_sync` (arg2 = r1) for open/read/write/**delete**,
  3. the **request C‑struct layout** (arg3=r2) → the TLV encoding (esp. how the path is passed: likely a fixed‑size struct with a length field + char array, not a bare string).
Tips: string refs are computed (movw/movt or GOT) so a naive grep for the hex address fails — search for `movw ... #0x04cb`/`movt ... #0x0025` pairs, or use radare2/Ghidra (`sudo apt-get install -y radare2`). The QMI message descriptor table for the service (an array with msg ids + TLV field descriptors) is in `.data.rel.ro`/`.rodata` — finding it yields every message at once.

### Approach B — dynamic (capture live)
Trigger `swiapp` to do an EFS op and capture the QMI it sends to node3:port9:
- `swiapp.service` is a boot oneshot that does NV backup/restore (EFS reads/writes) at init. `systemctl restart swiapp.service` on the device to make it re‑run.
- Capture via DIAG QMI logging: enable QMI log packets through the DIAG channel (`draw.pl` to port 17: DIAG LOG_CONFIG cmd 0x73 to set the log mask for the QMI log code, then read the log stream) and parse for service‑21 traffic. (More setup, but yields exact bytes.)
- Simpler if it works: check whether the device has `strace`/`ltrace` (`which strace`), or whether libqmi debug logging can be enabled via an env var when restarting swiapp, dumping QMI to a log you can read.

Once you know msg ids + request layout for **open** and **delete** (and read/write if needed), replicate them with `q.pl` (extend it to build the exact request struct) and delete `/policyman/persisted_items/limited_bands`, `/policyman/persisted_items/rat_mask` (and ideally the whole `/policyman/persisted_items/` dir). Some EFS APIs need open→op→close or a "rm/unlink by path" message — recover whichever swiapp uses.

## Execute + verify
1. Snapshot current state: `perl /tmp/q.pl 81 0045` (note NR list) and back up again if desired (`dd if=/dev/mtd2 of=/tmp/efs2.bin` then `nc` it to host).
2. Delete `/policyman/persisted_items/` via the svc‑21 protocol you recovered.
3. Reboot the device (or restart the modem subsystem if you find a clean way). Re‑establish telnet (rescan/power‑cycle if needed).
4. `perl /tmp/q.pl 81 0045` → check NR band list. **If 41 now appears, it worked** — then set the band pref to use it (QMI NAS Set Sys Sel Pref, or `AT!ENTERCND="A710"` + `AT!BAND=` with the wider mask, which should now be accepted). If it still shows only AT&T bands, the RF doesn't physically carry that band on this unit (report which bands did/didn't appear — n78/n48/n25 are the most likely to succeed since they share n77/b48/b2 RF paths).

## Safety
- `~/mr6500-checkpoint/efs2_backup.bin` is a full image of `/dev/mtd2`. The device's **Linux boots from `ubi0`, not `efs2`**, so even a corrupted EFS leaves telnet working → you can rewrite the backup to `/dev/mtd2`. Keep this image.
- Deleting policyman *persisted_items* is safe by design (the firmware instructs it); it does not touch calibration. Avoid touching other EFS paths.
- Prefer the svc‑21 (modem's own FS) route over raw `/dev/mtd2` writes.
