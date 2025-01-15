{pkgs, ...}: {
  imports = [
    # ./waybar.nix
    # ./hyprland.nix
  ];
  home.packages = with pkgs; [
    google-chrome
    waybar
    libnotify
    dolphin
    swww
    kitty
    rofi-wayland
    networkmanagerapplet
    discord
    wofi
    bitwig-studio
    vital
    morgen
    youtube-music
    dropbox
    xwayland
    wineWowPackages.full
    winetricks
    davinci-resolve
    # intel-ocl
    pciutils
    bottles
  ];
}
      
