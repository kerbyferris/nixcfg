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
      "wheel"
      "networkmanager"
      "libvirtd"
      "flatpak"
      "audio"
      "video"
      "plugdev"
      "input"
      "kvm"
      "qemu-libvirtd"
    ];
    packages = [ inputs.home-manager.packages.${pkgs.system}.default ];
  };
  home-manager.users.kerby =
    import ../../../home/kerby/${config.networking.hostName}.nix;
}
