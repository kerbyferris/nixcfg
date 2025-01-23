{ config, ... }: {
  imports = [
    ../common
#    ./dotfiles
    ../features/cli
    ../features/desktop
    ./home.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
    };
  };

}
