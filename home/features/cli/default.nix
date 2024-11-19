{pkgs, ...}: {
  imports = [
  ./zsh.nix
  ];
  home.packages = with pkgs; [
    coreutils
    fd
    htop
    btop
    httpie
    jq
    tree
    procs
    ripgrep
    tldr
    zip
  ];

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
