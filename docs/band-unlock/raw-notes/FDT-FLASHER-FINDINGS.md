# fdt.exe (Netgear/Sierra "FDT" Firmware Download Tool) — reverse-engineering findings

**Target:** `/home/leonz-agent/Downloads/fdt.exe` — PE32 i386 MS-Windows console, 1,090,688 bytes,
md5 `e7c7c05271cc879fed9026dc3d5556b3`. MSVC C++ (RTTI intact). Build path:
`m:\aircard_tools\netgear_hostsw\trunk\swisoftware\tools\fdt-b3750-netgear\fwupdatecore2\modem.cpp`
(+ `saharaprotocol.cpp`, `common\toolbox\toolboxdebug.cpp`).
Analysis: radare2 `aaa` (2543 funcs), objdump, custom Python scans. **Read-only. fdt.exe not run.**

---

## TL;DR / BOTTOM LINE (go / no-go)

**GO — but fdt.exe is only the orchestrator; the signed-firehose write capability lives in three
EXTERNAL files it drives, not inside fdt.exe.**

For the SDX65 (our modem), fdt.exe does **not** implement the EDL/firehose write itself. It shells out
(via `CreateProcessW("cmd /c cd <folder> & …")`) to Qualcomm's stock QPST tools:

1. `QSaharaServer.exe -p <port> -s 13:prog_firehose_sdx55.mbn` — Sahara-uploads the flash programmer
   (image id 13) into the modem's EDL/9008 boot.
2. `fh_loader.exe --port=<port> --sendxml=<Barebones.xml|Emergency.xml> --reset --noprompt` —
   Firehose, XML-driven raw partition writes.

`prog_firehose_sdx55.mbn` is a **Netgear/Qualcomm-SIGNED Firehose programmer** for the SDX (it must be
signed — that is exactly why DIAG on this device answers `BAD_SEC_MODE`; the modem PBL validates the
programmer's signature at Sahara). **This is the community's missing piece.** It is a plain file in
Netgear's flash package folder — NOT embedded or obfuscated inside fdt.exe (verified: zero embedded ELF/MBN).

Consequence: **whoever ran fdt.exe to flash 100PAS already possesses the signed firehose write path.**
You do not even need fdt.exe — you can call `fh_loader.exe`/`QSaharaServer.exe` directly with a custom
`rawprogram.xml`. fdt.exe imposes **no partition whitelist and no per-image signature check** on the
firehose path; the set of partitions written is exactly the `<program>` list in the plaintext XML.

**Blockers left to close** (all outside fdt.exe): obtain the 3 files above from Netgear's package;
confirm FSG is a normal GPT partition on firehose-accessible UFS/eMMC (not modem-internal secured/RPMB);
confirm the signed programmer doesn't restrict the FSG LUN (test with a non-destructive firehose READ);
then craft a valid EFS/FSG image (the EFS2-editing problem, orthogonal to the write path).

---

## 1. Full flashing flow

### 1a. Modem detection / switch to boot (EDL) mode
Classes `CModem`, `CQmodem`, `CDmProtocol`, `CSaharaProtocol`, `CSdpProtocol`, `CGobiApiWrapper`.
- Probes the port for each protocol: "Searching for Sahara protocol (Erase or Emergency / Reset or
  Download)", "Searching for DMSS download protocol", "Searching for AT or DM protocol", "Searching for
  DM protocol". Reports "Modem is under Sahara protocol …", "Modem is under DM protocol, switch to EDL",
  "Modem is under DMSS download protocol …", "Modem is under SDP protocol …".
- Switch to EDL: `CDmProtocol::SwitchToEDL`, DM-EDL command (`adb_edl_cmd`, `adb reboot edl`,
  "Error (%X) sending DM-EDL command"), `CGobiApiWrapper::ResetGobiToQdlMode`. Status strings:
  "Checking modem mode …", "Switching device to boot & hold mode …", "Failed to switch device to QDL mode",
  detects `QDLOADER`/`QDLoader` ports.

