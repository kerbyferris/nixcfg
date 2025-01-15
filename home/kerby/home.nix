# This is a default home.nix generated by the follwing hone-manager command
# 
# home-manager init ./

{ config, lib, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = lib.mkDefault "kerby";
  home.homeDirectory = lib.mkDefault "/home/${config.home.username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  dconf.settings = {
    "org/gnome/desktop/peripherals/mouse" = { natural-scroll = true; };
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    neofetch
    alejandra
    nerd-fonts.inconsolata

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];
  home.file.".icons/default".source = "${pkgs.vanilla-dmz}/share/icons/Vanilla-DMZ";

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
    #".config/nvim".source = dotfiles/nvim;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/m3tam3re/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
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
  };

  systemd.user.services.dropbox = {
      Unit = {
          Description = "Dropbox service";
      };
      Install = {
          WantedBy = [ "default.target" ];
      };
      Service = {
          ExecStart = "${pkgs.dropbox}/bin/dropbox";
          Restart = "on-failure";
      };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
