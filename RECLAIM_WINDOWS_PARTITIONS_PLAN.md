# reclaim-windows-partitions

## Context

Reclaim the abandoned Windows 11 partition space as a new local btrfs data volume without touching any
Samba-mounted media. The only block-device filesystems this procedure may mount or modify are the local NVMe
partitions and temporary inspection mountpoints under `/mnt/win-esp`, `/mnt/win-c`, `/mnt/shared-old`, and
`/mnt/test-root`. It may also write local records under `~/backups`, update the flake configuration under `~/nixcfg`,
and delete confirmed-local entries from the user's Trash. It must never write, delete, unmount, or test-write
`/mnt/media`, `/mnt/immich-data`, `/mnt/t7-shield`, or any other CIFS mount.

**Chosen design (2026-10-11): one new btrfs volume `/data` spanning the former p1–p4 region and p7.** The existing
root filesystem, `/boot`, the bootloader and the initrd are left completely untouched — no `btrfs device add`, no
root PARTUUID repin, no scripted-to-systemd stage-1 switch. This was chosen after p7 was verified empty and `/` was
measured at **56 % used (430 GiB free)** rather than the 88 % recorded when this plan was written: the reclaimed
capacity is worth having, the boot-path risk is not. Options A (everything into `/`) and B (p1 into `/`, p7
standalone) are retained below as the **rejected alternative**, behind an explicit do-not-execute fence, to be
revisited only if a larger `/` is actually wanted.

The procedure does not
copy or relocate `~/Videos`; those local GoPro files are being moved to the Samba share separately by the user. The
397 GiB `Shared` partition is inspected read-only, but it is reclaimed only after the user explicitly confirms that
its complete listing contains nothing wanted; directory names such as `Windows`, `$RECYCLE.BIN`, or installers are not
enough to authorize deletion. The local Trash is audited for Samba-originated and unknown-provenance entries before
deleting only confirmed-local entries; an "empty trash" command must not delete media originating on a CIFS mount.
**Safety-review corrections applied.** The earlier draft had four unsafe assumptions: a final verification wrote a test
file to the Samba share; bulk-removing the local Trash could delete Samba-originated media; directory names could be
mistaken for disposable p7 content; and stage-2 `ID_BTRFS_READY=1` was treated as proof of initrd root-mount ordering.
This version removes all Samba writes, audits Trash provenance, requires explicit p7 confirmation, and adds a flake-
managed initrd scan service plus dry-build/mount/reboot gates.
**Second safety-review corrections applied (2026-09-13 live-system review).** Eight more issues found and fixed: the
Trash audit crashed when every CIFS automount was idle (`findmnt` exits 1 on an empty match — now tolerated);
`lsinitrd` is not installed on NixOS (now run via `nix-shell -p dracut`); stale ESP/NTFS signatures are now erased
with `wipefs -a` *before* `btrfs device add` instead of relying on `device add -f` to overwrite them; the
`-f`-guidance contradiction is gone (no `-f` anywhere, and post-add `wipefs -n` gates on btrfs-only signatures); the
deprecated `systemd-udev-settle.service` ordering was dropped from the initrd service; the scripted→systemd stage-1
switch is now called out as its own boot-path change; Phase 3.4 capacity expectations are exact GiB figures; and the
Trash audit is now an allowlist (origin must be under `$HOME` and not under any current mountpoint) instead of a CIFS
denylist.

**p7 reclaim section added, and the design settled, 2026-10-11.** New 0.4b diagnoses, read-only, why the `Shared`
partition was never writable from NixOS and turns p7's disposal into an explicit disposition. p7 was then mounted
read-only and **verified effectively empty** (10 entries, ~1.0 MiB; manifest + sha256 in `~/backups`). p3 (`C:`) was
then reviewed read-only in full too (377,354 entries; manifest + sha256 in `~/backups`) and the four pieces of real
user data it held — a DaVinci Resolve project database, a 29.90 GiB `Photos-1-001.zip` of 87 Pixel videos, and two
booking documents — plus the 24.28 GiB Recycle Bin, were preserved locally (C0) before any deletion. With `/`
measured at 56 % used instead of the 88 % recorded at authoring time, the chosen design is **B′ — one new `/data`
btrfs volume spanning the former p1–p4 region and p7 (885.45 GiB), leaving `/`, `/boot`, the bootloader and the
initrd untouched**. The root-growing options A/B are kept as a fenced, do-not-execute alternative.

**✅ COMPLETED 2026-10-11.** All of C1–C8 ran successfully. Final state, verified after the C8 reboot:

| part | start | size | type | role |
|---|---|---|---|---|
| p1 | 2048 | 488.39 GiB | Linux filesystem, `nixos-data` | member of `/data` |
| p5 | 1024237568 | 1 GiB | EFI | `/boot` — **PARTUUID unchanged** `226c2b0b-…` |
| p6 | 1026334720 | 976.56 GiB | Linux filesystem | `/` — **PARTUUID unchanged** `67c0b066-…`, single device, untouched |
| p7 | 3074334720 | 397.06 GiB | Linux filesystem, `nixos-data` | member of `/data` |

`/data` = one btrfs filesystem, label `data`, **FS UUID `2f33dfb6-d596-4f5c-970a-cb1c7a89df46`**, 2 devices,
`Data: single` / `Metadata: RAID1` / `System: RAID1`, 885.45 GiB of device space (886G shown, 884G free). Mounted
**unattended at boot** from `/etc/fstab` by FS UUID with `noatime`; `btrfs device stats` all zero on both members;
`systemctl --failed` empty; `/` and `/boot` came up exactly as before on p6/p5. The bootloader and initrd were never
touched (`Skipping … systemd-bootx64.efi, same boot loader version`), which is the whole point of B′ over A/B.
Remaining optional item: Phase 7 (HOME Trash — now only **80 MB / 14 entries**, versus the 144 GB / 2106 entries this
plan assumed when it was written, so it is no longer worth the ceremony).

**What the three stalls cost, and the corrections they produced.** Every command in the destructive chain is now
either rehearsed offline on image files or confirmed on the live device:

- **Offline rehearsal of destructive commands** (sparse image files + `mkfs.vfat`/`mkntfs`/`mkfs.btrfs` + `dd … seek=`
  to place filesystems at chosen offsets) replaced assumption with measurement, and corrected two errors in this
  document: `wipefs -n` does **not** see NTFS superblocks buried inside the new p1 (only the old ESP's vfat entries,
  because it probes only near-zero offsets), and a plain `wipefs -a` **cannot** clear p7's `dos` at `0x1fe` — nor can
  the `wipefs -o` offset erase this document previously recommended, since both are refused by the non-whole-disk
  guard. A targeted `wipefs -a --force` is required, after which `mkfs.btrfs` succeeds without `-f`. Confirmed on the
  live devices: p1 reported three vfat entries and wiped clean; p7 reported `ntfs` + `dos`, the `dos` survived the
  plain wipe with `ignoring nested "dos" partition table on non-whole disk device`, and the leftover loop cleared it.
- **`sfdisk` cannot write a partition table on this disk at all.** With `/` (p6) and `/boot` (p5) mounted, every
  `sfdisk` table write is refused by the in-use check (`This disk is currently in use … Use the --no-reread flag`),
  which stalled stage 1 at C3. `parted` is unaffected and had already performed the deletions on the same busy disk,
  so C3 and C4 are `parted` (`mkpart` / `type` / `name`). Not a fallback — it is the only path that works here.
- **`set -e` must never be pasted at an interactive prompt.** The first stall was `/mnt/win-c` still mounted from the
  p3 review, refusing `parted rm 3`; because the block was a bare `set -e` paste, the non-zero exit **killed the
  shell** rather than stopping the block. Use a script or `( … )`, and always `umount` + `findmnt`-guard first.
  (Also: `lsblk` right-aligns its columns, so parsing it needs `tr -d '[:space:]'` or a padded `" 2048"` compares
  unequal to `"2048"` and aborts spuriously.)

Scripts for the stages live in `~/reclaim/`: `1-delete-windows-partitions.sh` (executed), `1b-create-p1.sh`
(executed), `1c-retag-p7.sh` (executed), `2-mkfs-data.sh` (executed).

Facts verified this session (2026-09-13):

- Disk `nvme0n1`, Samsung SSD 990 EVO Plus 2TB, serial `S7U7NU0Y626623M`, 3,907,029,168 sectors.

| part | start sector | size | type GUID | role |
|---|---|---|---|---|
| p1 | 2048 | 100 MiB | `c12a7328-f81f-11d2-ba4b-00a0c93ec93b` (EFI System) | Windows-created ESP, holds `\\EFI\\Microsoft\\Boot\\bootmgfw.efi` |
| p2 | 206848 | 16 MiB | `e3c9e316-0b5c-4db8-817d-f92df00215ae` (MSR) | Windows reserved |
| p3 | 239616 | 1022502912 s | `ebd0a0a2-b9e5-4433-87c0-68b6b72699c7` (MS basic data) | Windows `C:` — NTFS; contents still require read-only review |
| p4 | 1022742528 | 1495040 s | `de94bba4-06d1-4d40-a16a-bfd50179d6ac` (WinRE) | Windows recovery, NTFS |
| p5 | 1024237568 | 2097152 s (1 GiB) | `c12a7328-…` (EFI) | **NixOS `/boot`** — vfat label `NIXOS_BOOT`, UUID `7FAC-3464`, PARTUUID `226c2b0b-8bc9-4508-8fda-ad5b67a68e25` |
| p6 | 1026334720 | 2048000000 s (976.56 GiB) | `0fc63daf-8483-4772-8e79-3d69d8477de4` | **NixOS `/`** — btrfs FS UUID `dd0a6767-6a72-4d03-9611-f45b2534b98f`, label `NixOS_root`, subvol `@`, PARTUUID `67c0b066-5a52-4253-b075-d9d79fcf330a` |
| p7 | 3074334720 | 832694415 s (397.06 GiB) | `ebd0a0a2-…` | NTFS label `Shared` — no fstab entry, no reference anywhere in `~/nixcfg` |

