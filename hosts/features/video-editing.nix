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
      davinci-resolve
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

    # Mount T7 Shield from Hermes (Raspberry Pi) Samba share
    fileSystems."/mnt/t7-shield" = {
      device = "//192.168.1.67/T7-Shield";
      fsType = "cifs";
      options = [
        "guest"
        "uid=1000"
        "gid=100"
        "iocharset=utf8"
        "noexec"
        "nofail"
        "noatime"
        "_netdev"
        "x-systemd.automount"
        "x-systemd.idle-timeout=300"
      ];
    };
  };
}
