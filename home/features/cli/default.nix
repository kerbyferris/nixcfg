{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    ghostscript
    imagemagick
    moc
    neofetch
    nix-index
    probe-rs-tools
    tldr
    yt-dlp

    # git
    # nodejs
    # go
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

  programs.btop = {
    enable = true;
    settings = {
      theme_background = true;
      vim_keys = true;
      shown_boxes = "proc cpu mem net gpu0 gpu1";
    };
  };

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

  programs.git = {
    enable = true;
    userName = "Kerby Ferris";
    userEmail = "kerbyferris@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    shortcut = "u";
    historyLimit = 100000;
    escapeTime = 10;
    baseIndex = 1;
    clock24 = true;
    customPaneNavigationAndResize = true;
    extraConfig = "
      set -g status-bg '#333333'\n
      set -g status-fg white\n
      set -g status-right '#(echo $USER) @ #H '\n
      bind h select-pane -L\n
      bind j select-pane -D\n
      bind k select-pane -U\n
      bind l select-pane -R\n
      bind-key -r C-h select-window -t :-\n
      bind-key -r C-l select-window -t :+\n
      setw -g mode-keys vi
      ";
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      biqu = {
        hostname = "192.168.1.13";
        user = "biqu";
      };
    };
    addKeysToAgent = "yes";
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
      up = "ping 8.8.8.8";
      myip = "curl -s https://icanhazip.com";
      ls = "eza";
      grep = "rg";
      ps = "procs";
      clean = "nix-collect-garbage -d";
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
