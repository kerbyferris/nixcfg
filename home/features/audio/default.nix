{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.audio;
in {
  options.features.audio.enable = mkEnableOption "enable audio production config";
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      bitwig-studio
      vcv-rack
    ];
    xdg.configFile = {
      "pipewire/pipewire.conf.d/10-virtual-sinks.conf".source = ./pipewire/pipewire.conf.d/10-virtual-sinks.conf;
    };
    programs.zsh = {
      shellAliases = {
        vcvrack = "env -u WAYLAND_DISPLAY Rack";
      };
    };
  };
}
