{...}: {
  imports = [
    ../common
    ../features/audio
    ../features/cli
    ../features/desktop
    ./home.nix
  ];

  features = {
    audio.enable = true;
    desktop = {
      hyprland.enable = true;
    };
  };

  programs.zsh = {
    shellAliases = {
      update = "nix-flake-update";
      build = "sudo nixos-rebuild switch --flake .#nixos";
    };
  };
}
