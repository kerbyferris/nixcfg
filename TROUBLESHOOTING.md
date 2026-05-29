# Troubleshooting Reference (2026-05-28)

> **Issue 6 — RESOLVED.** Phase 1-3 complete. systemd-boot is now the permanent
> EFI default (`bootctl install`). GRUB entries are still on the ESP but ignored.
> If a future EFI update resets boot order, re-run `sudo bootctl install`.
>
> **Hyprland 0.55 notes:** `windowrulev2` is deprecated in 0.55 but still
> functional. `togglesplit` dispatcher and `dwindle:pseudotile` were removed.
> See Issue 7 for details on the config workarounds applied.

## Quick checks after reboot

```bash
# Monitor config
cat ~/.config/hypr/monitors.conf
hyprctl monitors

# Daemon status
systemctl --user status hyprdynamicmonitors.service
systemctl --user status hyprdynamicmonitors-prepare.service

# Waybar
ps -eo pid,comm | grep waybar

# Hyprland config errors
hyprctl configerrors

```

## Issue 1: Kvantum blocks nixos-rebuild

**Symptom:** `home-manager-kerby.service` fails with "Read-only file system" on
`~/.config/Kvantum/Base16Kvantum/Base16Kvantum.kvconfig`.

**Root cause:** Stylix home-manager module auto-enables Qt target when
`nixosConfig != null` (always under NixOS). The NixOS-level
`lib.mkForce false` doesn't propagate — `stylix.targets.qt.enable` is NOT in
Stylix's `copyModules` list for HM integration.

**Fix:** Added `stylix.targets.qt.enable = false;` to `home/kerby/home.nix`.

