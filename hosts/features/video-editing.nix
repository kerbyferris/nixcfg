{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.video-editing;
in {
  options.features.video-editing.enable = mkEnableOption "enable video-editing config";

  config = mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
    };

    environment.systemPackages = with pkgs; [
      kdePackages.kdenlive
      wineWowPackages.stableFull
      davinci-resolve
      clinfo
    ];
  };
}