- Deleting p1–p4 frees sectors **2048–1024237567 = 488.39 GiB**, immediately before p5. p6 cannot be extended
  backwards, so the space becomes a new partition and is added to the existing root btrfs filesystem.
- Current root pressure: `/` 977 GiB, 846 GiB used, 126 GiB free (88 %). `~/.local/share/Trash` = 144 GB (2106
  paired entries at the time of inspection).
- Boot chain: systemd-boot is configured for `/boot` (p5). Firmware entry `Boot0022` is the valid p5
  `Linux Boot Manager`; `Boot0021` is Windows on p1. `Boot0020` is a stale p5 GRUB entry and `Boot0023`/`Boot0024`
  have zeroed device paths. Their numeric IDs must be re-read before any EFI cleanup; the plan does not delete EFI
  entries as part of the storage cutover because stale entries are harmless and EFI cleanup is not needed to reclaim data.
- Multi-device btrfs support is **not treated as proven solely by the stage-2 `ID_BTRFS_READY=1` observation**. The
  initrd rule path and mount ordering must be validated by the generated flake configuration and by the post-change
  reboot. The plan includes an explicit initrd `btrfs device scan` service and a live mount test before reboot.
- `~/Videos` is local-only media currently on p6; its move to `/mnt/media` is separate user work. This plan never
  reads or writes its destination and never touches any Samba-mounted media.
- p7 was intended as a volume shared between the Windows and Linux installs so that large files would not be
  duplicated, and it never worked: NixOS could not write to it, and it was never wired into the configuration at all
  (no fstab entry, no `fileSystems` declaration). It was mounted read-only on 2026-10-11 and **verified effectively
  empty** (10 entries, ~1.0 MiB of test and Windows-bookkeeping files). Its write failure is diagnosed read-only in
  0.4b, and its disposition — plus p1–p4's — is settled as **B′**: one new `/data` btrfs volume spanning both, with
  the root filesystem untouched. See `## Chosen path — B′`.
- Re-read 2026-10-11: the layout above is unchanged (p1–p4 and p7 all still intact, p5/p6 at their original start
  sectors), but root pressure has eased to **543 GiB used / 430 GiB free (56 %)**. The reclaim is therefore no longer
  urgent, which makes the 0.4b disposition choice — and whether to reclaim at all — a deliberate decision rather than
  a space emergency.

**Root-device pinning.** `/etc/fstab` currently names `/` by the btrfs filesystem UUID. After a second partition joins,
each member reports that same filesystem UUID, so the by-UUID name is ambiguous. The NixOS module therefore overrides
only `fileSystems."/".device` with p6's stable GPT PARTUUID. This is a flake configuration change, not a hand edit of
`/etc/fstab`; `nixos-rebuild` regenerates the initrd and fstab from the flake. The root filesystem then depends on all
members being present at boot; all members remain on the same physical NVMe, so this adds no physical redundancy and
does add a recoverable boot/mount dependency. Reverting requires removing the added btrfs devices and restoring the
flake override; it is not an instant partition-table rollback after `btrfs device add`.

**Backup gate.** `btrfs device add` is metadata-changing even though it does not relocate existing file extents. Do
not proceed to the first `btrfs device add` until an independent backup of irreplaceable data currently on p6 is
confirmed. A btrfs snapshot on p6, the Trash, or a Samba mount that is not an independent backup of that local data
does not satisfy this gate. First check `sudo btrfs device stats /` and `sudo btrfs scrub status /`; any existing
errors or an incomplete scrub stop the procedure.

**Privileges.** Only `/run/current-system/sw/bin/nixos-rebuild` is passwordless (`sudo -n -l`). Run every other
privileged command through `bash` with `pty: true` so the password prompt reaches the terminal; start with `sudo -v`
and refresh it if it expires. Do not grant persistent passwordless partition or mount commands.

## Approach

Ordered so that nothing is destroyed until it is verifiable and the layout around it has been checked, and so that
each step can be verified before the next.

**The executable path is `## Chosen path — B′` immediately after Phase 0.** It reclaims p1–p4 and p7 into one new
`/data` btrfs volume and changes nothing in the boot path. Everything from `### Phase 1` onward is the **rejected
A/B alternative** (growing the root filesystem), retained for reference and fenced off with a do-not-execute banner;
Phases 7 and 8 apply to both paths. Phase 0 below is shared read-only pre-flight and applies in full.

### Phase 0 — Pre-flight, storage read-only (local records only)

0.1 Identity check; never operate by `/dev/sdX`:
`lsblk -dno NAME,SERIAL,MODEL,SIZE /dev/nvme0n1` must print `nvme0n1 S7U7NU0Y626623M Samsung SSD 990 EVO Plus 2TB 1.8T`.

0.2 Record rollback state and current CIFS mounts without opening or writing them:
```
mkdir -p ~/backups
umask 077
test ! -e ~/backups/nvme0n1-gpt-2026-09-13-before.sfdisk
sudo sfdisk -d /dev/nvme0n1 > ~/backups/nvme0n1-gpt-2026-09-13-before.sfdisk
nix-shell -p efibootmgr --run "sudo efibootmgr -v" > ~/backups/efi-boot-2026-09-13-before.txt
findmnt -rn -t cifs -o TARGET,SOURCE,FSTYPE,OPTIONS
sudo mkdir -p /mnt/win-esp /mnt/win-c /mnt/shared-old
```
The backup directory is local. The `test` prevents silently overwriting an existing dated record; if it fails, stop
and choose a new filename. The GPT dump is a pre-change record, not a safe post-btrfs-add rollback: never restore it
after a new device has joined the root filesystem.
The `efibootmgr` query is run with root privileges; all commands that may prompt for sudo must be run in the
interactive terminal as described in Privileges.


0.3 Read-only review of Windows content. Use `sudo find`, not unprivileged shell globs, so permissions do not change
what is inspected:
```
sudo mount -t vfat -o ro /dev/nvme0n1p1 /mnt/win-esp
sudo find /mnt/win-esp -xdev -maxdepth 3 -printf '%p\n' | sort
sudo umount /mnt/win-esp

sudo mount -t ntfs3 -o ro /dev/nvme0n1p3 /mnt/win-c
set -o pipefail
sudo find /mnt/win-c -xdev -mindepth 1 -printf '%y\t%s\t%p\0' | sort -z | while IFS= read -r -d '' entry; do printf '%q\n' "$entry"; done | tee ~/backups/windows-c-2026-09-13.manifest
set +o pipefail
sha256sum ~/backups/windows-c-2026-09-13.manifest
sudo umount /mnt/win-c


sudo ntfsls /dev/nvme0n1p4
```
(`set +o pipefail` after each use: `pipefail` persists in a long-lived interactive shell and would otherwise turn
later benign pipelines, e.g. a no-match `grep`, into failures.)
The p3 manifest is complete; do not truncate it for the deletion decision. If the NTFS mount refuses because the
volume is dirty/hibernated or encrypted, do not force it and do not wipe it; stop and ask the user. If the complete
manifest contains anything wanted, stop and ask before deleting p3. The vfat listing is used to detect an old
systemd-boot copy on p1, although Phase 1 makes p5 authoritative before deletion. p4 gets only the `ntfsls` listing,
not a full manifest — a deliberate asymmetry: the 730 MiB WinRE image is disposable by definition, unlike p3/p7.
`blkid` already probes p3 and p7 as `ntfs` today, so the encrypted-volume stop branch is known-clear in advance; the
dirty/hibernated branch still applies.

