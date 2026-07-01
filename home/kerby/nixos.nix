{...}: {
  imports = [
    ../common
    ../features/pi-agent
    ../features/audio
    ../features/cli
    ../features/desktop
    ./home.nix
  ];

  features = {
    audio.enable = true;
    desktop = {
      hyprland.enable = true;
    };
  };

  # Browser-workaround launcher for the Voron 0.1 (Klipper/Moonraker at
  # 192.168.1.13): OrcaSlicer's in-app Device tab crashes (webkitgtk 2.50+
  # AcceleratedBackingStore bug), so live control goes through Mainsail in the
  # browser. G-code upload is done from OrcaSlicer via its Moonraker print-host.
  home.file.".local/share/applications/mainsail-voron.desktop".text = ''
    [Desktop Entry]
    Name=Voron 0.1 (Mainsail)
    Comment=Klipper/Moonraker live control
    Exec=xdg-open http://192.168.1.13
    Icon=printer
    Terminal=false
    Type=Application
    Categories=Utility;
  '';

  programs.zsh = {
    shellAliases = {
      update = "nix-flake-update";
      build = "sudo nixos-rebuild switch --flake .#nixos";
    };
  };
}
