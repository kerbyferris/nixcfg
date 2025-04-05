{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.features.cli.zsh;
in {
  options.features.cli.zsh.enable = mkEnableOption "enable extended zsh configuration";

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
      loginExtra = "neofetch";
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "nvm"
        ];
        theme = "robbyrussell"; # "bira" "pmcgee" "robbyrussel"
      };
      shellAliases = {
        build = "sudo nixos-rebuild switch --flake .";
        homebuild = "home-manager switch --flake .";
        up = "ping 8.8.8.8";
        myip = "curl -s https://icanhazip.com";
        ls = "eza";
        grep = "rg";
        ps = "procs";
        nvim-backup = "NVIM_APPNAME=\"nvim-backup\" nvim";
        edit = "nix run github:kerbyferris/kickstart.nixvim";
      };
    };
  };
}
