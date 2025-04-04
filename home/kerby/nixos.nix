{config, ...}: {
  imports = [
    #    ./dotfiles
    ../common
    ../features/cli
    ../features/desktop
    ./home.nix
    # ./neovim.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
    };
  };
}
