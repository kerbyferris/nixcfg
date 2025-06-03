{config, ...}: {
  imports = [
    ../common
    ../features/cli
    # ../features/desktop
    ./home.nix
  ];

  features = {
    cli = {
      zsh.enable = true;
    };
  };
}
