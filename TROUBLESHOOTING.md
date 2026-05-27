# Troubleshooting Reference (2026-05-27)

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

**Root cause:** hyprdynamicmonitors daemon was ordered `After=graphical-session.target`,
meaning it started AFTER Hyprland already read `monitors.conf`. Meanwhile the
`prepare` service removes `monitor = …,disable` lines before Hyprland starts.

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

**Fix (2 changes):**
1. `home/features/desktop/hyprland.nix` — overrode daemon systemd unit:
   - `Before=graphical-session-pre.target` (was `After=graphical-session.target`)
   - `WantedBy=graphical-session-pre.target` (was `graphical-session.target`)
   - Removed `Requires=graphical-session.target`
2. `home/features/desktop/hyprdynamicmonitors/config.toml` — post_apply_exec:
   ```
   until hyprctl monitors >/dev/null 2>&1; do sleep 0.5; done; hyprctl reload
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

**Symptom:** After `nixos-rebuild switch`, waybar keeps running from old Nix
store path. Manual restart via `Alt+Shift+B` is needed.

**Root cause:** `pkill` in HM activation wasn't in PATH (procps not in
activation environment) and `2>/dev/null` hid the failure. Also launch
script used `pkill -f '\.waybar-wrapped$'` but the cmdline is just `waybar`,
not `.waybar-wrapped`. The process name (comm) IS `.waybar-wrapped` but `-f` 
matches cmdline, not comm.

**Fix:**
1. `home/kerby/home.nix` — activation uses `${pkgs.procps}/bin/pkill -u $USER '\.waybar-wrapp'`
2. `home/features/desktop/waybar/launch.sh` — uses `pkill '\.waybar-wrapp'` (match comm, not cmdline)

**Manual restart:**
```bash
pkill '\.waybar-wrapp'
# or press Alt+Shift+B
```

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