**p3 review carried out 2026-10-11 (read-only).** Mounted with
`ntfs3 -o ro,uid=1000,gid=100,umask=022`; 155 GiB used of 487.6 GiB, **377,354 entries**, full manifest and checksum
at `~/backups/windows-c-2026-10-11.manifest` (sha256 `d148bf6e0cce627b6d5d047b595c3ea234c14896e82cfc48bb0a96a1b8efd2e0`).
The volume is a stock Windows 11 install plus four pieces of real user data, all of which were preserved (C0):
a **DaVinci Resolve project database** (`Support/Resolve Project Library/Resolve Projects/Users/guest/Projects/` —
`kitchen reno jam` and `Untitled Project 1`, plus `User.db`), **`Downloads/Photos-1-001.zip`** (29.90 GiB, 87 Pixel
`PXL_2025*` videos), `Downloads/milanairbnb.pdf`, and a booking screenshot. `Downloads`, `Desktop`, `Documents`,
`Pictures`, `Videos`, `Music`, `OneDrive` and `DaVinci Resolve Media` hold nothing else. The 24.28 GiB
`$Recycle.Bin` holds 58 MP4s and 1 JPG, all from `C:\Users\kerby\Downloads\` and all deleted in one pass on
2025-10-28 — preserved too, since the cost of keeping them is small and the cost of being wrong is not. Everything
else (Windows, Program Files, ProgramData, `$WinREAgent`, Temp, PowerToys, installers) is disposable by inspection.
**`hiberfil.sys` is present at 26 GiB**, which corroborates the 0.4b cause #1 as the reason p7 was never writable
from Linux. No file on p3 is Samba data, so the CIFS prohibition is unaffected.


0.4 Read-only review of p7:
```
sudo mount -t ntfs3 -o ro /dev/nvme0n1p7 /mnt/shared-old
set -o pipefail
sudo find /mnt/shared-old -xdev -mindepth 1 -printf '%y\t%s\t%p\0' | sort -z | while IFS= read -r -d '' entry; do printf '%q\n' "$entry"; done | tee ~/backups/shared-old-2026-09-13.manifest
set +o pipefail
sha256sum ~/backups/shared-old-2026-09-13.manifest
sudo du -sh /mnt/shared-old
sudo umount /mnt/shared-old
```
The manifest is complete: it has no `maxdepth` or `sed` truncation. Preserve the exact manifest and its checksum
locally, then show every entry to the user. Reclaim p7 only after explicit user confirmation against that exact
manifest that every listed item is disposable; directory names are never enough. If the mount refuses read-only,
stop; do not use `force` to bypass an unknown filesystem state.
The `ntfs3` read-only mount in 0.4 is the kernel driver; if it refuses, try the FUSE driver (`ntfs-3g -o ro`, see
0.4b) before treating the volume as unreadable. 0.4's stop condition applies only after both drivers have failed.

0.4b p7 (`Shared`): why it was never writable, and its disposition.

Re-verified unprivileged on 2026-10-11 (no root, no mounts):

- p7 is 397.1 GiB at start sector 3074334720, GPT type `ebd0a0a2-…` (Microsoft basic data), FS `ntfs`, label
  `Shared`, FS UUID `409883C657845728`.
- **NixOS has never mounted p7.** There is no `/etc/fstab` entry, no `fileSystems` declaration in `~/nixcfg`, and no
  reference to p7 or to the label `Shared` anywhere in the configuration. Every write attempt so far was an ad-hoc
  manual mount, so the failure is not a broken fstab entry — nothing was ever configured to mount it.
- `ntfs-3g` + `ntfsfix` + `ntfsinfo` are installed (`hosts/features/video-editing.nix:67`) and the in-kernel `ntfs3`
  module ships with kernel 6.12 (`/run/booted-system/kernel-modules/.../fs/ntfs3/ntfs3.ko.xz`).
- `boot.supportedFilesystems` does not list `ntfs`. This is irrelevant to an on-demand mount and relevant only if p7
  were ever mounted at boot.
- `kerby` is not in the `disk` group, so the block device (`brw-rw---- root:disk`) cannot be read unprivileged: the
  volume's dirty/hibernation flag **is not verified and cannot be verified without root**.
- No `ntfs`/`nvme0n1p7` lines exist in the current boot's kernel log, i.e. nothing attempted a mount this boot.

The diagnosis and the 0.4 read-only review are the same step — run them together:

```
sudo ntfsinfo -m /dev/nvme0n1p7 | sed -n '1,40p'      # $Volume flags: dirty / hibernated
sudo mount -t ntfs3 -o ro /dev/nvme0n1p7 /mnt/shared-old   # kernel-driver read-only mount
sudo umount /mnt/shared-old
sudo ntfs-3g -o ro /dev/nvme0n1p7 /mnt/shared-old     # FUSE read-only fallback
sudo umount /mnt/shared-old
dmesg | grep -i ntfs | tail -20                       # the exact refusal text, if any
```

Three candidate causes, in the order they should be checked; the evidence above distinguishes them:

1. **Windows Fast Startup / hibernation (the expected one).** A hybrid shutdown leaves the `$Volume` dirty flag set
   and a `hiberfil.sys` on the Windows `C:` (p3). Both drivers then refuse read-write and either mount read-only or
   fail outright. Check the `hiberfil.sys` entry in the p3 manifest (0.3) and the dirty flag in `ntfsinfo`. This is
   the canonical reason a partition built to be shared between Windows and Linux is writable from only one side.
2. **No ownership mapping.** A manual `mount -t ntfs3` with no `uid=`/`gid=`/`umask=` presents every file as
   `root:root`, so writes fail with `EACCES` as `kerby` even though the mount is nominally read-write. This reads as
   "Linux cannot write to it" but is a mount-option problem, not a filesystem one.
3. **`ntfs3` read-write refusal on a mildly inconsistent volume.** The in-kernel driver is stricter than the FUSE
   driver; `ntfs-3g` is the more permissive fallback for a one-off read-write mount.

None of the three changes the outcome now that Windows is being removed, and **none should be fixed**: the diagnosis
exists only to establish whether the 0.4 listing is complete and whether the volume is in a state that makes the
manifest untrustworthy. **Do not run `ntfsfix`, do not mount read-write, and do not repair p7** — every such write
risks destroying evidence before the manifest has been reviewed and approved.

**Disposition decision (gate for 2.5 and 3.3).** Windows no longer needs this extent, so p7 is reclaimed; the only
open question is into what. Decide once, before Phase 2:

| | A. Absorb into root btrfs (current plan) | B. Standalone btrfs volume (recommended) | C. Repair NTFS and keep it |
|---|---|---|---|
| result | p1 + p6 + p7 in one filesystem | p6 (+p1) root, p7 a separate `mkfs.btrfs` volume | p7 stays NTFS, made writable |
| `df /` | shows the whole ≈1.82 TiB | unchanged | unchanged |
| capacity view | one pool | two pools (`/` and the data mount) | n/a |
| failure domain | **root depends on three partitions in two disjoint disk regions** — any one failing loses `/` | root unaffected by p7; each volume has its own `scrub`, snapshots and stats | n/a |
| configuration cost | PARTUUID pin + initrd btrfs scan service (already in Phases 1 and 4) | one `fileSystems` entry; no root-config change for p7 | one fstab entry plus driver options |
| right for | "one big `/`" | **"large files that should not be duplicated" — p7's original purpose** | nothing: Windows is going away, and NTFS is the worst choice for a Linux-only pool |

Recommendation: **B.** p7 was created to hold large files that both operating systems reached, which is a separate
data volume, not more root. It also keeps the failure domain honest: stretching root across a second, physically
disjoint region of the same disk buys no redundancy and adds a boot dependency. Option A remains correct if a single
unified pool is preferred, and the existing 2.5/3.3 commands then apply unchanged.

**A (absorb):** run the existing 2.5 then 3.3 — recreate the extent as GPT entry 2 `nixos-pool2`, `wipefs -a` before
the add, and `btrfs device add` without `-f`.

**B (standalone):** do not run 2.5 or 3.3. Instead:

```
sudo wipefs -n /dev/nvme0n1p7        # expect: ntfs signature only
findmnt -rn -S /dev/nvme0n1p7        # expect: no output
sudo wipefs -a /dev/nvme0n1p7        # erase the NTFS signature; nothing has it mounted
sudo mkfs.btrfs -L data /dev/nvme0n1p7
lsblk -o NAME,SIZE,PARTUUID,FSTYPE,LABEL /dev/nvme0n1p7
```
No `parted`/`sfdisk` step and no partition renumbering: p7 keeps its number and its extent, and only its contents
change. Then declare it in the flake, beside the other local mounts in `hosts/nixos/configuration.nix`:
```nix
  # Bulk data pool: the former Windows 'Shared' partition, reformatted for Linux.
  fileSystems."/data" = {
    device = "/dev/disk/by-partuuid/<p7 PARTUUID from the lsblk above>";
    fsType = "btrfs";
    options = ["noatime"];
  };
```
Use the **PARTUUID**, not the new filesystem UUID, so a future re-`mkfs` cannot silently repoint the mount. Do not
set `nofail` and do not add `x-systemd.automount`: this is local NVMe that is always present, so a plain boot mount
is correct and a failure should drop to emergency mode visibly rather than be deferred or skipped.

`compress=zstd` is deliberately omitted — the pool is expected to hold media that is already compressed, so zstd
would burn CPU for no space gain; add `compress=` only if the contents turn out to be compressible. If snapshots of
this pool are wanted later, create a `@data` subvolume after the `mkfs` and mount `subvol=@data`, mirroring root's
`subvol=@` layout.
Apply and verify:
```
alejandra hosts/nixos/configuration.nix
sudo nixos-rebuild dry-build --flake .#nixos --impure --no-write-lock-file
sudo nixos-rebuild switch --flake .#nixos --impure --no-write-lock-file
findmnt /data && sudo btrfs filesystem show /data
sudo chown kerby:users /data          # a fresh btrfs root is root:root
```
With B, the root filesystem gains exactly one device (p1) and the p2 path in 3.3 is dead; nothing else in Phases 1–5
changes, including the PARTUUID pin and the initrd scan service, which are still required because root becomes
multi-device.

0.5 Health and backup gate before any root btrfs mutation:
```
sudo btrfs device stats /
sudo btrfs scrub status /
```
All existing error counters must be zero and no scrub may be running or incomplete. Independently confirm the p6
data backup described in Context; if it is not confirmed, stop before Phase 3.

0.6 Before leaving this phase, prove that all temporary inspection mounts are gone:
```
for p in /dev/nvme0n1p1 /dev/nvme0n1p3 /dev/nvme0n1p4 /dev/nvme0n1p7; do
  findmnt -rn -S "$p"
done
```
Expected: no output. Do not unmount or otherwise manipulate any CIFS mount shown in 0.2.

## Chosen path — B′: one new `/data` btrfs volume (2026-10-11)

**Outcome.** The former Windows p1–p4 region (488.39 GiB, sectors 2048–1024237567) and p7 (397.06 GiB) become a
single new btrfs filesystem spanning **885.45 GiB of device space** (usable data capacity is slightly less, because
metadata is RAID1 across both devices) mounted at `/data`. `/` (p6), `/boot` (p5), the bootloader and the
initrd are not modified in any way. Partition numbers p5/p6/p7 do not move, so `/boot` and `/` references stay valid.
GPT entries 2, 3 and 4 end up unused, and `nvme0n1p2/3/4` cease to exist.

**Why this and not growing `/`.** See Context: `/` is 56 % used with 430 GiB free. Growing it is the only part of
this procedure that carries boot risk, and it is not done for capacity that is not needed.

**Preconditions.**
- p7's contents were verified empty on 2026-10-11 — 10 entries, ~1.0 MiB, manifest and sha256 at
  `~/backups/shared-old-2026-10-11.manifest`. Nothing on p7 constrains its reclamation.
- p3 (`C:`) was listed read-only and reviewed in full on 2026-10-11 — 377,354 entries, manifest and sha256 at
  `~/backups/windows-c-2026-10-11.manifest`; findings recorded in 0.3. Everything wanted from it is preserved in C0.
  It is no longer a reason to stop, only a source of data to copy first.
- `/mnt/shared-old` was unmounted after the p7 review (verified 2026-10-11), so nothing must be unmounted before C2.
- No CIFS mount is touched at any point; p1–p4 hold no Samba data.

C0 Preserve the confirmed-wanted data off p3 **before anything is deleted**, to a local path — never a CIFS mount:
```
mkdir -p ~/preserved/win-c-<date>
cp -a /mnt/win-c/Users/kerby/Downloads/Photos-1-001.zip ~/preserved/win-c-<date>/
cp -a /mnt/win-c/Users/kerby/Downloads/milanairbnb.pdf ~/preserved/win-c-<date>/
cp -a "/mnt/win-c/Users/kerby/Downloads/Screenshot 2025-10-28 at 12-51-48 View Booking KBGSVP5 easyJet.com.png" \
      ~/preserved/win-c-<date>/
