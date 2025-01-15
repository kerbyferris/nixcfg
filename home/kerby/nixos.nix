{ config, ... }: {
  imports = [
    ../common
#    ./dotfiles
    ../features/cli
    ../features/desktop
    ../features/dev
    ./home.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
    };
    # desktop = {
    #   hyprland.enable = true;
    #   wayland.enable = true;
    # };
    dev = {
      neovim.enable = true;
    };
  };

  # wayland.windowManager.hyprland = {
  #   settings = {
  #     device = [
  #       {
  #         name = "keyboard";
  #         kb_layout = "us";
  #       }
  #       {
  #         name = "mouse";
  #         sensitivity = -0.5;
  #       }
  #     ];
  #   };
  # };
}
