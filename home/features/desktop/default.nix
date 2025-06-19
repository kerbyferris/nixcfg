{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hyprland.nix
  ];
  home.packages = with pkgs; [
    bitwig-studio
    blender
    # bottles
    # cura
    discord
    dropbox
    fstl
    google-chrome
    kew
    morgen
    nordic
    nwg-look
    obs-studio
    obsidian
    openocd
    openscad
    # orca-slicer
    pavucontrol
    prusa-slicer
    qbittorrent
    rpi-imager
    signal-desktop
    tidal-hifi
    todoist-electron
    vital
    vlc
    inputs.zen-browser.packages."${system}".default # beta
    zoom-us
  ];

  programs.vscode = {
    enable = true;
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
