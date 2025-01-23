{pkgs, lib, ...}: {
  home.packages = with pkgs; [
    nautilus
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
    # wofi
    bitwig-studio
    vital
    morgen
    youtube-music
    dropbox
    xwayland
    wineWowPackages.full
    winetricks
    davinci-resolve
    pciutils
    bottles
    # pywal16
  ];
  programs.rofi = {
    enable = true;
    theme = lib.mkDefault "gruvbox-dark-soft";
  };
}
