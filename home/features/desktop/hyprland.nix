{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.features.desktop.hyprland;
in {
  options.features.desktop.hyprland.enable = mkEnableOption "enable hyprland config";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      blueman # For blueman-applet
      brightnessctl # For brightness controls
      kitty
      libnotify
      ghostty # Your chosen terminal
      hypridle
      hyprshot # For screenshot binds
      nautilus # Your file manager
      networkmanagerapplet # For nm-applet
      playerctl # For media key controls
      swaynotificationcenter # For swaync
      swww
      waybar
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
      };
    };

    # Manage other related configuration files
    # These will be symlinked into ~/.config/
    xdg.configFile = {
      "waybar/config".source = ./waybar/config.jsonc;
      "waybar/style.css".source = ./waybar/style.css;
      "waybar/launch.sh".source = ./waybar/launch.sh;
    };

    wayland.windowManager.hyprland = {
      enable = true;

      settings = {
        # Hyprland's internal variables (defined with $ in hyprland.conf)
        "$mainMod" = "SUPER"; # Sets "Windows" key as main modifier
        "$terminal" = "ghostty";
        "$fileManager" = "nautilus";
        "$menu" = "rofi -show drun --show-icons";

        # MONITORS
        monitor = [
          "eDP-1,highres@highrr,0x0,1" # laptop
          "DP-1,highres@highrr,auto-right,1" # Arzopa 1
          # "HDMI-A-1,1920x1080,1920x0,1" # Arzopa 2 (HDMI) - commented out
          # "HDMI-A-4,1920x1080,-1920x0,1" # Arzopa 2 (Radeon) - commented out
          # "DP-3,1920x1080@60,0x0,1" # Asus - commented out
        ];

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
        ];

        # AUTOSTART
        "exec-once" = [
          "$terminal" # Hyprland will substitute its $terminal variable
          "nm-applet & blueman-applet"
          "waybar & swaync"
          # "waybar & hyprpaper & firefox" # Original commented out line
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
          kb_variant = ""; # Explicitly empty as in original
          kb_model = ""; # Explicitly empty
          kb_options = "ctrl:nocaps"; # From your original config
          kb_rules = ""; # Explicitly empty
          follow_mouse = 1;
          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
          touchpad = {
            natural_scroll = true;
          };
          natural_scroll = true; # This applies to mice if separate from touchpad
        };

        gestures = {
          workspace_swipe = false;
        };

        # Per-device config
        device = {
          "epic-mouse-v1" = {
            # Name of the device becomes the key
            sensitivity = -0.5;
          };
        };

        # KEYBINDINGS
        # Note: $mainMod, $terminal, etc. are Hyprland variables defined above.
        # The script `~/dotfiles/waybar/launch.sh` needs to exist at that path.
        # For better reproducibility, consider managing this script with Nix as well,
        # e.g., by placing it in `${config.xdg.configHome}/hypr/scripts/launch.sh`
        # and referencing that path.
        bind = [
          "$mainMod SHIFT, B, exec, ~/dotfiles/waybar/launch.sh"
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
        ];
      };
    };
  };
}
