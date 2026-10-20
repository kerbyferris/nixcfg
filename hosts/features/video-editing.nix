{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.video-editing;
in {
  options.features.video-editing.enable = mkEnableOption "enable video-editing config";

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
    };

    virtualisation.libvirtd = {
      enable = true;

      qemu = {
        swtpm.enable = true;
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    programs.dconf.enable = true;

    users.users.kerby.extraGroups = ["libvirtd" "kvm"];
    users.groups.libvirt.gid = 985;
    users.groups.qemu.gid = 986;

    users.users.libvirt-qemu = {
      group = "libvirt"; # Primary group
      extraGroups = ["qemu"]; # Add to 'qemu' group as well if needed
      # This user's home directory is typically not used, set it to a dummy path
      home = "/var/lib/libvirt";
      createHome = true;
      uid = 985; # Matching the GID is common for system users (can be different, but consistency is safe)
      description = "Libvirt QEMU daemon user";
    };

    services.udev.extraRules = ''
      # Rule to allow libvirt-qemu user to access USB devices
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="985"
      SUBSYSTEM=="usb_device", MODE="0664", GROUP="985"
    '';

    environment.systemPackages = with pkgs; [
      kdePackages.kdenlive
      wineWow64Packages.stable
      wine
      (wine.override {wineBuild = "wine64";})
      wine64
      wineWow64Packages.staging
      winetricks
      wineWow64Packages.waylandFull
      digikam
      clinfo
      wimlib
      parted
      ntfs3g
      gparted
      gnome-boxes
      dnsmasq
      phodav
      # virtualbox
      # qemu
      virt-manager
      (bottles.override {removeWarningPopup = true;})
      cifs-utils
      # quickemu
    ];

    # REMOVED 2026-10-11: fileSystems."/mnt/t7-shield" (CIFS -> //192.168.1.67/T7-Shield).
    # It was declared on 2026-06-15 for the era when the Raspberry Pi hosted a Samba share over
    # the T7 Shield. That drive was later reformatted and moved to Proxmox (it is now pve's
    # /mnt/t7-backup, btrfs UUID 5210d908-...), so the Pi had no T7 attached any more and the
    # share was exporting a plain empty directory on the Pi's own root filesystem. Losing its
    # backing disk is what made this mount a hollow, per-boot automount. The Pi-side [T7-Shield]
    # share was dropped at the same time. History: this is the share whose forced unmount
    # corrupted the T7 - see RULES.md "Storage Safety".

    # Mount T7 media workspace from Proxmox (RW) — GoPro originals, audio, projects, refern roots.
    # Renamed 2026-10-11 (editor-neutral: FilmCraft, not just Resolve): mountpoint was /mnt/davinci,
    # the Samba share was [davinci], and pve's host path was /mnt/t7-davinci. The backing btrfs
    # subvolume is @media-workspace (was @davinci-workspace).
    fileSystems."/mnt/media" = {
      device = "//192.168.1.200/media";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.templates."proxmox-samba-credentials".path}"
        "uid=1000"
        "gid=100"
        "iocharset=utf8"
        "nofail"
        "noatime"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=10"
      ];
    };

    # Mount T7 Immich data from Proxmox (RO) — Immich upload library, thumbs, encoded-video
    fileSystems."/mnt/immich-data" = {
      device = "//192.168.1.200/immich-data";
      fsType = "cifs";
      options = [
        "credentials=${config.sops.templates."proxmox-samba-credentials".path}"
        "uid=1000"
        "gid=100"
        "iocharset=utf8"
        "ro"
        "nofail"
        "noatime"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=10"
      ];
    };
  };
}