cp -a "/mnt/win-c/Users/kerby/AppData/Roaming/Blackmagic Design/DaVinci Resolve/Support/Resolve Project Library" \
      ~/preserved/win-c-<date>/
mkdir -p ~/preserved/win-c-<date>/recycle-bin
cp -a "/mnt/win-c/\$Recycle.Bin/S-1-5-21-2391088008-423882448-4197848775-1001" ~/preserved/win-c-<date>/recycle-bin/
```
The destination is `/` (the local NVMe root, not `/data`, which does not exist yet) and the copy must complete and be
size-verified **before C2**. The Recycle Bin is copied verbatim — the `$I` sidecars are what map the meaningless `$R`
filenames back to their originals, so they must travel with the payloads. After C8, move `~/preserved/` to `/data`;
until then it is a 54 GiB duplicate on the same physical disk, which is a staging cost, not a backup.

C1 Records and mount check — Phase 0.2 and 0.6 verbatim: the `sfdisk -d` dump, the `efibootmgr -v` dump, and proof
that none of `/dev/nvme0n1p{1,3,4,7}` is mounted.

C2 Delete p1–p4 highest number first, one command at a time, stopping on any non-zero status:
```
sudo parted -s /dev/nvme0n1 rm 4
sudo parted -s /dev/nvme0n1 rm 3
sudo parted -s /dev/nvme0n1 rm 2
sudo parted -s /dev/nvme0n1 rm 1
```
**Status 2026-10-11: DONE — all four partitions are gone.** It did not go in one pass, and the two stalls are worth
keeping: `rm 4` and `rm 2` succeeded, `rm 3` was refused because `/mnt/win-c` was still mounted on p3, and the
non-zero exit of a `set -e` block run at an interactive prompt killed the shell, ending the run. `rm 3` and `rm 1`
were then completed by `~/reclaim/1-delete-windows-partitions.sh`.
The lesson that outlives the run: **do not re-run a deletion for a partition that is already gone** — it exits 1 with
`Partition doesn't exist` (measured) and aborts the whole block. Re-read the table with `sudo sfdisk -d /dev/nvme0n1`
before any continuation, and let the C5 geometry gate — not an assumption — be what confirms p5/p6 did not move.
The first step of any continuation must be `sudo umount /mnt/win-c`, guarded by an explicit
`if findmnt -rn -S /dev/nvme0n1p3; then … exit 1; fi` — a mounted partition is exactly what caused the refusal.
Run continuations as a **script or a `( … )` subshell**, never as a bare `set -e` paste at an interactive prompt.

**Second stall, same run: C3's `sfdisk` command was refused.** Stage 1 got past C2 cleanly (the table is now
`p5, p6, p7` only) and then `sfdisk` declined to write a partition table on a disk with mounted partitions —
`This disk is currently in use … Use the --no-reread flag` — so the script exited at that point with everything
consistent and `/` and `/boot` untouched. The corrected C3/C4 below use `parted`, which is the tool that already
deleted p1/p3 on this same busy disk. Attachments: stage 1 record at
`~/backups/nvme0n1-gpt-2026-10-11-mid.sfdisk` (that dump, and `lsblk`, both show `p5, p6, p7`, no drift).

C3 Recreate the freed extent as GPT entry 1, typed as Linux filesystem.
**Use `parted`, not `sfdisk` — `sfdisk` cannot do this on this disk.** Measured 2026-10-11: any `sfdisk` table
write refused with
`This disk is currently in use - repartitioning is probably a bad idea. … Use the --no-reread flag to suppress this
check. sfdisk: Use the --force flag to overrule all checks.`
because `/` (p6) and `/boot` (p5) are mounted from this disk. `parted` is the tool that already worked for the
deletions on that same busy disk — it commits via per-partition kernel updates instead of requiring a full table
re-read — so it is the primary path here, and the earlier sfdisk form is demoted to reference only.
```
sudo parted -s /dev/nvme0n1 unit s mkpart nixos-data ext4 2048 1024237567
sudo partprobe /dev/nvme0n1   # may be a no-op on a busy disk; ignored if so
sudo udevadm settle
```
Validated offline against an image with this exact slot layout (1–4 free, 5/6/7 present): it creates **exactly slot
1** at start 2048 with type GUID `0FC63DAF` (Linux filesystem), and leaves slots 5/6/7 byte-identical. Two
consequences to check rather than assume: that the new partition really is number 1, and that the kernel has created
the node — assert `lsblk -no START` is `2048` and `lsblk -bno SIZE` is `524408586240`. If `/dev/nvme0n1p1` does not
appear after `partprobe`, try `sudo partx -a /dev/nvme0n1`; if it still does not exist the table is nonetheless
written and **a plain reboot resolves it safely**, since p5/p6 are untouched.
`parted`'s `mkpart` does not format anything, so the stale ESP signature survives for C6 to erase.
(Reference-only sfdisk equivalent, which does **not** work here without `--no-reread --force`:
`printf '%s\n' 'start=2048, size=1024235520, type=0fc63daf-8483-4772-8e79-3d69d8477de4, name="nixos-data"' | sudo sfdisk --partno 1 --wipe=never --quiet /dev/nvme0n1`
— syntax validated offline, but the in-use check rejects it on the live disk.)

C4 Retag and rename p7. Its extent and number do not change; only the GPT metadata stops describing it as Microsoft
data, so nothing in the table is misleading afterwards. **`sfdisk --part-type`/`--part-label` hit the same in-use
refusal as C3**, so these are `parted` too:
```
sudo parted -s /dev/nvme0n1 type 7 0fc63daf-8483-4772-8e79-3d69d8477de4
sudo parted -s /dev/nvme0n1 name 7 nixos-data
sudo partprobe /dev/nvme0n1 || true; sudo udevadm settle
```
Validated offline: `parted type` accepts a raw GUID (an invalid one exits 1 rather than being silently ignored), and
it changes only the type — geometry and PARTUUID are left exactly as they were.

C5 Geometry gate before any filesystem exists. `lsblk -o NAME,SIZE,START,PARTTYPENAME,PARTLABEL,PARTUUID
/dev/nvme0n1` must show p1 at start 2048, 488.39 GiB, type `Linux filesystem`; and p5/p6/p7 at their original start
sectors with their original PARTUUIDs (`226c2b0b-…`, `67c0b066-…`). Any movement means stop — before any filesystem
exists, the Phase 0 dump is still a valid thing to restore from.

C6 Erase the stale signatures and create the filesystem. Neither device belongs to any filesystem yet and neither is
mounted:
```
DEV1=/dev/nvme0n1p1; DEV2=/dev/nvme0n1p7
sudo wipefs -n "$DEV1"; sudo wipefs -n "$DEV2"
findmnt -rn -S "$DEV1"; findmnt -rn -S "$DEV2"          # expect no output
sudo wipefs -a "$DEV1"
sudo wipefs -a "$DEV2"
for d in "$DEV1" "$DEV2"; do                            # plain wipefs CANNOT clear everything
  if [ -n "$(sudo wipefs -n "$d" | tail -n +2)" ]; then
    sudo wipefs -n "$d"                                 # show what survived
    sudo wipefs -a --force "$d"                         # targeted: this one bare partition
  fi
  [ -n "$(sudo wipefs -n "$d" | tail -n +2)" ] && { echo "ABORT: $d still dirty"; exit 1; }
done
sudo mkfs.btrfs -L data -d single -m raid1 "$DEV1" "$DEV2"
sudo btrfs filesystem show "$DEV1"
```
**What actually shows up — measured offline on 2026-10-11** on image files shaped like these two devices
(btrfs-progs v7.1, util-linux wipefs), because the earlier text here got both of these wrong:

- **p1 reports only the old ESP's vfat signatures** — three lines, all at low offsets (`0x0`, `0x36`, `0x1fe`). It
  does **not** report the old `C:` or WinRE NTFS superblocks, even though those physically sit inside the new extent
  at byte offsets 121,634,816 and 523,643,125,760: `wipefs` only probes the offsets libblkid's probers look at, which
  are all near zero. A plain `wipefs -a` erases all three vfat entries and p1 comes back clean.
- **p7 reports `ntfs` at `0x3` *plus* a `dos` signature at `0x1fe`.** The plain `wipefs -a` erases the ntfs magic but
  **refuses the `dos` one** — `ignoring nested "dos" partition table on non-whole disk device … Use the --force option
  to force erase` — and that single leftover makes `mkfs.btrfs` refuse with `appears to contain a partition table
  (dos)`. **The offset-erase remedy this document previously recommended does not work:** `wipefs -o 0x1fe` is refused
  by the same guard and changes nothing. A targeted `wipefs -a --force "$d"` does clear it (2 bytes at `0x1fe`), and
  `mkfs.btrfs` then succeeds **without** `-f`. The `--force` is scoped to that one bare partition — it cannot reach the
  GPT, which lives on the disk rather than on p7 — and it runs only when the leftover check finds something.
- `mkfs.btrfs` is therefore still invoked **without** `-f`: a refusal there now means the leftover loop failed to
  notice a signature, which is a stop condition, not something to force past.

Profiles are stated explicitly rather than defaulted. `-m raid1` keeps metadata on both devices; both live on the
same physical NVMe, so it protects against per-partition damage and scrub-detectable bit rot but **not** against
losing the disk — it is not redundancy, and must not be described as such. `-d single` keeps the capacity arithmetic
honest: data can use either device's free space, so the pool's usable data capacity is the sum of the devices minus
the duplicated metadata, which is a few GiB. Verified offline on two image files with these exact flags
(btrfs-progs v7.1): `Data: single`, `Metadata: RAID1`, `System: RAID1`, 2 devices.

