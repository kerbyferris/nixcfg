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
      build = "sudo nixos-rebuild switch --flake .#nixos";
      eagle = "wine64 ~/.wine/drive_c/Program\ Files/Eagle/Eagle.exe";
    };
  };
}
