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
    pciutils
    bottles
    pavucontrol
    # pywal16
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
