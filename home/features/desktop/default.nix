{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    gcc-arm-embedded-9
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
    imagemagick
    ghostscript
    obsidian
    vivaldi
    librewolf
    probe-rs-tools
    zoom-us
    vlc
    usbutils
    moc
    openscad
    tidal-hifi
    signal-desktop
    qbittorrent
    vital
    # morgen
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
  programs.rofi = {
    enable = true;
    theme = lib.mkDefault "gruvbox-dark-soft";

    extraConfig = {
      show-icons = true;
      display-drun = "application: ";
      drun-display-format = "{icon} {name}";
      icon-theme = "Papirus";
      terminal = "ghostty";
    };
  };
}
