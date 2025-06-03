{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hyprland.nix
  ];
  home.packages = with pkgs; [
    bitwig-studio
    blender
    # bottles
    # cura
    discord
    dropbox
    fstl
    google-chrome
    kew
    morgen
    nix-index
    nordic
    nwg-look
    obs-studio
    obsidian
    openocd
    openscad
    # orca-slicer
    pavucontrol
    prusa-slicer
    qbittorrent
    signal-desktop
    tidal-hifi
    todoist-electron
    vital
    vlc
    # wineWowPackages.unstableFull
    # winetricks
    zoom-us
  ];
}
