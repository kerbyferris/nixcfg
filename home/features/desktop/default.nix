{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hyprland.nix
  ];
  home.packages = with pkgs; [
    android-tools
    arduino-ide
    bambu-studio # replaces Flatpak version which crashes on NixOS (glycin sandbox DBus issue)
    brave
    blender
    # bottles
    calibre
    clickup
    code-cursor
    cursor-cli
    discord
    distrobox
    dropbox
    esptool
    fstl
    llm-agents.dsh
    google-chrome
    hydrus
    kew
    lmstudio
    nwg-look
    obs-studio
    obsidian
    # llm-agents.pi
    llm-agents.omp
    # llm-agents.hermes-desktop
    ollama
    openai-whisper
    openocd
    # openscad
    # orca-slicer # via Flatpak — nixpkg links webkitgtk 2.52 which crashes the Device tab; Flatpak runtime ships a working webkitgtk
    pavucontrol
    pdfarranger
    prusa-slicer
    qbittorrent
    quickemu
    rpi-imager
    signal-desktop
    steam-run
    syncthing
    telegram-desktop
    # tidal-hifi
    todoist-electron
    upower
    vital
    vlc
    inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default # beta
    # inputs.tagstudio.packages."${system}".default
    zoom-us
  ];

  programs.vscode = {
    # enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        marus25.cortex-debug
        vscodevim.vim
        ms-vscode.cpptools-extension-pack
        ms-vscode.makefile-tools
        # TODO: (why can't we have nice things?)
        # platformio.platformio-ide
        # probe-rs.probe-rs-debugger
      ];
      userSettings = {
        "vim.normalModeKeyBindings" = [
          {
            "before" = [";"];
            "after" = [":"];
          }
        ];
        "vim.insertModeKeyBindings" = [
          {
            "before" = ["j" "j"];
            "after" = ["<esc>"];
          }
        ];
        "git.openRepositoryInParentFolders" = "always";
      };
    };
  };
  # Auto-unlock the login keyring with an empty password for auto-login setups.
  # Without this, Chromium-based browsers (Brave, Chrome) prompt for a keyring
  # password on every launch because PAM can't pass a login password during
  # auto-login.
  systemd.user.services.gnome-keyring-unlock = {
    Unit = {
      Description = "Unlock GNOME keyring with empty password for auto-login";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"\" | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --replace --daemonize --unlock'";
      RemainAfterExit = true;
      KillMode = "process";
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
