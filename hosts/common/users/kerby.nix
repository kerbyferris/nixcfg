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
      "input"
      "kvm"
      "libvirtd"
      "networkmanager"
      "plugdev"
      "qemu-libvirtd"
      "video"
      "wheel"
    ];
    packages = [inputs.home-manager.packages.${pkgs.system}.default];
  };
  home-manager.users.kerby =
    import ../../../home/kerby/${config.networking.hostName}.nix;
}
