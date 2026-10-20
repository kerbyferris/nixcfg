{
  config,
  pkgs,
  inputs,
  ...
}: {
  users.users.kerby = {
    isNormalUser = true;
    description = "Kerby Ferris";
    extraGroups = [
      "audio"
      "dialout"
      "flatpak"
      "hp"
      "input"
      "kvm"
      "libvirtd"
      "networkmanager"
      "plugdev"
      "qemu-libvirtd"
      "render"
      "video"
      "wheel"
    ];
    packages = [inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default];
  };
  # "plugdev" is referenced by the openocd udev rules (60-openocd.rules assigns
  # GROUP="plugdev" to FTDI/ATmega debug probes and to GPIO devices) and is listed
  # in kerby's extraGroups — but it was never declared here, so it did not exist
  # in /etc/group. Any device matched by those rules therefore ended up owned by
  # a nonexistent group with MODE=0660, i.e. unusable by the seated user.
  users.groups.plugdev = {};
  home-manager.users.kerby =
    import ../../../home/kerby/${config.networking.hostName}.nix;
}
