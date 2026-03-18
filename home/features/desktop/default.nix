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
    # bambu-studio # network plugin woes
    blender
    # bottles
    # calibre
    clickup
    code-cursor
    cursor-cli
    discord
    dropbox
    esptool
    fstl
    gemini-cli
    claude-code
    google-chrome
    kew
    lmstudio
    morgen
    nordic
    nwg-look
    obs-studio
    obsidian
    opencode
    openocd
    openscad
    orca-slicer # using flatpak until the webgtk issue is sorted
    pavucontrol
    prusa-slicer
    qbittorrent
    quickemu
    rpi-imager
    signal-desktop
    telegram-desktop
    # tidal-hifi
    todoist-electron
    vital
    vlc
    inputs.zen-browser.packages."${system}".default # beta
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
}
