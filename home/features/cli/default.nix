{pkgs, ...}: {
  imports = [
    ./zsh.nix
  ];
  home.packages = with pkgs; [
    ghostscript
    imagemagick
    moc
    probe-rs-tools
    tldr
    yt-dlp
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

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    loginExtra = "neofetch";
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "nvm"
      ];
      theme = "robbyrussell"; # "bira" "pmcgee" "robbyrussel"
    };
    shellAliases = {
      build = "sudo nixos-rebuild switch --flake .";
      homebuild = "home-manager switch --flake .";
      up = "ping 8.8.8.8";
      myip = "curl -s https://icanhazip.com";
      ls = "eza";
      grep = "rg";
      ps = "procs";
      nvim-backup = "NVIM_APPNAME=\"nvim-backup\" nvim";
      edit = "nix run github:kerbyferris/kickstart.nixvim";
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      # theme = "zenburned";
      # fullscreen = true;
      window-decoration = false;
      font-size = 11;
    };
  };
}
