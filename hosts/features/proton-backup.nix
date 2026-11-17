{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.proton-backup;

  # `proton drive items upload` has no incremental mode (see the script header),
  # so the change detection lives in bin/proton-drive-backup.py. Wrapping it in
  # writeShellApplication pins python3 and proton-cli into the unit's PATH, which
  # a bare repo-path ExecStart would not do.
  backup = pkgs.writeShellApplication {
    name = "proton-drive-backup";
    runtimeInputs = [pkgs.python3 pkgs.proton-cli];
    text = ''
      exec python3 ${../../bin/proton-drive-backup.py} "$@"
    '';
  };
in {
  options.features.proton-backup = {
    enable = mkEnableOption "incremental nightly mirror of /data/proton-drive into Proton Drive";

    remote = mkOption {
      type = types.str;
      default = "/Backups/proton-drive";
      description = "Destination folder in Proton Drive (created if missing).";
    };

    onCalendar = mkOption {
      type = types.str;
      default = "*-*-* 04:30:00";
      description = "systemd timer calendar spec for the incremental run.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments passed to proton-drive-backup.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [backup];

    systemd.services.proton-drive-backup = {
      description = "Incremental mirror of /data/proton-drive into Proton Drive";
      wants = ["network-online.target"];
      after = ["network-online.target"];

      # A rebuild must not touch a run that is in flight: the unit file changes
      # on almost every nixpkgs bump (ExecStart embeds store paths), and killing
      # a half-done upload throws away hours of work. With X-RestartIfChanged=no
      # switch-to-configuration leaves it alone entirely.
      restartIfChanged = false;

      serviceConfig = {
        # NOT Type=oneshot. A oneshot's start job does not complete until the
        # whole run finishes, and switch-to-configuration starts units with a
        # blocking `systemctl start` — so activation would sit there for the
        # entire backup (hours), leaving the transient
        # `nixos-rebuild-switch-to-configuration` unit loaded. The next
        # `nixos-rebuild switch` then fails before doing anything with
        # "Unit nixos-rebuild-switch-to-configuration.service was already
        # loaded or has a fragment file". Type=exec makes the start job
        # complete as soon as the process is exec'd.
        Type = "exec";
        # Runs as kerby (not root) so proton-cli finds ~/.config/proton-cli/sessions.
        User = "kerby";
        Group = "users";
        Environment = ["HOME=/home/kerby"];
        ExecStart = "${backup}/bin/proton-drive-backup --remote ${
          escapeShellArgs ([cfg.remote] ++ cfg.extraArgs)
        }";
        # 133 GB over the home uplink takes hours on the first (seed) run, so
        # cap the run rather than the (now instantaneous) start job.
        RuntimeMaxSec = "24h";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.proton-drive-backup = {
      description = "Daily incremental Proton Drive backup";
      wantedBy = ["timers.target"];
      timerConfig = {
        Unit = "proton-drive-backup.service";
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
