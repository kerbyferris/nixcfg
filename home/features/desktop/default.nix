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
    distrobox
    dropbox
    esptool
    fstl
    llm-agents.gemini-cli
    llm-agents.claude-code
    google-chrome
    hydrus
    kew
    lmstudio
    nordic
    nwg-look
    obs-studio
    obsidian
    llm-agents.pi
    llm-agents.omp
    ollama
    openai-whisper
    llm-agents.opencode
    openocd
    openscad
    orca-slicer # using flatpak until the webgtk issue is sorted
    pavucontrol
    pdfarranger
    prusa-slicer
    qbittorrent
    quickemu
    rpi-imager
    signal-desktop
    steam-run
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
}
