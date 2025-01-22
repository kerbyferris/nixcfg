{pkgs, ...}: {
  imports = [
    # ./waybar.nix
    ./hyprland.nix
  ];
  home.packages = with pkgs; [
    xfce.thunar
    blueman
    google-chrome
    waybar
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
    rofi
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
    pywal16
  ];
}
