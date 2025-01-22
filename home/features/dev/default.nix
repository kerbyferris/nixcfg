{pkgs, ...}: {
  imports = [
    # ./neovim.nix
  ];

  home.packages = with pkgs; [
    git
    nodejs
    go
    nvim
  ];
}
