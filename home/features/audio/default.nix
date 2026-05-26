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
      # bitwig-studio6
      bitwig-fhs
      vcv-rack
    ];

    # Create the symlink for the main VST plugin
    home.file.".vst/VidPlayVSTv2.so" = {
      source = "${pkgs.vidplayvst}/lib/vst/VidPlayVSTv2.so";
      executable = true;
    };

    # Create the symlink for the second VST plugin
    home.file.".vst/VidRenderVSTv1.so" = {
      source = "${pkgs.vidplayvst}/lib/vst/VidRenderVSTv1.so";
      executable = true;
    };

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
