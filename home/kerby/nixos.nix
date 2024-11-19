{ config, ... }: {
  imports = [
    ../common
    ../features/cli
    ../features/desktop
    ./home.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
    };
    desktop = {
      hyprland.enable = true;
      wayland.enable = true;
    };
  };

  wayland.windowManager.hyprland = {
    settings = {
      device = [
        {
          name = "keyboard";
          kb_layout = "us";
        }
        {
          name = "mouse";
          sensitivity = -0.5;
        }
      ];
    };
  };
}
