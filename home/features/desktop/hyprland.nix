{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.features.desktop.hyprland;
in {
  imports = [
    inputs.hyprdynamicmonitors.homeManagerModules.default
  ];

  options.features.desktop.hyprland.enable = mkEnableOption "enable hyprland config";

  config = mkIf cfg.enable {
    home.hyprdynamicmonitors = {
      enable = true;
      configFile = ./hyprdynamicmonitors/config.toml;
      extraFlags = ["--enable-lid-events"];
    };

    home.packages = with pkgs; [
      blueman # For blueman-applet
      brightnessctl # For brightness controls
      kitty
      libnotify
      ghostty # terminal
      hypridle
      hyprshot # For screenshot binds
      nautilus # Your file manager
      networkmanagerapplet # For nm-applet
      playerctl # For media key controls
      swaynotificationcenter # For swaync
      awww
      waybar
      wl-clipboard
      xwayland
    ];

    programs.rofi = {
      enable = true;
      theme = lib.mkDefault "gruvbox-dark-soft";

      extraConfig = {
        show-icons = true;
        display-drun = "application: ";
        drun-display-format = "{icon} {name}";
        icon-theme = "Papirus";
        terminal = "ghostty";
        # terminal = "kitty";
        font = "JetBrains Mono Nerd Font 11";
      };
    };

    # Manage other related configuration files
    # These will be symlinked into ~/.config/
    xdg.configFile = {
      "waybar/config".source = ./waybar/config.jsonc;
      "waybar/style.css".source = ./waybar/style.css;
      "waybar/launch.sh" = {
        source = ./waybar/launch.sh;
        executable = true;
      };
      "hyprdynamicmonitors/hyprconfigs/laptop-only.conf".source = ./hyprdynamicmonitors/hyprconfigs/laptop-only.conf;
      "hyprdynamicmonitors/hyprconfigs/dual-monitor.conf".source = ./hyprdynamicmonitors/hyprconfigs/dual-monitor.conf;
      "hyprdynamicmonitors/hyprconfigs/clamshell.conf".source = ./hyprdynamicmonitors/hyprconfigs/clamshell.conf;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang";

      settings = {
        # Hyprland's internal variables (defined with $ in hyprland.conf)
        "$mainMod" = "SUPER_L"; # Sets "Windows" key as main modifier
        "$terminal" = "ghostty";
        # "$terminal" = "kitty";
        "$fileManager" = "nautilus";
        "$menu" = "rofi -show drun --show-icons";

        # MONITORS
        # Managed by hyprdynamicmonitors
        source = "~/.config/hypr/monitors.conf";

        # XWAYLAND specific settings (from your xwayland {} block)
        xwayland = {
          force_zero_scaling = true;
        };

        # ENVIRONMENT VARIABLES (set within Hyprland's scope)
        # These are from your `env = ...` lines
        env = [
          "GDK_SCALE,0.66667" # Original was .66667, using 0. for clarity
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24" # This was duplicated in original, included once
          "WLR_NO_HARDWARE_CURSORS,1"
          "MOZ_ENABLE_WAYLAND, 1"
        ];

        # AUTOSTART
        "exec-once" = [
          "$terminal" # Hyprland will substitute its $terminal variable
          "nm-applet & blueman-applet"
          "~/.config/waybar/launch.sh & swaync"
        ];

        # LOOK AND FEEL
        general = {
          gaps_in = 2;
          gaps_out = 2;
          border_size = 0;
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 6;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          shadow = {
            # Corresponds to the shadow {} block
            enabled = false;
            range = 4;
            render_power = 3;
          };
        };

        animations = {
          enabled = true; # Original: "yes, please :)" - the "please :)" is a comment
          bezier = [
            "easeOutQuint,0.23,1,0.32,1"
            "easeInOutCubic,0.65,0.05,0.36,1"
            "linear,0,0,1,1"
            "almostLinear,0.5,0.5,0.75,1.0"
            "quick,0.15,0,0.1,1"
          ];
          animation = [
            "global, 1, 10, default"
            "border, 1, 5.39, easeOutQuint"
            "windows, 1, 4.79, easeOutQuint"
            "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
            "windowsOut, 1, 1.49, linear, popin 87%"
            "fadeIn, 1, 1.73, almostLinear"
            "fadeOut, 1, 1.46, almostLinear"
            "fade, 1, 3.03, quick"
            "layers, 1, 3.81, easeOutQuint"
            "layersIn, 1, 4, easeOutQuint, fade"
            "layersOut, 1, 1.5, linear, fade"
            "fadeLayersIn, 1, 1.79, almostLinear"
            "fadeLayersOut, 1, 1.39, almostLinear"
            "workspaces, 1, 1.94, almostLinear, fade"
            "workspacesIn, 1, 1.21, almostLinear, fade"
            "workspacesOut, 1, 1.94, almostLinear, fade"
          ];
        };

        # Workspace rules (from `workspace = ...` lines)
        workspace = [
          "w[tv1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];

        dwindle = {
          pseudotile = true;
          preserve_split = true;
          # force_split = 2; # Original commented out
        };

        master = {
          new_status = "master";
        };

        misc = {
          force_default_wallpaper = -1;
          disable_hyprland_logo = true;
        };

        # INPUT
        input = {
          kb_layout = "us";
          # kb_variant = "intl"; # Explicitly empty as in original
          kb_variant = ""; # Explicitly empty as in original
          kb_model = ""; # Explicitly empty
          # kb_options = "ctrl:nocaps, altwin:swap_alt_win, compose:ralt"; # From your original config
          # kb_options = "ctrl:nocaps, lv3:ralt_alt, altwin:swap_lalt_lwin, compose:ralt";
          # kb_options = "ctrl:nocaps, lv3:ralt_alt, compose:ralt, altwin:swap_alt_win";
          kb_options = "ctrl:nocaps, lv3:ralt_alt, compose:rctrl, altwin:swap_alt_win";
          kb_rules = ""; # Explicitly empty
          follow_mouse = 1;
          # sensitivity = -0.5; # -1.0 - 1.0, 0 means no modification.
          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
          touchpad = {
            natural_scroll = true;
          };
          natural_scroll = true; # This applies to mice if separate from touchpad
        };

        device = {
          name = "cx-2.4g-receiver-mouse";
          sensitivity = -0.7;
        };

        # gestures = {
        #   workspace_swipe = false;
        # };

        # KEYBINDINGS
        # Note: $mainMod, $terminal, etc. are Hyprland variables defined above.
        # The script `~/dotfiles/waybar/launch.sh` needs to exist at that path.
        # For better reproducibility, consider managing this script with Nix as well,
        # e.g., by placing it in `${config.xdg.configHome}/hypr/scripts/launch.sh`
        # and referencing that path.
        bind = [
          "$mainMod SHIFT, B, exec, ~/.config/waybar/launch.sh"
          "$mainMod SHIFT, R, exec, hyprctl reload"
          "$mainMod, RETURN, exec, $terminal"
          "$mainMod, C, killactive,"
          "$mainMod, x, exit,"
          "$mainMod, f, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod, SPACE, exec, $menu"
          "$mainMod SHIFT, m, exec, rofi -show window"
          "$mainMod, P, pseudo," # dwindle
          "$mainMod, t, togglesplit," # dwindle
          "$mainMod, m, fullscreen, 1"
          # "$mainMod, m, fullscreenstate, 0 2" # Original commented out
          "$mainMod, TAB, cyclenext"
          ", PRINT, exec, hyprshot -m window"
          "shift, PRINT, exec, hyprshot -m region"
          "$mainMod, h, movefocus, l"
          "$mainMod, l, movefocus, r"
          "$mainMod, k, movefocus, u"
          "$mainMod, j, movefocus, d"
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
          "$mainMod SHIFT, h, resizeactive, -10 0"
          "$mainMod SHIFT, l, resizeactive, 10 0"
          "$mainMod SHIFT, k, resizeactive, 0 10"
          "$mainMod SHIFT, j, resizeactive, 0 -10"
          "$mainMod ALT, h, movewindow, l"
          "$mainMod ALT, l, movewindow, r"
          "$mainMod ALT, k, movewindow, u"
          "$mainMod ALT, j, movewindow, d"
        ];

        bindm = [
          # Mouse bindings
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        bindel = [
          # Laptop multimedia keys (no repeat)
          ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
          ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
        ];

        bindl = [
          # Keys with lock (repeat)
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPrev, exec, playerctl previous"
        ];

        # WINDOWS AND WORKSPACES RULES (from `windowrulev2 = ...` lines)
        windowrulev2 = [
          # Rules for specific workspaces (from original config)
          "bordersize 0, floating:0, onworkspace:w[tv1]"
          "rounding 0, floating:0, onworkspace:w[tv1]"
          "bordersize 0, floating:0, onworkspace:f[1]"
          "rounding 0, floating:0, onworkspace:f[1]"
          # Other window rules from your config
          "fullscreenstate 0 2, class:(firefox)"
          # "windowrule = float, ^(kitty)$" # Example v1, commented out
          # "windowrulev2 = float,class:^(kitty)$,title:^(kitty)$" # Example v2, commented out
          "suppressevent maximize, class:.*"
          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0" # Fix some dragging issues
          "tile,class:(eagle.exe)" # Ensure Eagle.cool is always tiled
        ];
      };
    };
  };
}
