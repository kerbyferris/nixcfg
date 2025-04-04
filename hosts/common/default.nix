# Common configuration for all hosts
{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
    ./neovim
    ./users
    inputs.home-manager.nixosModules.home-manager
    inputs.nixvim.nixosModules.nixvim
  ];
  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs outputs;};
  };
  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.stable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  nix = {
    settings = {
      trusted-users = [
        "root"
        "kerby"
      ]; # Set users that are allowed to use the flake command
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 10d";
    };
    optimise.automatic = true;
    registry =
      (lib.mapAttrs (_: flake: {inherit flake;}))
      ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    #nixPath = [ "/etc/nix/path" ];
  };
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
}
