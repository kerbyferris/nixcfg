#!/usr/bin/env bash
# RECOVER.SH — Post-reboot recovery & diagnostics for nixcfg
# Run this if: opencode not in PATH, monitor layout wrong, Waybar missing, mod key off
#
# USAGE: bash ~/nixcfg/bin/recover.sh
# Output goes to ~/nixcfg/bin/results.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/results.txt"

{
  echo "###############################################################################"
  echo "# RECOVER.SH — $(date)"
  echo "# Context: nixcfg commit $(git -C ~/nixcfg log --oneline -1)"
  echo "###############################################################################"
  echo ""

  # ── SECTION A: What generation are we on? ──────────────────────────────────

  echo "=== A0. Bootloader mismatch check (init= vs /run/current-system) ==="
  booted_init=$(cat /proc/cmdline | tr ' ' '\n' | grep '^init=' | sed 's/init=//')
  current_system=$(readlink -f /run/current-system 2>/dev/null || echo "FAILED")
  echo "Booted init  : $booted_init"
  echo "Current sys  : $current_system"
  if [ "$booted_init" != "$current_system/init" ]; then
    echo "*** MISMATCH *** Booted into OLD generation! Bootloader config is stale."
    echo "    See TROUBLESHOOTING.md Issue 6 (stale GRUB, systemd-boot not first)"
  else
    echo "OK — booted and current generation match"
  fi
  echo ""

  echo "=== A1. Booted NixOS generation ==="
  readlink -f /run/current-system || echo "FAILED"
  echo ""

  echo "=== A2. Nix store path for home-manager config ==="
  readlink -f ~/.config/systemd/user/hyprdynamicmonitors.service 2>/dev/null || echo "NOT FOUND (service unit missing from disk)"
  echo ""

  echo "=== A3. Home-manager activation log (this boot) ==="
  journalctl -u home-manager-kerby.service -b --no-pager 2>/dev/null || echo "FAILED"
  echo ""

  # ── SECTION B: Systemd user unit files on disk ─────────────────────────────

  echo "=== B1. hyprdynamicmonitors unit files ==="
  ls -la ~/.config/systemd/user/hyprdynamicmonitors* 2>&1 || echo "NOT FOUND"
  echo ""

  echo "=== B2. graphical-session-pre.target.wants ==="
  ls -la ~/.config/systemd/user/graphical-session-pre.target.wants/ 2>&1 || echo "DIRECTORY NOT FOUND"
  echo ""

  echo "=== B3. default.target.wants ==="
  ls -la ~/.config/systemd/user/default.target.wants/ 2>&1 || echo "DIRECTORY NOT FOUND"
  echo ""

  # ── SECTION C: Systemd daemon reload and service activation ────────────────

  echo "=== C1. Reloading user systemd daemon ==="
  if systemctl --user daemon-reload 2>&1; then
    echo "OK — daemon reloaded"
  else
    echo "FAILED — daemon reload failed (user session might not be running)"
  fi
  echo ""

  echo "=== C2. Service status after reload ==="
  systemctl --user status hyprdynamicmonitors-prepare.service 2>&1 || echo "(prepare service not active)"
  echo "---"
  systemctl --user status hyprdynamicmonitors.service 2>&1 || echo "(daemon service not active)"
  echo ""

  echo "=== C3. Starting services ==="
  systemctl --user start hyprdynamicmonitors-prepare.service 2>&1 || echo "prepare start FAILED"
  sleep 1
  systemctl --user start hyprdynamicmonitors.service 2>&1 || echo "daemon start FAILED"
  sleep 2
  echo ""

  echo "=== C4. Service status after start ==="
  systemctl --user status hyprdynamicmonitors-prepare.service 2>&1 || echo "(prepare not found/running)"
  echo "---"
  systemctl --user status hyprdynamicmonitors.service 2>&1 || echo "(daemon not found/running)"
  echo ""

  echo "=== C5. HyprDynamicMonitors daemon log ==="
  journalctl --user -u hyprdynamicmonitors.service --since "1 min ago" --no-pager 2>&1 || echo "NO LOGS"
  echo ""

  # ── SECTION D: Monitor config ─────────────────────────────────────────────

  echo "=== D1. monitors.conf existence ==="
  if [ -f ~/.config/hypr/monitors.conf ]; then
    echo "EXISTS — content below:"
    cat ~/.config/hypr/monitors.conf
  else
    echo "NOT FOUND — HyprDynamicMonitors daemon did not write monitors.conf"
  fi
  echo ""

  echo "=== D2. hyprctl monitors ==="
  hyprctl monitors 2>&1 || echo "hyprctl FAILED (Hyprland not running or not on Wayland)"
  echo ""

  echo "=== D3. hyprdynamicmonitors config dir ==="
  ls -laR ~/.config/hyprdynamicmonitors/ 2>&1 || echo "DIR NOT FOUND"
  echo ""

  # ── SECTION E: Hyprland config correctness ─────────────────────────────────

  echo "=== E1. Hyprland conf symlink target ==="
  readlink -f ~/.config/hypr/hyprland.conf 2>/dev/null || echo "NOT FOUND"
  echo ""

  echo "=== E2. Mod key (should be ALT) ==="
  grep '^\$mainMod' ~/.config/hypr/hyprland.conf 2>/dev/null || echo "NOT FOUND (generation stale?)"
  echo ""

  echo "=== E3. Hyprland source directive ==="
  grep 'source.*monitors' ~/.config/hypr/hyprland.conf 2>/dev/null || echo "No source directive (expected)"
  echo ""

  # ── SECTION F: Waybar ──────────────────────────────────────────────────────

  echo "=== F1. Waybar process ==="
  ps -eo pid,comm | grep waybar 2>&1 || echo "waybar not running"
  echo ""

  echo "=== F2. Waybar restart (kill old, systemd picks up new) ==="
  pkill '\.waybar-wrapp' 2>/dev/null && echo "Killed old waybar" || echo "No waybar to kill"
  echo ""

  # ── SECTION G: Shell environment ───────────────────────────────────────────

  echo "=== G1. PATH ==="
  echo "$PATH"
  echo ""

  echo "=== G2. opencode ==="
  which opencode 2>&1 || echo "NOT FOUND — profile not updated?"
  echo ""

  echo "=== G3. D-Bus session bus ==="
  systemctl --user status dbus.service 2>&1 | head -6 || echo "dbus FAILED"
  echo ""

  # ── SECTION H: Summary / next steps ────────────────────────────────────────

  echo "###############################################################################"
  echo "# DIAGNOSTICS COMPLETE"
  echo "#"
  echo "# Common root causes & fixes:"
  echo "#"
  echo "# 1. Unit files missing on disk → activation didn't complete or old generation booted"
  echo "#    Fix: rebuild with 'sudo nixos-rebuild switch --flake ~/nixcfg#nixos --impure'"
  echo "#"
  echo "# 2. Unit files exist but services not active → systemd daemon not reloaded"
  echo "#    Fix: this script already ran daemon-reload + start above"
  echo "#"
  echo "# 3. monitors.conf missing → daemon didn't run or DP-1 not detected yet"
  echo "#    Fix: wait 10-30 seconds, then check again. Cold-boot GPU race is normal."
  echo "#"
  echo "# 4. mainMod != ALT → stale Hyprland generation"
  echo "#    Fix: rebuild (see 1), or 'hyprctl reload' if monitors.conf exists"
  echo "#"
  echo "# 5. opencode not found → home-manager profile not linked"
  echo "#    Fix: verify 'systemctl status home-manager-kerby.service' succeeded"
  echo "###############################################################################"
  echo ""
  echo "=== RAW CPU INFO (for GPU/DRM context) ==="
  cat /proc/cpuinfo | head -5 2>/dev/null || echo "N/A"
  echo ""

  echo "=== DRM CONNECTORS ==="
  for p in /sys/class/drm/card*-*/status; do
    echo "$p: $(cat "$p" 2>/dev/null || echo 'N/A')"
  done
  echo ""

  echo "=== RECOVER.SH FINISHED — $(date) ==="
} > "$OUTPUT" 2>&1

echo "Results written to $OUTPUT"
cat "$OUTPUT"
