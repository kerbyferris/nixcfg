{pkgs, ...}: {
  imports = [
  ./zsh.nix
  ];
  home.packages = with pkgs; [
    coreutils
    fd
    htop
    btop
    file
    jq
    tree
    procs
    ripgrep
    tldr
    zip
    killall
    pciutils
  ];

  programs.ghostty = {
    enable = true;
    settings = {
      # theme = "zenburned";
      # fullscreen = true;
      window-decoration = false;
      font-size=12;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    extraOptions = ["-l" "--icons" "--git" "-a"];
  };

  programs.bat.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--preview='bat --color=always -n {}'"
      "--bind 'ctrl-/:toggle-preview'"
    ];
    defaultCommand = "fd --type f --exclude .git --follow --hidden";
    changeDirWidgetCommand = "fd --type d --exclude .git --follow --hidden";
  };
}
