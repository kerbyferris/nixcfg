{...}: {
  imports = [
    ../common
    ../features/cli
    ../features/desktop
    ./home.nix
  ];

  features = {
    desktop = {
      hyprland.enable = true;
    };
  };

  programs.zsh = {
    shellAliases = {
      build = "nixos-rebuild switch --flake .#nixos";
    };
  };
}
