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
      bitwig-studio6
      # vcv-rack # broken in current nixpkgs: patch URL 404s
    ];

    xdg.desktopEntries."com.bitwig.BitwigStudio" = {
      name = "Bitwig Studio";
      genericName = "Digital Audio Workstation";
      comment = "Modern music production and performance";
      exec = "bitwig-studio-fhs-env";
      icon = "com.bitwig.BitwigStudio";
      terminal = false;
      type = "Application";
      categories = ["AudioVideo" "Music" "Audio" "Sequencer" "Midi" "Mixer" "Player" "Recorder"];
      mimeType = [
        "application/bitwig-clip"
        "application/bitwig-device"
        "application/bitwig-package"
        "application/bitwig-preset"
        "application/bitwig-project"
        "application/bitwig-scene"
        "application/bitwig-template"
        "application/bitwig-extension"
        "application/bitwig-remote-controls"
        "application/bitwig-module"
        "application/bitwig-modulator"
        "application/vnd.bitwig.dawproject"
      ];
      settings = {
        Keywords = "daw;bitwig;audio;midi";
        StartupNotify = "true";
        StartupWMClass = "com.bitwig.BitwigStudio";
        DBusActivatable = "false";
      };
    };

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
