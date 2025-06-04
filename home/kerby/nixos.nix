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
}
