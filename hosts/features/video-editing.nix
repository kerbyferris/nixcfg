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
        ovmf.packages = [pkgs.OVMFFull.fd];
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
      wineWowPackages.stableFull
      davinci-resolve
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
      # quickemu
    ];
  };
}
