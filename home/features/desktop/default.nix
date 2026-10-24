{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hyprland.nix
  ];
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "x-scheme-handler/sgnl" = "signal.desktop";
      "x-scheme-handler/signalcaptcha" = "signal.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
      "application/pdf" = "zen-beta.desktop";
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "audio/x-wav" = "vlc.desktop";
      "audio/wav" = "vlc.desktop";
      "audio/vnd.wave" = "vlc.desktop";
      "audio/x-pn-wav" = "vlc.desktop";
    };
    associations.added = {
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "application/pdf" = [
        "org.gnome.Papers.desktop"
        "org.gnome.Evince.desktop"
        "zen-beta.desktop"
      ];
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
    };
  };

  # Thunar forced onto X11 (GDK_BACKEND=x11). Rationale: ArtCraft's winit-based
  # apps implement native file drag-and-drop only in winit's X11 backend, and
  # Hyprland does not reliably relay a *Wayland* drag onto an XWayland target
  # (hyprwm/Hyprland#7644), so dropping from Nautilus does nothing. An X11 drag
  # source never involves the compositor: plain XDND between two X11 clients.
  # Nautilus stays on Wayland for everything else — use Thunar when dragging
  # into an ArtCraft app.
  xdg.desktopEntries."thunar" = {
    name = "Thunar File Manager";
    genericName = "File Manager";
    comment = "Browse the filesystem with the file manager";
    exec = "env GDK_BACKEND=x11 thunar %U";
    icon = "org.xfce.thunar";
    terminal = false;
    categories = ["System" "Core" "GTK" "FileTools" "FileManager"];
    mimeType = ["inode/directory"];
    actions = {
      open-home = {
        name = "Home";
        exec = "env GDK_BACKEND=x11 thunar %U";
      };
      open-computer = {
        name = "Computer";
        exec = "env GDK_BACKEND=x11 thunar computer:///";
      };
      open-trash = {
        name = "Trash";
        exec = "env GDK_BACKEND=x11 thunar trash:///";
      };
    };
  };

  # Thunar owns these D-Bus names. Without the env var here a D-Bus-activated
  # instance would come up on Wayland and then swallow later menu launches via
  # GApplication single-instance, silently undoing the X11 source above.
  xdg.dataFile = {
    "dbus-1/services/org.xfce.Thunar.service".text = ''
      [D-BUS Service]
      Name=org.xfce.Thunar
      Exec=env GDK_BACKEND=x11 ${pkgs.thunar}/bin/Thunar --gapplication-service
    '';
    "dbus-1/services/org.xfce.FileManager.service".text = ''
      [D-BUS Service]
      Name=org.xfce.FileManager
      Exec=env GDK_BACKEND=x11 ${pkgs.thunar}/bin/Thunar --gapplication-service
    '';
    "dbus-1/services/org.freedesktop.FileManager1.service".text = ''
      [D-BUS Service]
      Name=org.freedesktop.FileManager1
      Exec=env GDK_BACKEND=x11 ${pkgs.thunar}/bin/Thunar --gapplication-service
    '';
  };

  home.packages = with pkgs; [
    affine
    android-tools
    anytype
    arduino-cli # headless builds against the esp32 core; nixpkgs wraps it in bwrap so the downloaded xtensa/riscv toolchains run on NixOS
    arduino-ide
    bambu-studio # replaces Flatpak version which crashes on NixOS (glycin sandbox DBus issue)
    brave
    blender
    # bottles
    # calibre
    clickup
    code-cursor
    cursor-cli
    discord
    distrobox
    dropbox
    esptool
    fstl
    m5burner # M5Stack firmware flasher — see pkgs/m5burner.nix
    llm-agents.dsh
    google-chrome
    hydrus
    kew
    lmstudio
    logseq # 2.0.2 "DB version" — overlay overrides nixpkgs' EOL-electron 0.10.15 (pkgs/logseq.nix)
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
    protonmail-bridge # IMAP/SMTP bridge for Proton Mail (included in the paid Proton plan); needed for any desktop client
    prusa-slicer
    qbittorrent
    quickemu
    refern # Eagle alternative — AppImage wrapped in flake (pkgs/refern.nix)
    rpi-imager
    signal-desktop
    steam-run
    syncthing
    telegram-desktop
    thunar # X11-forced file manager — see the desktop entry comment above
    thunderbird # mail hub for Proton (via Bridge) + Gmail (OAuth2)
    # tidal-hifi
    # todoist-electron
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

  # Proton Mail Bridge, headless. nixpkgs builds it without the Qt frontend, so
  # `protonmail-bridge` on its own dies with "no frontend specified"; --noninteractive
  # is the daemon mode. It serves IMAP/SMTP on 127.0.0.1 only (1143/1025, STARTTLS,
  # self-signed cert), which is what Thunderbird connects to — Bridge does the
  # decryption locally, so mail is never decrypted outside this machine.
  # The account credential lives in the keyring, hence the ordering against
  # gnome-keyring-unlock; without that it cannot start until the keyring is open.
  # If you exit an interactive `protonmail-bridge --cli` and this unit is already
  # failed, `systemctl --user start protonmail-bridge` picks up the free lock.
  systemd.user.services.protonmail-bridge = {
    Unit = {
      Description = "Proton Mail Bridge (headless IMAP/SMTP bridge)";
      After = ["graphical-session.target" "gnome-keyring-unlock.service"];
      Wants = ["gnome-keyring-unlock.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive";
      # "always", not "on-failure": when an interactive `protonmail-bridge --cli`
      # already holds the data-dir lock, Bridge exits 0 (after logging "another
      # instance is running"), so on-failure would never retry and the daemon
      # would stay dead after you simply close the CLI. always retries until it
      # gets the lock, which is exactly the handover we want.
      Restart = "always";
      RestartSec = 30;
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
