{pkgs, lib, ...}: {
  home.packages = with pkgs; [
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
    probe-rs-tools
    zoom-us
    vlc
    moc
    openscad
    signal-desktop
    qbittorrent
    vital
    morgen
    youtube-music
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