### 1b. SDX65 path — Firehose via external QPST tools (THE relevant path)
Orchestrator `CModem::RunSaharaServer_Download` (**fcn.0042e1d0**, body 0x433de6–0x43408e); launcher
`CQmodem::LaunchProcess` (**fcn.0043a6c0** → `KERNEL32!CreateProcessW`, "Launching  %s").

Two hard-coded command templates (UTF-16, exact):
```
cmd /c cd %s & QSaharaServer.exe -p %s -s 13:prog_firehose_sdx55.mbn %s%s     (@0x4d8180)
cmd /c cd %s & fh_loader.exe --port=%s --sendxml=%s --reset --noprompt %s%s   (@0x4d8018)
```
- `%s` #1 = the firmware folder (from `-fd`, else CWD) — everything runs `cd`'d into it.
- Sahara upload uses **image id 13** (Qualcomm's "flash programmer" id) = `prog_firehose_sdx55.mbn`.
- Firehose XML selected by operation:
  - normal → `Barebones.xml`  (log `\fdt_Barebones_download.txt`; "Downloading the Netgear bootloader …")
  - emergency → `Emergency.xml` (log `\fdt_Emergency_download.txt`; "Downloading the partition table and
    Netgear bootloader …")
- The XML + `prog_firehose_sdx55.mbn` + the raw partition images must already exist in that folder;
  fh_loader streams them to the signed programmer as raw sector program/erase/patch.

### 1c. Legacy path (NOT used for SDX65, present for completeness)
For 9x00–9x55 / Gobi, fdt.exe implements its OWN Sahara/SDP/DMSS: uploads `NPRG9xNN.mbn`/`ENPRG9xNN.mbn`,
then `sbl1/sbl2/dbl/fsbl/osbl/rpm/appsboot/partition.mbn` + `amss.mbn`/`uqcn.mbn` via
`CModem::Download*Bootloader`, `CModem::SendPartitionData`, `CSdpProtocol::SendPartitionTable`, with a
partition-table **override** ("Partition table differs, override is accepted", "Resending the partition
table, override existing table …"). This is the old SDP protocol — irrelevant to the SDX65.

---

## 2. Partition-write control — is arbitrary (FSG/secure) write possible?

**On the firehose (SDX65) path fdt.exe enforces NOTHING about partitions.** It passes a fixed-name XML
(`Barebones.xml`/`Emergency.xml`) to the external `fh_loader.exe`. What actually constrains which
partitions get written:

- **The Firehose XML** (`Barebones.xml`) — a *plaintext, user-editable* rawprogram-style file. The set of
  `<program label=… start_sector=… filename=…>` lines = the partitions written. Add a line targeting the
  FSG partition's LUN/start-sector → FSG gets written. No signature on the XML.
- **The signed `prog_firehose_sdx55.mbn` programmer** — the real authority. Standard Qualcomm firehose
  programmers implement raw `program`/`read`/`erase`/`peek`/`poke` on ANY LUN/sector; an OEM build *may*
  block specific LUNs, but the reference behaviour is unrestricted. Unknown until tested (do a
  non-destructive `read` of FSG first).
- **Modem secure boot** — only validates the *programmer's* signature at Sahara. Once the signed
  programmer runs, individual images are NOT re-checked by secure boot (they may be checked later by the
  bootloader at *boot*, but a raw FSG/EFS write is data, not a signed boot image).

**Verdict:** to write an arbitrary partition (FSG), you do **not** patch fdt.exe. Either
(a) edit `Barebones.xml` to add an FSG `<program>` entry pointing at your patched FSG image, or
(b) bypass fdt.exe and run `fh_loader.exe --sendxml=<your_rawprogram.xml>` with the same signed
programmer. The only gates are the programmer's own LUN policy (test) and whether FSG lives on
firehose-accessible flash (see §5). This is a clean bypass of the "Golden Copy auto-restore," because in
EDL the modem OS is not running — you rewrite the golden copy on flash directly.

---

## 3. CWE decryption (for the firmware agent) — KEY IS NOT IN fdt.exe

**fdt.exe does NOT decrypt the CWE. It has NO cryptography at all.** Hard evidence:
- **Imports:** only `KERNEL32/USER32/SHELL32/SHLWAPI/SETUPAPI/VERSION/ADVAPI32`. `ADVAPI32` is used ONLY
  for `RegOpenKeyExW/RegCreateKeyExW/RegQueryValueExW/RegSetValueExW/RegEnumKeyExW/RegCloseKey`.
  → NO `CryptImportKey/CryptDecrypt/CryptSetKeyParam/CryptDeriveKey`, NO `bcrypt`, NO `crypt32`,
  NO OpenSSL/mbedTLS.
- **No AES tables:** full-file scan found no forward/inverse S-box, no Te/Td T-table word, no Rcon,
  no SHA-256 IV, and no 256-byte permutation anywhere.
- **No AES-NI:** `AESENC/AESENCLAST/AESDEC/AESDECLAST/AESIMC/AESKEYGENASSIST/PCLMULQDQ` opcodes = 0.
- The only "encrypt" string ("enable encrypt", @0x4d14dc) is inside the **ToolBoxDebug** logging init
  (`fcn.0041b520`, reads registry `Software\ToolBoxDebug`) — a debug-log flag, not CWE crypto.
- The CWE routine `CModem::VerifyImageFile` (**fcn.00436100**) opens the file with plain
  `CreateFileW`(GENERIC_READ)+`ReadFile` and parses a **plaintext** CWE header/version block
  ("CWE file path: %s", Package Version / PRI / Carrier / Boot Block / FW Version / Device Model /
  Part Number / SKU ID; "Incorrect CWE file (product type) for this device"). It **cannot** consume an
  encrypted `.secc.cwe` — it is fed an already-DECRYPTED `.cwe`.

**The `.secc.cwe` encryption (characterised for the firmware agent):**
- File `MR6550-100PAS_23115682_NTGX65_12.01.20.00_00_Generic_01.28_00.secc.cwe`, 244,733,486 bytes
  (15,295,843 × 16-byte blocks).
- **AES-ECB, whole-file, from offset 0, no IV.** Proof: in the header-padding region the 16-byte-aligned
  ciphertext block `80 40 4C 21 51 9B FD C5 CD FF 2E D3 66 0B 8F 6E` repeats exactly (= `ECB(0x00×16)`;
  CBC/CTR could never produce identical blocks). Body is high-entropy (no dominant block).
  **No plaintext header/trailer** — no 6-byte `MR6550`/`NTGX65` anywhere (the stray 3-byte `SWI`/`CWE`
  hits are coincidental in ciphertext). Key size unknown → firmware agent should try both AES-128-ECB
  and AES-256-ECB.
- **Key not recoverable from fdt.exe.** It lives in a different component (Netgear's firmware packager /
  OTA server / on-device updater that produces the plaintext `.cwe` or the flash folder).

**PIVOT for the firmware agent:** you may not need to decrypt the `.secc.cwe` at all. Because
`fh_loader.exe`/`QSaharaServer.exe` consume **plaintext** files, the raw partition images +
`prog_firehose_sdx55.mbn` + `Barebones.xml` must exist as plaintext in Netgear's flash package folder.
Get the images from that folder. Only if you have *just* the `.secc.cwe` do you need the AES-ECB key.

---

## 4. CLI usage (recovered from usage printer `fcn.00414b80` @ 0x414bae + help text)

```
fdt -o [normal/emergency] -d [9x00/9x15/9x25/9x35/9x45/9x55/g3k/g5k] -fd [folder name]
    -f [file name 1] [file name 2] -p [port] -h -a -r -q -sc -force -slot [slot #]
    -baud [baud rate] -ssdp -timeout [value]
```
| opt | meaning |
|---|---|
| `-o normal/emergency` | normal = regular download; emergency = to an empty device (uses Emergency.xml) |
| `-d 9x00…9x55/g3k/g5k` | device type (default 9x15). **List predates SDX** — SDX/firehose path is chosen by runtime QDLoader/Sahara detection, then uses hard-coded `prog_firehose_sdx55.mbn` |
| `-fd [folder]` | folder of firmware images = the folder `cd`'d into for QSaharaServer/fh_loader (holds the programmer, XML, raw images). **This is the folder-of-parts mode.** |
| `-f file1 [file2]` | explicit image file(s): the CWE for non-Gobi; fw+config for G5K. **No single-arbitrary-partition flag.** |
| `-p AT:DM:BHold` | 2–3 serial ports |
| `-force` | force / **gang download** both images (mass multi-port flash; needs `-p`) — NOT an arbitrary-partition mode |
| `-slot 1..5` | storage slot (Gobi only) |
| `-baud`, `-ssdp`, `-a`(auto), `-r`(skip arrival check), `-q`(skip pre-reset), `-sc`(QMI status check), `-timeout` | misc |

There is **no documented raw-EDL / single-arbitrary-partition CLI mode**. But because the firehose path
already delegates to `fh_loader.exe`, arbitrary/raw writes are achieved by calling `fh_loader.exe`
directly (or editing `Barebones.xml`) — fdt.exe is not the constraint.

---

## 5. Precise next steps

1. **Locate Netgear's flash package folder** (the one used for the 100PAS flash) containing:
   `QSaharaServer.exe`, `fh_loader.exe`, `prog_firehose_sdx55.mbn` (the SIGNED programmer),
   `Barebones.xml`/`Emergency.xml` (+ any `rawprogram*.xml`, `patch*.xml`, `gpt_*`), and the raw
   partition images. NONE of these are inside fdt.exe.
2. **Enter EDL** (`adb reboot edl`, or fdt's DM-EDL path) → run `QSaharaServer.exe -s 13:prog_firehose_sdx55.mbn`.
3. **Non-destructive probe:** `fh_loader.exe … <read FSG LUN/sectors>` to (a) confirm the signed
   programmer allows FSG access and (b) dump the current FSG golden copy.
4. **Confirm FSG partition location** from the rawprogram XML / GPT — must be a normal GPT partition on
   firehose-accessible UFS/eMMC (writable), not modem-internal secured NAND / RPMB.
5. **Author a patched FSG image** (EFS/FSG format — the EFS2-editing problem from FINDINGS.md) and
   `fh_loader.exe --sendxml=<rawprogram-with-FSG-program-line>` to write it back. Auto-restore then
   restores YOUR config.
6. **CWE key** is only needed if the firmware agent must unpack `.secc.cwe` without the flash folder;
   it is AES-ECB and is **not** in fdt.exe — source it from Netgear's packager/updater, or extract
   plaintext images from the flash folder instead.

### Key function/address map
| item | addr |
|---|---|
| usage printer (`CModem` arg help) | fcn.00414b80 (0x414bae) |
| `CModem::VerifyImageFile` (CWE open/read/parse, no crypto) | fcn.00436100 |
| `CModem::RunSaharaServer_Download` (firehose orchestration, both cmd lines) | fcn.0042e1d0 (0x433de6–0x43408e) |
| `CQmodem::LaunchProcess` (CreateProcessW) | fcn.0043a6c0 |
| ToolBoxDebug init ("enable encrypt" registry flag) | fcn.0041b520 |
| QSahara cmd template str | 0x4d8180 |
| fh_loader cmd template str | 0x4d8018 |
| `.secc.cwe` ECB(zero) block | `80404C21519BFDC5CDFF2ED3660B8F6E` |
