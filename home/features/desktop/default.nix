{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hyprland.nix
  ];
  home.packages = with pkgs; [
    # gcc-arm-embedded-9
    dfu-util
    gnumake
    openocd
    nix-index
    nautilus
    fstl
    blueman
    google-chrome
    nwg-look
    libnotify
    nordic
    swww
    swaynotificationcenter
    kitty
    hyprshot
    brightnessctl
    hypridle
    networkmanagerapplet
    discord
    bitwig-studio
    blender
    todoist-electron
    imagemagick
    ghostscript
    obsidian
    probe-rs-tools
    obs-studio
    zoom-us
    vlc
    usbutils
    moc
    openscad
    tidal-hifi
    signal-desktop
    qbittorrent
    vital
    morgen
    kew
    dropbox
    xwayland
    # wineWowPackages.unstableFull
    # winetricks
    pciutils
    # bottles
    pavucontrol
    # orca-slicer
    prusa-slicer
    yt-dlp
    # cura
  ];
}