C7 Declare `/data` in the flake, keyed on the **filesystem UUID** that `mkfs` printed:
```nix
  # Bulk data pool: former Windows p1-p4 region + the 'Shared' partition, one btrfs volume.
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/2f33dfb6-d596-4f5c-970a-cb1c7a89df46";
    fsType = "btrfs";
    options = ["noatime"];
  };
```
**Executed 2026-10-11: C6 produced FS UUID `2f33dfb6-d596-4f5c-970a-cb1c7a89df46`, label `data`.** The `mkfs`
ran without `-f`, performed a full-device TRIM on both members (SSD detected), and reported exactly the rehearsed
profile: `Data: single`, `Metadata: RAID1`, `System: RAID1`, `Filesystem size 885.45GiB`, `Number of devices: 2`
(devid 1 = p1 488.39GiB, devid 2 = p7 397.06GiB). The C7 entry above is already applied to
`hosts/nixos/configuration.nix` and the system has been switched to the generation that carries it.
The filesystem UUID, not a member's PARTUUID: this is a multi-device filesystem, so the filesystem is what is being
named rather than any one device, and a future `mkfs` produces a *new* UUID — so a re-created filesystem makes the
mount **fail loudly** instead of silently attaching a fresh, empty filesystem at `/data`. Do not add `nofail` and do
not add `x-systemd.automount`: `/data` is local and always present, and a mount failure should be visible rather than
silent.
```
cd ~/nixcfg
alejandra hosts/nixos/configuration.nix
sudo nixos-rebuild dry-build --flake .#nixos --impure --no-write-lock-file
sudo nixos-rebuild switch --flake .#nixos --impure --no-write-lock-file
findmnt /data && sudo btrfs filesystem show /data && sudo btrfs device stats /data
sudo chown kerby:users /data
```
There is deliberately no Phase 1 boot gate here: nothing in the boot path changes, and the only new boot-time
behaviour is one ordinary filesystem mount. `hardware-configuration.nix` is not touched.

C8 Reboot and verify `/data` mounts unattended:
```
findmnt -no SOURCE,OPTIONS /data    # btrfs at /dev/disk/by-uuid/<uuid>, unmodified options
sudo btrfs filesystem show /data    # label 'data', 2 devices
df -h /data                         # ≈880 GiB (885.45 GiB of devices, less duplicated metadata)
sudo btrfs device stats /data       # every counter 0
systemctl --failed                  # empty
```
If `/data` does not mount, `sudo btrfs device scan` then `sudo mount /data` is the first thing to try — the likely
failure is a member device not yet registered with the kernel, not a damaged filesystem, and root boots regardless,
so there is no emergency. **Fallback if the two-device pool proves flaky:** format p1 and p7 as two independent
single-device btrfs volumes — no scanned-device ordering anywhere, at the cost of two mountpoints.

C9 Final records — Phase 8 verbatim — then the Trash audit — Phase 7 verbatim.

**Rollback is trivially safe, and that is the point of this design.** `/data` is new and empty: delete the
`fileSystems."/data"` block, `nixos-rebuild switch`, and p1/p7 are inert unformatted space that can be reformatted,
repurposed, or later fed into Option A/B — with `/`, `/boot` and the bootloader never having been touched at all.

---

## Rejected alternative — A/B: growing the root filesystem

> **NOT THE CHOSEN PATH — do not execute.** Everything from here to Phase 8 describes the **rejected A/B
> alternative**, in which the reclaimed space is added to the **root** btrfs filesystem with `btrfs device add`.
> It is retained as reference and is the path to follow only if a larger `/` is actually wanted. It carries the
> boot-path risk that B′ avoids: a root filesystem that cannot mount without the newly created partition, a root
> PARTUUID repin, a scripted→systemd stage-1 initrd switch, an initrd `btrfs device scan` service, and a reboot gate
> that must pass before anything is deleted. Phase 0 above is shared and still applies; Phases 7 and 8 apply to
> both paths.

### Phase 1 — Prove the flake-managed firmware boot path before deletion

1.1 From `~/nixcfg`, inspect the existing declarative state:
```
sudo bootctl --esp-path=/boot status
findmnt -no SOURCE /boot
nix-shell -p efibootmgr --run "sudo efibootmgr -v"

```
`/boot` must be `/dev/nvme0n1p5`, and the p5 PARTUUID must be `226c2b0b-8bc9-4508-8fda-ad5b67a68e25`.

1.2 Before any partition deletion, stage the deterministic root configuration in `~/nixcfg/hosts/nixos/configuration.nix`, beside the existing boot-loader declarations:
```nix
  # Root btrfs is multi-device; pin the mount to p6's GPT partition GUID.
  fileSystems."/".device = lib.mkForce "/dev/disk/by-partuuid/67c0b066-5a52-4253-b075-d9d79fcf330a";

  # NOTE: this host currently runs the scripted (non-systemd) stage 1 — nothing
  # under ~/nixcfg sets boot.initrd.systemd today. Enabling it switches the
  # initrd implementation itself, a boot-path change beyond this service; the
  # Phase 1 reboot gate exists to prove that switch before any deletion.
  boot.initrd.systemd.enable = true;

  # Explicit registration fallback. The primary multi-device mechanism in a
  # systemd initrd is udev's 64-btrfs.rules (auto-included via fsPackages for a
  # btrfs root); this service is belt-and-braces. Do NOT order on
  # systemd-udev-settle.service: it is deprecated and absent from the NixOS
  # unit set (verified absent on systemd 261.2 here), so wants/after on it are
  # inert and would leave udev-trigger ordering as the only sequencing anyway.
  boot.initrd.systemd.services.btrfs-root-device-scan = {
    description = "Register all btrfs root devices before sysroot mount";
    wantedBy = [ "initrd-root-device.target" ];
    before = [ "initrd-root-device.target" "sysroot.mount" ];
    after = [ "systemd-udev-trigger.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs device scan";
      RemainAfterExit = true;
    };
  };
```
The leaf `fileSystems` override belongs in `configuration.nix`, not the generated `hardware-configuration.nix`.
Before continuing, confirm the initrd systemd service option and its `udev`/`sysroot.mount` ordering are accepted by
the current NixOS release. If the generated dependencies differ, stop and correct the configuration rather than
guessing. Treat the scripted→systemd stage-1 switch as part of this phase's blast radius: if the Phase 1.7 gate
reboot fails, every pre-Phase-1 generation boots a *different* initrd implementation, which matters for rollback
reasoning.

1.3 Format only the changed Nix file, then evaluate/build before any partition deletion:
```
cd ~/nixcfg
alejandra hosts/nixos/configuration.nix
sudo nixos-rebuild dry-build --flake .#nixos --impure --no-write-lock-file
```
If evaluation or dry-build fails, stop while all partitions are intact. Confirm `hardware-configuration.nix` was not
modified.

1.4 Apply the validated flake configuration and bootloader through NixOS; do not install the bootloader ad hoc:
```
sudo nixos-rebuild switch --flake .#nixos --impure --no-write-lock-file --install-bootloader
```
This applies the declared systemd-boot, root PARTUUID, and initrd service through NixOS and avoids an untracked
hand-installed bootloader state.

1.5 Verify the generated configuration and initrd before deletion:
```
grep -n 'by-partuuid/67c0b066-5a52-4253-b075-d9d79fcf330a' /etc/fstab
nix-shell -p dracut --run "sudo lsinitrd /run/current-system/initrd" | grep -E 'btrfs-root-device-scan|btrfs-progs/bin/btrfs'
```
`lsinitrd` is a dracut tool and is NOT installed on this NixOS host — it must be run via `nix-shell` as shown. Do not
hand-roll `zcat | cpio -t`: the NixOS initrd has a prepended microcode cpio, so naive decompression chokes;
`lsinitrd` handles the concatenation. The fstab root line must retain `subvol=@`. The initrd listing must show the
scan service, its target wants link, and the btrfs executable. `test -e /run/current-system/initrd` alone is
insufficient because it proves only that some initrd exists.

1.6 Re-read `efibootmgr -v`. A valid p5 `Linux Boot Manager` entry must exist. If it is not first, reorder only after
copying the complete current order, preserving every entry; do not hard-code the old `0022` number.

1.7 Reboot while p1 still exists: `sudo systemctl reboot`. After login, verify `BootCurrent` is the valid p5 entry,
`findmnt -no SOURCE /boot` is p5, `/` is mounted normally from the pinned p6 PARTUUID, and the expected initrd
service is present in the active generation. This is the deletion gate. If it fails, use the firmware Boot Menu or a
NixOS installer USB while all partitions are still intact; do not continue.


### Phase 2 — Delete Windows partitions and create raw btrfs member partition(s)

2.1 Save the pre-mutation partition table and reconfirm every relevant partition is unmounted:
```
sudo parted -s /dev/nvme0n1 print | tee ~/backups/nvme0n1-parted-2026-09-13-pre-mutation.txt
for p in /dev/nvme0n1p1 /dev/nvme0n1p3 /dev/nvme0n1p4 /dev/nvme0n1p7; do
  findmnt -rn -S "$p"
done
```
The `findmnt` loop must produce no output. Confirm p5/p6 start sectors match the Context table. Stop on any command
failure; never continue with a partially applied partition-table change.

2.2 Delete p1–p4 highest-number first. Run each command separately and stop immediately on any nonzero status:
```
sudo parted -s /dev/nvme0n1 rm 4
sudo parted -s /dev/nvme0n1 rm 3
sudo parted -s /dev/nvme0n1 rm 2
sudo parted -s /dev/nvme0n1 rm 1
```
After the sequence, save and inspect `sudo parted -s /dev/nvme0n1 print` before creating the replacement. If any
deletion fails, do not run later deletions or any Btrfs command.

