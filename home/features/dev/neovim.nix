{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.dev.neovim;
  in {
  options.features.dev.neovim.enable = mkEnableOption "enable neovim configuration";

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
    };
    home.packages = with pkgs; [
      gnumake
      unzip
      gcc
      ripgrep
      nerd-fonts.inconsolata
    ];
  };
}