**Workaround (if fix isn't applied):**
```bash
rm -rf ~/.config/Kvantum
sudo nixos-rebuild switch --flake .#nixos --impure
```

## Issue 2: Monitor config not applied on boot

**Symptom:** Monitors come up with wrong layout after cold boot, then fix
themselves after a few seconds (or don't fix at all).

**Root cause (2 separate issues):**

1. **Daemon ordering:** hyprdynamicmonitors daemon was ordered `After=graphical-session.target`,
meaning it started AFTER Hyprland already read `monitors.conf`. Meanwhile the
`prepare` service removes `monitor = …,disable` lines before Hyprland starts.

2. **Cold boot race:** On cold boot, the GPU DRM driver may not have exposed
DP-1 in `/sys/class/drm/` by the time the daemon starts. Also UPower's D-Bus
interface may not be ready for lid state queries. When either check fails, the
clamshell profile (which requires both `lid_state = "Closed"` AND DP-1 present)
doesn't match, and no profile is written.

**Fix (4 changes):**
1. `home/features/desktop/hyprland.nix` — overrode daemon systemd unit:
   - `Before=graphical-session-pre.target` (was `After=graphical-session.target`)
   - `WantedBy=graphical-session-pre.target` (was `graphical-session.target`)
   - Removed `Requires=graphical-session.target`
   - Added `After=upower.service` (ensures lid state DBus query works)
   - Added `ExecStartPre` retry loop: polls `/sys/class/drm/card*-DP-*/status`
     up to 10 seconds, waiting for the GPU to expose DP-1
2. `home/features/desktop/hyprdynamicmonitors/config.toml` — post_apply_exec:
   ```
    until hyprctl monitors >/dev/null 2>&1; do sleep 0.5; done; hyprctl reload
    ```

**Boot sequence before fix:**
```
prepare (cleans monitors.conf) → Hyprland starts (reads stale/incomplete) →
daemon starts → writes correct config → hyprctl reload
```

**Boot sequence after fix:**
```
prepare (cleans monitors.conf) → daemon starts → writes correct config →
Hyprland starts (reads correct monitors.conf) → post_apply_exec waits for
Hyprland then reloads
```

**Debug commands:**
```bash
journalctl --user -u hyprdynamicmonitors.service -b --no-pager
journalctl --user -u hyprdynamicmonitors-prepare.service -b --no-pager
ls -la ~/.config/hypr/monitors.conf
ls -la ~/.config/hyprdynamicmonitors/hyprconfigs/
```

**Profiles (in `~/.config/hyprdynamicmonitors/hyprconfigs/`):**
- `laptop-only.conf` — eDP-1 only, lid open
- `dual-monitor.conf` — eDP-1 + DP-1, lid open
- `clamshell.conf` — DP-1 only, lid closed, eDP-1 disabled

## Issue 3: Waybar doesn't restart after nixos-rebuild

**Symptom:** After `nixos-rebuild switch`, waybar is killed by activation but
doesn't restart. Also manifests as waybar running from old Nix store path
before the rebuild completes.

**Root cause:** Two issues:

1. `pkill` in HM activation wasn't in PATH (procps not in activation
environment) and `2>/dev/null` hid the failure. Also launch script used
`pkill -f '\.waybar-wrapped$'` but the cmdline is just `waybar`, not
`.waybar-wrapped`. The process name (comm) IS `.waybar-wrapped` but `-f`
matches cmdline, not comm.

2. Home-manager activation hung trying to reload user dbus-broker.service
(see Issue 4), preventing the activation from completing successfully.

**Fix:**
1. `home/kerby/home.nix` — activation uses `${pkgs.procps}/bin/pkill -u $USER '\.waybar-wrapp'`
2. `home/features/desktop/waybar/launch.sh` — uses `pkill '\.waybar-wrapp'` (match comm, not cmdline)
3. `home/kerby/home.nix` — `systemd.user.startServices = false` prevents the
   dbus-broker reload hang, allowing activation to complete fully

**Manual restart:**
```bash
pkill '\.waybar-wrapp'
# or press Alt+Shift+B
```

## Issue 4: Build hangs at "reloading the following user units: dbus.service"

**Symptom:** During `nixos-rebuild switch`, the output hangs for ~90 seconds at:

```
reloading the following user units: dbus.service
```

followed by:

```
warning: the following user units failed: dbus-broker.service
warning: user activation for kerby failed
```

**Root cause:** home-manager's activation script tries to reload all changed
user systemd units via `systemctl --user reload`. `dbus-broker.service` is the
active user D-Bus message bus and cannot be reloaded while in use. The reload
command hangs until systemd times out. This failure cascades into:
- New packages not linked into user profile → `opencode` not in PATH
- Hyprland config symlinks not updated → wrong mod key mappings
- Waybar activation script (pkill) runs but full activation doesn't complete

**Fix:** `systemd.user.startServices = false;` in `home/kerby/home.nix`.
This tells home-manager to not attempt to reload/restart user services
during activation. Services will pick up new binaries on next login.
Activation scripts (like the waybar pkill) still run normally.

**Note:** This is a known NixOS 24.11 behavior with `dbus-broker` (the default
D-Bus implementation since 24.11). `dbus-daemon` (the old implementation) could
be reloaded; `dbus-broker` cannot because it's the active message bus.

## Issue 5: Networking down for ~20 seconds during rebuild

**Symptom:** Network connectivity drops for 15–30 seconds during `nixos-rebuild
switch`. WiFi disconnects/reconnects. Tailscale and SSH connections drop.

**Root cause:** `nixos-rebuild switch` restarts systemd services whose
dependencies have changed. `NetworkManager.service` is the sole networking
provider. When NetworkManager or any of its dependencies (systemd, glib,
dbus, etc.) change — which happens frequently with `nixos-unstable` — the
service is restarted, tearing down all interfaces. DHCP renegotiation adds
several seconds per interface. Tailscale (`tailscaled.service`) also restarts
if its dependencies change, adding to the downtime.

Additionally, Avahi (`avahi-daemon.service`), CUPS (`cups.service`), and
OpenSSH (`sshd.service`) may restart if their dependencies change, though
these don't cause the core networking outage themselves.

**Mitigations (pick one):**

1. Use `nixos-rebuild boot` instead of `switch`, then reboot at a convenient time:
   ```bash
   sudo nixos-rebuild boot --flake .#nixos --impure && sudo reboot
   ```

2. Pin specific packages to reduce unnecessary NetworkManager restarts:
   ```nix
   # In hosts/nixos/configuration.nix
   systemd.services.NetworkManager.reloadTriggers = [];
   ```

3. Accept it as normal NixOS behavior. The outage is temporary and the
   system recovers automatically.

**This is expected NixOS behavior** — any distro that replaces live services
during an upgrade will experience brief service interruptions. NixOS is just
more aggressive about restarting services that have changed.

## Architecture notes

- **Stylix**: NixOS module at `stylix.nixosModules.stylix` (flake.nix:71).
  Home-manager module auto-imported via `stylix.homeManagerIntegration.autoImport`
  (`stylix/home-manager-integration.nix`). Qt target auto-enables under NixOS:
  `modules/qt/hm.nix:15-18` — `autoEnable = nixosConfig != null`.

- **hyprdynamicmonitors**: Daemon writes a **symlink** from
  `~/.config/hypr/monitors.conf` → `~/.config/hyprdynamicmonitors/hyprconfigs/<profile>.conf`.
  Profile files are HM-managed symlinks to Nix store.

- **hyprdynamicmonitors-prepare**: Runs `TruncateDestination()` which reads
  monitors.conf, removes lines matching `.*monitor.*=.*disable.*`, then calls
  `WriteAtomic` which converts symlink→regular file (because `os.Stat` follows
  symlinks, sees regular file target, `os.Rename` replaces the symlink).
  Daemon later removes the regular file and recreates the symlink.

## Issue 6: System boots into old generation (stale GRUB, systemd-boot not first) — **RESOLVED 2026-05-28**

**Symptom:** After `nixos-rebuild switch`, the system seems updated (`/run/current-system`
points to new generation, mod key is ALT, opencode works). But after reboot, everything
is broken again — wrong mod key, no opencode, no hyprdynamicmonitors services.

**Root cause:** Both GRUB and systemd-boot are installed on the ESP, but the EFI boot
order has GRUB first. GRUB's config (`/boot/grub/grub.cfg`) is stale and points to an
ancient Sep 2025 generation. Every reboot boots via GRUB into that old generation,
regardless of how many `nixos-rebuild switch` calls were made (those update systemd-boot
entries, which GRUB doesn't read).

**How to verify:**

```bash
bootctl
# Look for "Boot Loaders Listed in EFI Variables" — both GRUB and systemd-boot appear

cat /proc/cmdline | grep init=
# Shows the old generation path — this is set at boot, never changes
# Compare to:
readlink -f /run/current-system
# Shows the current (switched) generation — different after nixos-rebuild switch
```

Current EFI boot entries (on this system):
- `NixOS-boot` (ID 0x0020) → `/EFI/NixOS-boot/grubx64.efi` — GRUB, boots first
- `Linux Boot Manager` (ID 0x0022) → `/EFI/systemd/systemd-bootx64.efi` — systemd-boot
- Both on partition `226c2b0b-8bc9-4508-8fda-ad5b67a68e25` (`/boot`)

**Fix plan (3 phases, with fallback at every step):**

```
Phase 1 — Prepare systemd-boot entries (no risk):
  sudo nixos-rebuild boot --flake ~/nixcfg#nixos --impure
  # Only writes to /boot/loader/entries/, doesn't touch EFI boot order

Phase 2 — One-time test via BIOS boot menu:
  sudo reboot
  # Press F12 (or your firmware's boot menu key) during POST
  # Select "Linux Boot Manager" (systemd-boot)
  # If it boots into a working system → proceed to Phase 3
  # If it fails → reboot normally, GRUB is still the default, try Phase 3a instead

Phase 3 — Make permanent:
  sudo bootctl install
  # Installs systemd-boot and makes it the default EFI entry
  # OR manually reorder with efibootmgr:
  sudo efibootmgr --bootorder 0022,<current-order-minus-0022>
  sudo reboot

Phase 3a — Switch config back to GRUB (if systemd-boot test fails):
  # In hosts/nixos/configuration.nix:
  #   boot.loader.systemd-boot.enable = false;
  #   boot.loader.grub.enable = true;
  #   boot.loader.grub.efiSupport = true;
  #   boot.loader.grub.devices = ["nodev"];
  sudo nixos-rebuild boot --flake ~/nixcfg#nixos --impure
  sudo reboot
```

**Fallback at any point:**
- BIOS boot menu (F12) → select "NixOS-boot" (GRUB) — GRUB files are untouched
- BIOS setup → reorder boot priorities manually
- Boot an older NixOS generation from either bootloader's menu
- Live USB — `/nix/store` (nvme0n1p6 btrfs) and `/home` are on separate partitions

**Key safety property:** `nixos-rebuild boot` and `bootctl install` only write to
`/boot/loader/` and `/boot/EFI/systemd/`. They never touch `/EFI/NixOS-boot/grubx64.efi`.
GRUB remains as the escape hatch throughout the entire process.

## Issue 7: Hyprland 0.55 config incompatibilities — **RESOLVED 2026-05-28**

**Symptom:** `hyprctl configerrors` shows multiple errors:
- `Invalid dispatcher, requested "togglesplit" does not exist`
- `config option <dwindle:pseudotile> does not exist`
- `invalid field type bordersize` / `floating:0: missing a value` on `windowrule` lines
- `windowrulev2 is deprecated` — triggers Hyprland's on-screen error overlay

**Root cause:** Hyprland 0.55 favours Lua config. `windowrulev2` still works
but Hyprland 0.55 treats the deprecation as a config error, showing an error
overlay that takes up screen real estate.

Three specific breakages:

1. **`togglesplit` dispatcher removed** — no longer available in 0.55. The
   keybinding `$mainMod, t, togglesplit,` produces an error.

2. **`dwindle:pseudotile` removed** — the option no longer exists.

3. **`windowrulev2` deprecated** — the keyword still works, but using it in
   a sourced config file produces persistent config errors that trigger the
   on-screen error overlay. Dynamic `hyprctl keyword` calls also produce the
   deprecation message on stdout but do NOT register as config errors.

**Fix (3 changes):**

1. **Removed `togglesplit` keybind** from `home/features/desktop/hyprland.nix`.

2. **Removed `dwindle.pseudotile`** from `home/features/desktop/hyprland.nix`.

3. **Removed `source = ~/.config/hypr/window-rules.conf`** — the raw
   `windowrulev2 = …` lines were being parsed as config errors, triggering
   the on-screen error overlay. Rules are now defined inline in the Nix
   config's `exec-once` list. The home-manager hyprland module detects
   `windowrulev2` strings and converts them to `windowrule=` entries in the
   generated config — which Hyprland 0.55.2 accepts without triggering the
   deprecation error (unlike raw `windowrulev2 =` lines).

**Result:** `hyprctl configerrors` returns empty — no errors, no on-screen
error overlay. The home-manager module handles the `windowrulev2` →
`windowrule` conversion automatically when rules are specified inline rather
than in a separately sourced file.

**How to verify:**
```bash
hyprctl configerrors
# Should return empty (no output)
```