2.3 Create the replacement in the explicitly numbered unused GPT entry 1. `-N 1` is intentional: `--append` may
choose a different unused GPT slot and must not be relied upon for `/dev/nvme0n1p1` naming:
```
printf '%s\n' 'start=2048, size=1024235520, type=0fc63daf-8483-4772-8e79-3d69d8477de4, name="nixos-pool"' \
  | sudo sfdisk --partno 1 --wipe=never --quiet /dev/nvme0n1
sudo partprobe /dev/nvme0n1
sudo udevadm settle
```
Fallback only if sfdisk rejects the exact command: `sudo parted -s /dev/nvme0n1 mkpart nixos-pool ext4 2048s 1024237567s`.
**Measured 2026-10-11: this fallback is the real path, not a fallback.** `/` (p6) and `/boot` (p5) are mounted from
this disk, so every `sfdisk` table write is refused by the in-use check (`This disk is currently in use … Use the
--no-reread flag`) and `parted` is required for the create. Treat the sfdisk form as reference only;
then run `partprobe`/`udevadm settle` and verify the resulting partition number before continuing. `partprobe` may
warn about re-reading a busy table (p5/p6 are mounted) even when sfdisk's per-partition kernel update succeeded —
the sole authoritative gate is the `lsblk` geometry check in 2.4, not partprobe's output. If the new p1 device node
genuinely does not appear, the clean pick-up is a reboot (the boot configuration was already validated in Phase 1);
do not use kpartx or other mapper hacks. If the kernel does not accept the new table, stop before any Btrfs operation.

2.4 Verify geometry before any Btrfs operation:
`lsblk -o NAME,SIZE,START,PARTTYPENAME,PARTLABEL,PARTUUID /dev/nvme0n1` must show p1 at start 2048, p5 still at
1024237568 with its exact PARTUUID `226c2b0b-8bc9-4508-8fda-ad5b67a68e25`, and p6 still at 1026334720 with its exact
PARTUUID `67c0b066-5a52-4253-b075-d9d79fcf330a`. If any existing partition moved, stop; before Btrfs changes only,
restore the GPT from the Phase 0 dump and reread the table. Do not proceed based on abbreviated or ellipsized output.

2.5 Only after the user explicitly approved p7 disposal in Phase 0.4, delete p7 and recreate its exact extent as GPT
entry 2 (not an automatically selected append slot). Run each command separately and stop on any failure:
```
sudo parted -s /dev/nvme0n1 rm 7
printf '%s\n' 'start=3074334720, size=832694415, type=0fc63daf-8483-4772-8e79-3d69d8477de4, name="nixos-pool2"' \
  | sudo sfdisk --partno 2 --wipe=never --quiet /dev/nvme0n1
sudo partprobe /dev/nvme0n1
sudo udevadm settle
lsblk -o NAME,SIZE,START,PARTLABEL,PARTUUID /dev/nvme0n1
```
If p7 is kept, or if the 0.4b disposition chose **B (standalone btrfs volume)**, do not run 2.5 and do not create p2.
Under B, p7 keeps its partition number and extent and is reformatted in place by 0.4b; under a decision to keep p7 as
NTFS, Phase 2 leaves it untouched entirely.

### Phase 3 — Add only confirmed-disposable raw space to root Btrfs

3.1 Record the pre-add device list, allocation, and profiles with privileged commands:
```
sudo btrfs filesystem show /
sudo btrfs filesystem usage /
sudo btrfs filesystem df /
```
Record the Data, Metadata, and System profiles. Stop if the actual profiles differ from the profile assumptions used
for the no-balance decision; do not silently accept RAID or other profiles.

3.2 Before adding p1, confirm its only signatures are the expected stale Windows signatures and that it is not mounted:
```
sudo wipefs -n /dev/nvme0n1p1
findmnt -rn -S /dev/nvme0n1p1
```
The `findmnt` command must produce no output, and `wipefs -n` must show only the expected stale ESP/foreign
signature; anything else is a stop condition. Then erase the stale signatures **before** the add — safe at this point
because p1 is not yet part of any filesystem:
```
sudo wipefs -a /dev/nvme0n1p1
sudo wipefs -n /dev/nvme0n1p1    # expect: no output
```
Rationale: `sfdisk --wipe=never` (Phase 2.3) preserves the old ESP vfat signature at p1's sector 0, and
`btrfs device add -f` does not guarantee its erasure on all progs versions/discard configurations. A surviving vfat
signature makes blkid ambivalent on p1: udev's `64-btrfs.rules` matches on `ID_FS_TYPE=="btrfs"`, so member
registration can break and a bogus `/dev/disk/by-uuid/<old-ESP-UUID>` symlink can reappear. Do **not** run `mkfs` on
p1. Then add p1 online **without** `-f` — a refusal at this point is itself the signature check:
```
sudo btrfs device add /dev/nvme0n1p1 /
```
`btrfs device add` changes filesystem metadata but does not copy existing file extents. If the add refuses due to a
remaining signature, stop and re-inspect with `wipefs -n`; do not escalate to `-f`. Post-add, verify that only btrfs
signatures remain:
```
sudo wipefs -n /dev/nvme0n1p1    # expect: only btrfs superblock offsets
```
If a stale non-btrfs signature somehow survives the add, erase it by explicit offset
(`sudo wipefs -o <offset> /dev/nvme0n1p1`) — **but note that a `dos` entry at `0x1fe` is refused by the same
non-whole-disk guard and cannot be removed that way** (measured 2026-10-11); clear such an entry with
`wipefs -a --force` *before* the add instead. NEVER `wipefs -a` on a device that has joined the filesystem — that would
erase the btrfs superblocks.

3.3 If and only if the 0.4b disposition chose **A (absorb)** and p7 was explicitly approved and recreated as p2,
repeat the same gates as 3.2 — mount check,
expected-signature check, explicit pre-add wipe, add WITHOUT `-f`, post-add signature verification:
```
sudo wipefs -n /dev/nvme0n1p2        # expect: only the stale NTFS signature
findmnt -rn -S /dev/nvme0n1p2        # expect: no output
sudo wipefs -a /dev/nvme0n1p2
sudo wipefs -n /dev/nvme0n1p2        # expect: no output
sudo btrfs device add /dev/nvme0n1p2 /
sudo wipefs -n /dev/nvme0n1p2        # expect: only btrfs superblock offsets
```
The same rules as 3.2 apply: any unexpected signature or mount is a stop condition; a `device add` refusal is the
signature check working — stop and re-inspect, never escalate to `-f`; post-add stale signatures are erased by
explicit offset only.

3.4 Verify immediately using privileged Btrfs reports: `sudo btrfs filesystem show /` lists 2 (or 3) devices;
`sudo btrfs filesystem usage /` reports a total device size of ≈1464.95 GiB (1.43 TiB), or ≈1862.01 GiB (1.82 TiB)
with p7 — exact expectations, not approximations: p6+p1 = 3,072,235,520 sectors, plus p2 = 3,904,929,935 sectors; and
`df -h /` is consistent with the expanded filesystem. Treat `btrfs filesystem usage` as authoritative rather than
relying on `df` alone. Do not run a full balance unless the recorded profiles require one: existing data need not
move for single-profile allocation, but the actual profile must justify that decision.

### Phase 4 — Confirm the validated root configuration after Btrfs device add

4.1 The root PARTUUID override and initrd scan service must already have been applied, generated, and tested in Phase
1 before this phase. If Phase 1.2–1.7 was skipped or any generated-initrd check failed, stop; do not introduce the
configuration for the first time after deleting partitions.

4.2 Confirm the active generated configuration still points at p6 and contains the initrd scan service:
```
grep -n 'by-partuuid/67c0b066-5a52-4253-b075-d9d79fcf330a' /etc/fstab
nix-shell -p dracut --run "sudo lsinitrd /run/current-system/initrd" | grep -E 'btrfs-root-device-scan|btrfs-progs/bin/btrfs'
```
The fstab root line must retain `subvol=@`; the initrd listing must show the scan service and executable. Do not claim
that a stage-2 unit listing or the mere existence of the initrd proves initrd contents. No rebuild is needed here: the
configuration was deliberately activated before partition deletion.

4.3 Test the pinned root member while the running system has all members registered:
```
sudo mkdir -p /mnt/test-root
sudo mount -o subvol=@ /dev/disk/by-partuuid/67c0b066-5a52-4253-b075-d9d79fcf330a /mnt/test-root
sudo test -d /mnt/test-root/etc -a -d /mnt/test-root/home -a -d /mnt/test-root/nix
sudo umount /mnt/test-root
sudo rmdir /mnt/test-root
```
Expected: mount succeeds, the three directories exist, and the temporary mount is gone. This test does not access any
CIFS mount.
### Phase 5 — Reboot verification

`sudo systemctl reboot`, then after boot:
```
findmnt -no SOURCE,OPTIONS /          # member of p6's btrfs fs, subvol=/@
sudo btrfs filesystem show /          # 2 (or 3) devices, label NixOS_root
sudo btrfs filesystem usage /         # authoritative expanded capacity
df -h /                               # consistent with the expanded filesystem
sudo btrfs device stats /             # every counter 0
systemctl --failed                    # empty
```
Do not rely on the previous generation as the only rollback: it still uses the ambiguous FS-UUID path. If the root
mount fails, use the NixOS installer USB, scan every present member before mounting, then repair the flake:
```
sudo btrfs device scan /dev/nvme0n1p6 /dev/nvme0n1p1 /dev/nvme0n1p2  # omit p2 if p7 was kept
sudo mount -o subvol=@ /dev/nvme0n1p6 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p5 /mnt/boot
```
From the mounted system, prepare the installer environment before entering it, then revert the flake override/service
and rebuild the installed system explicitly:
```
sudo mount --rbind /dev /mnt/dev
sudo mount --make-rslave /mnt/dev
sudo mount --rbind /proc /mnt/proc
sudo mount --make-rslave /mnt/proc
sudo mount --rbind /sys /mnt/sys
sudo mount --make-rslave /mnt/sys
sudo mount --rbind /run /mnt/run
sudo mount --make-rslave /mnt/run
sudo nixos-enter --root /mnt
```
Inside `nixos-enter`, revert the flake configuration, then run the following against the known installed checkout:
```
cd /home/kerby/nixcfg
nixos-rebuild boot --flake /home/kerby/nixcfg#nixos --impure --no-write-lock-file
```
If that checkout is unavailable inside the mounted root, stop — this host is flake-only and has no `/etc/nixos`
configuration to fall back to; restore or repair the `~/nixcfg` checkout from the installer environment before
rebuilding. Exit and reboot only after the new generation is built. Once
booted into the repaired generation, remove newly added Btrfs devices with `sudo btrfs device delete` only if returning
to a single-device root is required. Do not restore the old GPT dump while the root Btrfs filesystem still knows about
added members.

