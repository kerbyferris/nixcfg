{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    ghostscript
    imagemagick
    kubernetes
    fastfetch
    nix-index
    nmap
    nodejs
    probe-rs-tools
    tldr
    yt-dlp
    bun
  ];

  # programs.pi-coding-agent = {
  #   enable = true;
  #
  #   # package = inputs.pi-flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
  #
  #   mutableDir = true;
  #
  #   models = {
  #     providers = {
  #       my-provider = {
  #         # baseUrl = "https://api.openai.com/v1";
  #         # api = "openai-completions";
  #         # apiKey = "sk-...";
  #         # models = [{id = "gpt-4o";}];
  #       };
  #     };
  #   };
  #
  #   extensions = [
  #     "npm:pi-subagents"
  #   ];
  # };

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

  # programs.bash isn't enabled (user's default shell is zsh via oh-my-zsh),
  # but tmux may shell-out to bash — source agent-env there too.
  home.sessionVariablesExtra = ''
    # Source sops-managed env vars for all login shells
    if [ -r /run/secrets/agent-env ]; then
      set -a
      . /run/secrets/agent-env
      set +a
    fi
  '';

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
    changeDirWidget.command = "fd --type d --exclude .git --follow --hidden";
  };

  programs.git = {
    signing.format = null;
    enable = true;
    settings = {
      user = {
        name = "Kerby Ferris";
        email = "kerbyferris@gmail.com";
      };
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
      set -g default-terminal 'tmux-256color'
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
    enableDefaultConfig = false;
    settings = {
      pi = {
        hostname = "192.168.1.67";
        user = "pi";
      };
      biqu = {
        hostname = "192.168.1.13";
        user = "biqu";
      };
      hostinger = {
        hostname = "82.29.178.198";
        user = "root";
      };
      mac = {
        hostname = "192.168.1.89";
        user = "kerby";
      };
      pixel3xl = {
        hostname = "192.168.1.100";
        user = "u0_a235";
        port = 8022;
      };
      proxmox = {
        hostname = "192.168.1.200";
        user = "root";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    autosuggestion.highlight = "fg=#ff00ff,bg=cyan,bold,underline";
    loginExtra = "fastfetch";
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "nvm"
      ];
      theme = "robbyrussell"; # "bira" "pmcgee" "robbyrussel"
    };
    # Source sops-managed env vars (API keys, etc.) if available
    initContent = ''
      if [ -r /run/secrets/agent-env ]; then
        set -a
        . /run/secrets/agent-env
        set +a
      fi
    '';
    shellAliases = {
      up = "ping 8.8.8.8";
      myip = "curl -s https://icanhazip.com";
      ls = "eza";
      grep = "rg";
      ps = "procs";
      clean = "nix-collect-garbage -d";
      pixel-kbd-on = "adb shell pm enable com.android.inputmethod.latin";
      pixel-kbd-off = "adb shell pm disable-user --user 0 com.android.inputmethod.latin";
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      # fullscreen = true;
      window-decoration = false;
      font-size = 11;
      mouse-scroll-multiplier = 1;
      term = "xterm-256color";
    };
  };
  programs.kitty = {
    enable = true;
    font.size = lib.mkForce 11;
  };
}
