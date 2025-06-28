{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.freecad;
in {
  options.features.freecad.enable = mkEnableOption "enable freecad";

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (freecad-wayland.override {
        ifcSupport = true;
      })
    ];
  };
}