### Phase 6 — Leave EFI entries alone during the storage cutover

No EFI entry deletion is required to reclaim storage. After Phase 5, record a fresh
`nix-shell -p efibootmgr --run "sudo efibootmgr -v"` and confirm the valid p5 Linux Boot Manager entry remains present
and first. Leave stale Windows/GRUB/removable-disk entries untouched in this plan; deleting EFI variables adds risk
but no storage benefit. EFI cleanup can be a separate, independently verified task after the new root has survived a
reboot.


### Phase 7 — Empty only local-provenance Trash entries

The user requested emptying Trash, but deleting all of `~/.local/share/Trash` blindly could permanently remove media
that originated on a CIFS mount. Audit every `.trashinfo` sidecar and preserve anything whose decoded `Path=` is under
the configured Samba targets (`/mnt/media`, `/mnt/immich-data`, `/mnt/t7-shield`) or any currently active CIFS target,
plus any entry with missing, malformed, relative, or otherwise unknown provenance, or a missing sidecar. This protects
automounts even when they are not currently mounted. The deletion rule is an ALLOWLIST, not a denylist: an entry is
deleted only when its decoded origin is under `$HOME` AND not under any current mountpoint. An origin on removable or
since-removed media (e.g. `/run/media/kerby/backup-t7/...`) decodes to a clean absolute path that is NOT under the
configured CIFS targets — under a denylist it would be wrongly treated as local and destroyed, even though the trash
payload may be the only copy. As of 2026-09-13 all 2106 sidecars have `/home/kerby/...` origins, so the dry run must
show exactly 2106 `WOULD_DELETE` lines; investigate any deviation before the apply run. This phase only ever empties
the HOME trash: media trashed directly on a Samba share lives in that share's topdir trash (e.g.
`/mnt/media/.Trash-1000`), which this plan never opens, lists, or empties — those remain after Phase 7 by design.

Run the following exact script twice. The first run is a dry run (`TRASH_APPLY=0`) and must be reviewed before the
second run. Only rerun with `TRASH_APPLY=1` after every `WOULD_DELETE` entry has been confirmed as local; any
`PROTECTED` or `UNKNOWN` entry remains preserved. Do not change the script between runs. Review the printed SUMMARY
(entries and bytes grouped by origin directory) first — it makes a ~2106-entry review feasible — then the full list.
```sh
TRASH_APPLY=0 python3 - <<'PY'
from pathlib import Path
from urllib.parse import unquote, urlsplit
from collections import Counter
import os, shutil, subprocess

trash = Path.home() / ".local/share/Trash"
files, info = trash / "files", trash / "info"
home = Path.home()
apply = os.environ.get("TRASH_APPLY") == "1"

def findmnt_targets(*args):
    """findmnt exits 1 when a query matches nothing — the normal state once
    the CIFS automounts idle out. An empty match list is valid input, not an
    error; check_output here crashed an earlier version of this script."""
    result = subprocess.run(["findmnt", "-rn", "-o", "TARGET", *args],
                            capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"findmnt {args} failed: {result.stderr.strip()}")
    return [Path(os.path.normpath(x)) for x in result.stdout.splitlines()]

configured_cifs = [Path("/mnt/media"), Path("/mnt/immich-data"), Path("/mnt/t7-shield")]
active_cifs = findmnt_targets("-t", "cifs")
cifs = configured_cifs + active_cifs
all_mounts = findmnt_targets()
summary = Counter()
summary_bytes = Counter()

def under(path, root):
    try:
        return os.path.commonpath((str(path), str(root))) == str(root)
    except ValueError:
        return False

def decode_origin(raw):
    """Return only a normalized absolute local path; unknown forms return None."""
    try:
        value = unquote(raw.strip())
        if value.startswith("file://"):
            parsed = urlsplit(value)
            if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
                return None
            value = unquote(parsed.path)
        path = Path(value)
        if not path.is_absolute():
            return None
        return Path(os.path.normpath(str(path)))
    except (OSError, ValueError):
        return None

def has_mount_below(path):
    return any(target == path or under(target, path) for target in all_mounts)

def payload_size(path):
    if path.is_symlink() or not path.is_dir():
        try:
            return path.stat(follow_symlinks=False).st_size
        except OSError:
            return 0
    total = 0
    for root, _dirs, names in os.walk(path):
        for name in names:
            try:
                total += Path(root, name).stat(follow_symlinks=False).st_size
            except OSError:
                pass
    return total

def remove(path):
    if path.is_symlink() or not path.is_dir():
        path.unlink(missing_ok=True)
    else:
        shutil.rmtree(path)

for sidecar in sorted(info.glob("*.trashinfo")):
    raw_origin = None
    try:
        for line in sidecar.read_text(errors="replace").splitlines():
            if line.startswith("Path="):
                raw_origin = line[5:]
                break
    except OSError as exc:
        print("UNKNOWN", sidecar, f"unreadable sidecar: {exc}", "preserved")
        continue

    origin = decode_origin(raw_origin) if raw_origin is not None else None
    payload = files / sidecar.stem
    if origin is None or not payload.exists():
        print("UNKNOWN", sidecar, raw_origin or "missing Path=", "preserved")
        continue
    if any(under(origin, root) for root in cifs):
        print("PROTECTED", sidecar, origin, "preserved")
        continue
    # Allowlist, not denylist: delete only confirmed-local entries — origin
    # under $HOME and not under ANY current mountpoint. Origins on removable
    # or since-removed media (e.g. /run/media/kerby/backup-t7/...) would pass
    # a CIFS denylist and lose their only copy.
    if not under(origin, home):
        print("UNKNOWN", sidecar, origin, "origin outside $HOME; preserved")
        continue
    if any(m != Path("/") and under(origin, m) for m in all_mounts):
        print("PROTECTED", sidecar, origin, "origin under a mountpoint; preserved")
        continue
    if has_mount_below(payload):
        print("PROTECTED", sidecar, payload, "mount below payload; preserved")
        continue

    group = "/".join(origin.parts[:4])
    size = payload_size(payload)
    summary[group] += 1
    summary_bytes[group] += size
    print("DELETE" if apply else "WOULD_DELETE", sidecar, origin)
    if apply:
        remove(payload)
        sidecar.unlink()

for payload in sorted(files.iterdir() if files.exists() else []):
    sidecar = info / f"{payload.name}.trashinfo"
    if not sidecar.exists():
        print("UNKNOWN", payload, "missing sidecar", "preserved")

print()
print("=== SUMMARY (entries, bytes) by origin group ===")
for group in sorted(summary):
    print(f"{summary[group]:6d}  {summary_bytes[group]:14d}  {group}")
print(f"{sum(summary.values()):6d}  {sum(summary_bytes.values()):14d}  TOTAL",
      "(deleted)" if apply else "(would delete)")
PY
```
The script requires an absolute, successfully decoded, `$HOME`-local provenance path before it can delete anything.
It handles the standard absolute Trash path and `file://` form; all other forms are `UNKNOWN`. `findmnt` exits 1 when
a query matches nothing (the normal state once the CIFS automounts idle out), so the script tolerates return codes 0
and 1 — an earlier version used `check_output` and crashed with `CalledProcessError` in exactly that common case. It
also refuses to recursively remove a Trash payload if the payload or any descendant is a mountpoint. No command in
this phase opens, writes, unmounts, or deletes `/mnt/media`, `/mnt/immich-data`, `/mnt/t7-shield`, or another CIFS
mount.

### Phase 8 — Final record

```
test ! -e ~/backups/nvme0n1-gpt-2026-09-13-after.sfdisk
test ! -e ~/backups/efi-boot-2026-09-13-after.txt
df -h /
lsblk -o NAME,SIZE,PARTTYPENAME,PARTLABEL,PARTUUID /dev/nvme0n1
sudo parted -s /dev/nvme0n1 print
sudo btrfs filesystem show /
sudo btrfs filesystem usage /
sudo btrfs device stats /
sudo sfdisk -d /dev/nvme0n1 > ~/backups/nvme0n1-gpt-2026-09-13-after.sfdisk
nix-shell -p efibootmgr --run "sudo efibootmgr -v" > ~/backups/efi-boot-2026-09-13-after.txt
```
Use a new filename if either after-record already exists. Record the final partition table, Btrfs device list, free
space, existing Btrfs stats, and any preserved Trash entries. The GPT dumps are records, not a rollback mechanism after
Btrfs devices have been added. A root rollback is the flake change plus `btrfs device delete` (new devices removed one
at a time, p2 before p1 if p7 was reclaimed). The Samba mounts are not opened or written by this verification.

## Critical files & anchors

- `~/nixcfg/hosts/nixos/configuration.nix` — boot-loader block (~lines 77–80) is where the root PARTUUID override and
  initrd btrfs scan service go; `lib` and `pkgs` are already in scope.
- `~/nixcfg/hosts/nixos/hardware-configuration.nix` — reference only: generated `/` and `/boot` declarations. Do not
  edit; the override in `configuration.nix` wins.
- `~/nixcfg/hosts/nixos/default.nix` — confirms the host imports the flake modules.
- `~/backups/` — pre/post partition and EFI records, and the `shared-old-*.manifest` p7 listing with its checksum.
- `/dev/nvme0n1p7` — the `Shared` partition. Under disposition B it is reformatted in place and mounted at `/data`
  (declared in `configuration.nix` by PARTUUID); under A it becomes GPT entry 2 `nixos-pool2`. Never mounted at a
  fixed path until the disposition is chosen.
- `~/.local/share/Trash/{files,info}` — audited by provenance before local-only deletion.

## Verification

| after | command | expected |
|---|---|---|
| Phase 0 | complete p3/p7 manifests, `sha256sum`, health checks, temporary-partition `findmnt` | Windows contents and exact p7 manifest reviewed; backup gate passes; all temporary mounts are gone; CIFS mounts are unchanged and not touched |
| Phase 0.3 + C0 | read-only `ntfs3` mount, full `find` manifest + `sha256sum`, `cp -a` of the wanted items, size comparison | p3 reviewed in full (377,354 entries, manifest recorded); the Resolve project DB, `Photos-1-001.zip`, the two Downloads documents and the verbatim Recycle Bin are copied locally and size-verified **before** C2; nothing was written to p3 at any point |
| Chosen path C1–C5 | `sfdisk -d` and `efibootmgr -v` pre-records, `parted rm`, **`parted mkpart`/`type`/`name`** (sfdisk refuses on this busy disk), `lsblk -o …START,PARTTYPENAME,PARTUUID` | p1 removed and recreated at sector 2048 as `Linux filesystem` (~488.4 GiB, asserted as start `2048` / `524408586240` bytes); p7 retagged and renamed with its extent unchanged; p5/p6 starts and PARTUUIDs identical to the pre-records; nothing mounted on p1/p3/p4/p7. Sizes/geometry for p1 and the slot-1 assignment rehearsed offline 2026-10-11 |
| Chosen path C6 | `wipefs -n` before, plain `wipefs -a`, leftover loop with targeted `wipefs -a --force`, `mkfs.btrfs -d single -m raid1` (no `-f`), `btrfs filesystem show` | p1's three vfat entries erased by the plain wipe; p7's `dos` at `0x1fe` caught by the leftover check and cleared with a targeted `--force` (a plain `wipefs -a` and `wipefs -o` both refuse it); both devices report no signatures before `mkfs`; one btrfs filesystem `data` on 2 devices, Data `single`, Metadata `RAID1`; `mkfs.btrfs` itself never forced. Logic rehearsed offline on p1-/p7-shaped images 2026-10-11 |
| Chosen path C7–C8 | `alejandra`, `dry-build`, `switch`, `findmnt /data`, `btrfs filesystem show /data`, `btrfs device stats /data`, `df -h /data`, `systemctl --failed`, reboot | `/data` declared by filesystem UUID, no `nofail`/automount; mounts unattended after reboot with ≈880 GiB usable; stats 0; no failed units; `/` mounted from p6 exactly as before, single device, boot path unmodified |
| Phase 0.4b | p7 read-only mount + full listing + manifest checksum (done 2026-10-11); `ntfsinfo -m` only if the volume is unmounted | p7 holds 10 entries / ~1.0 MiB, all recorded in `~/backups/shared-old-2026-10-11.manifest` (`0496b60a…`); nothing on p7 constrains reclamation; the chosen disposition is B′ (one new `/data` volume), with A/B recorded as the rejected alternative |
| Phase 1 | dry-build, generated fstab/initrd inspection (`lsinitrd` via `nix-shell -p dracut`), `efibootmgr -v`, `findmnt -no SOURCE /boot`, successful reboot | flake evaluates before deletion; initrd contains the scan service, target wants link, and btrfs executable; firmware uses the p5 Linux Boot Manager; `/boot` is p5 and root uses the pinned p6 PARTUUID |
| Phase 2 | `parted`/`lsblk` after table reread | new p1 is exactly 488.39 GiB at sector 2048; p5/p6 starts and exact PARTUUIDs are unchanged; p7 is either unchanged or explicitly approved/recreated as p2; kernel sees the new table |
| Phase 3 | privileged `btrfs filesystem show/usage/df`, pre/post-add `wipefs -n`, and `findmnt` gates | 2 (3) devices; profiles match the no-balance decision; pre-add stale signatures erased with `wipefs -a`; `btrfs device add` runs WITHOUT `-f`; post-add `wipefs -n` shows only btrfs; expanded capacity matches the exact GiB figures; no Samba path involved |
| Phase 4 | active fstab/initrd checks and privileged pinned mount test | prevalidated configuration is still active; generated root line uses p6 PARTUUID and `subvol=@`; test mount succeeds and temporary mount is gone |
| Phase 5 | `findmnt -no SOURCE /`, privileged Btrfs usage/stats, `systemctl --failed` | root booted unattended, all members visible, authoritative usage is expanded, stats 0, no failed units |
| Phase 7 | dry-run Trash audit followed by explicitly gated apply run | every deletion was reviewed as known-local (origin under `$HOME`, not under any mountpoint); CIFS-originated, out-of-`$HOME`, under-a-mountpoint, malformed, mount-containing, and unknown entries preserved; grouped summary reviewed before the apply run |
| Phase 8 | final `lsblk`, `parted`, privileged Btrfs reports, and EFI record | expected local layout, expanded Btrfs device list/capacity, clean stats, and boot entry; no CIFS mount was opened or written |


## Assumptions & contingencies

- **No automatic p7 classification.** The complete, checksummed read-only manifest is shown to the user; reclaim
  happens only after explicit confirmation against that exact manifest. Any uncertainty means p7 stays untouched.
- **The chosen path is B′ and the A/B phases are fenced off.** `/data` is a new, empty, standalone btrfs volume on
  p1+p7; the root filesystem, `/boot`, the bootloader and the initrd are untouched, which is why the multi-device-root
  gate, the PARTUUID repin, the stage-1 initrd switch and the pre-deletion reboot gate do not apply. Everything from
  `### Phase 1` to Phase 8 is the rejected alternative, retained for reference and not to be executed unless the
  disposition is revisited. Because B′ never mutates the root filesystem's metadata, the p6 independent-backup gate
  is no longer a precondition for the destructive steps — it remains good practice and is still the gate for the
  fenced A/B path.
- **B′'s own multi-device caveat is not hidden.** `/data` spans two partitions on the same physical NVMe, so it
  depends on both member devices being registered before the mount (`btrfs device scan`, normally driven by udev). A
  failure there is survivable — root still boots, `/data` is simply absent and the failed unit is visible — and the
  documented fallback is two independent single-device volumes. `-m raid1` on one physical disk is not redundancy.
- **p7 write failure is diagnosed, never repaired.** The 0.4b diagnosis is read-only. `ntfsfix`, read-write mounts,
  and any other NTFS repair are forbidden: the cause (Fast Startup/hibernation, missing `uid=`/`gid=`, or an
  `ntfs3` read-write refusal) does not change the disposition now that Windows is removed, and writing to p7 before
  the manifest is approved risks destroying the only copy of its contents.
- **p7 disposition is an explicit, recorded choice.** A (absorb into root btrfs) or B (standalone btrfs volume) is
  chosen in 0.4b before Phase 2, and 2.5/3.3 run only under A. B leaves p7's partition number and extent untouched
  and only replaces its contents, so Phases 1–5 are otherwise unchanged.
- **Bulk pool sizing is not the goal of collecting p7.** Whether p7 becomes `/data` or part of `/`, it does not
  satisfy the p6 backup gate; the gate still requires an independent backup of irreplaceable local data.
- **No automatic Samba Trash deletion.** The Trash audit has a dry-run/apply gate and is an allowlist: only entries
  with a decoded origin under `$HOME` and not under any current mountpoint are deleted; CIFS-originated,
  removable-media, malformed, mount-containing, and unknown-provenance entries are preserved. An incomplete emptying
  is safer than deleting media. CIFS-topdir trash (e.g. `/mnt/media/.Trash-1000`) is never opened or emptied.
- **No Samba access in the procedure.** `/mnt/media`, `/mnt/immich-data`, `/mnt/t7-shield`, and all current/future
  CIFS targets are not unmounted, remounted, listed for verification, written, or cleanup-targeted by this plan.
- **Windows/p6 backup gate.** If p3 is unreadable or contains wanted data, stop before deletion. If p6 has nonzero
  Btrfs device stats, an incomplete scrub, or no confirmed independent backup of irreplaceable local data, stop before
  Phase 3.
- **Phase 1 gate.** The root flake/initrd configuration is dry-built, inspected, activated, and rebooted before any
  deletion. This phase also switches stage 1 from scripted to systemd (`boot.initrd.systemd.enable`) — a boot-path
  change in its own right, which is why the gate precedes all destructive work. If that reboot fails, use the
  firmware Boot Menu or NixOS installer USB while all partitions are intact.
- **Multi-device root mount.** The initrd scan service is explicitly enabled and validated before deletion, then the
  active configuration and live pinned mount are checked after device add and the root is rebooted. If root fails to
  mount, use the exact installer recovery sequence in Phase 5, then only use `btrfs device delete` after booting the
  repaired generation. Never restore the old GPT dump after a Btrfs member has been added.
- **No `mkfs`, no `-f`, and no unreviewed balance.** Stale signatures are erased with `wipefs -a` BEFORE
  `btrfs device add`, which then runs without `-f` — a refusal is itself the signature check. Post-add `wipefs -n`
  must show only btrfs; any later signature removal is by explicit offset (`wipefs -o`), never `wipefs -a` on a
  joined member — **with the measured caveat that a `dos` entry at `0x1fe` is refused by both a plain `wipefs -a` and
  `wipefs -o`, so it must be cleared with a targeted `wipefs -a --force` before the device joins anything.** A balance
  is run only if the recorded allocation profiles require it, because unnecessary balancing creates long, avoidable
  metadata/data movement.
- **Flake discipline.** All persistent configuration changes are under `~/nixcfg`; `/etc/fstab` and the initrd are
  generated outputs. Use `nixos-rebuild ... --flake .#nixos --impure --no-write-lock-file`; do not hand-edit generated
  files or use an ad-hoc bootloader configuration as the final state.
- **Two reboots** are required (Phase 1 gate and Phase 5 verification), with the user present; the user types sudo
  passwords for non-`nixos-rebuild` commands.
- `~/Videos` → Samba move, `time.hardwareClockInLocalTime`, kernel params, and the commented-out GRUB Windows entry
  remain untouched.

