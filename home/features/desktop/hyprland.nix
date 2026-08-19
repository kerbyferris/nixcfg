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
      cliphist
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
      "hypr/scripts/cycle-next-fullscreen.sh" = {
        text = ''
          #!/usr/bin/env bash
          # Cycle to next window preserving fullscreen/maximize state
          data=$(hyprctl activewindow -j 2>/dev/null || echo '{"fullscreen":0}')
          fs=''${data#*'"fullscreen":'}
          fs=''${fs:0:1}
          if [ "$fs" != "0" ]; then
            mode=$((fs - 1))
            hyprctl dispatch cyclenext
            hyprctl dispatch fullscreenstate 1 "$mode"
          else
            hyprctl dispatch cyclenext
          fi
        '';
        executable = true;
      };
    };

    systemd.user.services.hyprdynamicmonitors = {
      Unit = {
        After = lib.mkForce [
          "hyprdynamicmonitors-prepare.service"
          "upower.service"
        ];
        Before = lib.mkForce [
          "graphical-session-pre.target"
        ];
        Requires = lib.mkForce [];
        PartOf = lib.mkForce [];
      };
      Service = let
        waitForDp1 = pkgs.writeShellScript "hyprdynamicmonitors-wait-dp1" ''
          for i in $(seq 1 20); do
            if cat /sys/class/drm/card*-DP-*/status 2>/dev/null | grep -q "^connected"; then
              exit 0
            fi
            sleep 0.5
          done
          exit 0
        '';
      in {
        ExecStartPre = ["-${waitForDp1}"];
      };
      Install = {
        WantedBy = lib.mkForce [
          "default.target"
          "graphical-session-pre.target"
        ];
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";

      settings = {
        # Lua locals, rendered before everything else. Referenced by name in
        # `extraConfig` below (e.g. `hl.dsp.exec_cmd(terminal)`).
        mainMod = {
          _var = "SUPER";
        };
        terminal = {
          _var = "ghostty";
        };
        # terminal = { _var = "kitty"; };
        fileManager = {
          _var = "nautilus";
        };
        menu = {
          _var = "rofi -show drun --show-icons";
        };

        # hl.config(...) — dotted section settings (replaces the hyprlang blocks)
        config = {
          # XWAYLAND specific settings
          xwayland = {
            force_zero_scaling = true;
          };

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
            enabled = true;
          };

          dwindle = {
            preserve_split = true;
            # force_split = 2; # Original commented out
          };

          master = {
            new_status = "master";
          };

          misc = {
            force_default_wallpaper = -1;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
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
            kb_options = "ctrl:nocaps, lv3:ralt_alt, compose:rctrl";
            kb_rules = ""; # Explicitly empty
            follow_mouse = 1;
            # sensitivity = -0.5; # -1.0 - 1.0, 0 means no modification.
            sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
            touchpad = {
              natural_scroll = true;
            };
            natural_scroll = true; # This applies to mice if separate from touchpad
          };
        };

        # hl.curve(...) — animation curves (2-arg calls)
        curve = [
          {
            _args = [
              "easeOutQuint"
              {
                type = "bezier";
                points = [
                  [0.23 1]
                  [0.32 1]
                ];
              }
            ];
          }
          {
            _args = [
              "easeInOutCubic"
              {
                type = "bezier";
                points = [
                  [0.65 0.05]
                  [0.36 1]
                ];
              }
            ];
          }
          {
            _args = [
              "linear"
              {
                type = "bezier";
                points = [
                  [0 0]
                  [1 1]
                ];
              }
            ];
          }
          {
            _args = [
              "almostLinear"
              {
                type = "bezier";
                points = [
                  [0.5 0.5]
                  [0.75 1.0]
                ];
              }
            ];
          }
          {
            _args = [
              "quick"
              {
                type = "bezier";
                points = [
                  [0.15 0]
                  [0.1 1]
                ];
              }
            ];
          }
        ];

        # hl.animation(...)
        animation = [
          {
            leaf = "global";
            enabled = true;
            speed = 10;
            bezier = "default";
          }
          {
            leaf = "border";
            enabled = true;
            speed = 5.39;
            bezier = "easeOutQuint";
          }
          {
            leaf = "windows";
            enabled = true;
            speed = 4.79;
            bezier = "easeOutQuint";
          }
          {
            leaf = "windowsIn";
            enabled = true;
            speed = 4.1;
            bezier = "easeOutQuint";
            style = "popin 87%";
          }
          {
            leaf = "windowsOut";
            enabled = true;
            speed = 1.49;
            bezier = "linear";
            style = "popin 87%";
          }
          {
            leaf = "fadeIn";
            enabled = true;
            speed = 1.73;
            bezier = "almostLinear";
          }
          {
            leaf = "fadeOut";
            enabled = true;
            speed = 1.46;
            bezier = "almostLinear";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 3.03;
            bezier = "quick";
          }
          {
            leaf = "layers";
            enabled = true;
            speed = 3.81;
            bezier = "easeOutQuint";
          }
          {
            leaf = "layersIn";
            enabled = true;
            speed = 4;
            bezier = "easeOutQuint";
            style = "fade";
          }
          {
            leaf = "layersOut";
            enabled = true;
            speed = 1.5;
            bezier = "linear";
            style = "fade";
          }
          {
            leaf = "fadeLayersIn";
            enabled = true;
            speed = 1.79;
            bezier = "almostLinear";
          }
          {
            leaf = "fadeLayersOut";
            enabled = true;
            speed = 1.39;
            bezier = "almostLinear";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 1.94;
            bezier = "almostLinear";
            style = "fade";
          }
          {
            leaf = "workspacesIn";
            enabled = true;
            speed = 1.21;
            bezier = "almostLinear";
            style = "fade";
          }
          {
            leaf = "workspacesOut";
            enabled = true;
            speed = 1.94;
            bezier = "almostLinear";
            style = "fade";
          }
        ];

        # hl.env(...) — ENVIRONMENT VARIABLES
        env = [
          {_args = ["XCURSOR_SIZE" "24"];}
          {_args = ["HYPRCURSOR_SIZE" "24"];}
          {_args = ["WLR_NO_HARDWARE_CURSORS" "1"];}
          {_args = ["MOZ_ENABLE_WAYLAND" "1"];}
        ];

        # hl.window_rule(...) — structured rules (replaces hyprlang windowrule
        # and the old exec-once `hyprctl keyword windowrulev2` workarounds)
        window_rule = [
          {
            match = {class = "(blender)";};
            tile = true;
            min_size = "600 400";
          }
          # Catch Blender's built-in file browser by title
          {
            match = {title = "Blender File View";};
            tile = true;
            min_size = "800 600";
          }
          {
            match = {initial_title = "Blender File View";};
            tile = true;
            min_size = "800 600";
          }
          # Zen Browser — keep video fullscreen within window (like Chrome)
          {
            match = {class = "(zen-beta)";};
            fullscreen_state = "1 2";
          }
          # Suppress maximize requests from all apps
          {
            match = {class = ".*";};
            suppress_event = "maximize";
          }
          # Fix dragging issues with XWayland: no focus for blank Wine windows
          {
            match = {
              class = "^$";
              title = "^$";
              xwayland = true;
              float = true;
              fullscreen = false;
              pin = false;
            };
            no_focus = true;
          }
          # Eagle (Wine) — force tiling
          {
            match = {class = "(eagle.exe)";};
            tile = true;
          }
          # Suppress blank Wine explorer.exe windows to the special (hidden) workspace
          {
            match = {class = "(explorer.exe)";};
            workspace = "special";
          }
          # Smart gaps: no gaps/borders on w[tv1] and f[1] workspaces
          {
            match = {
              float = false;
              workspace = "w[tv1]";
            };
            border_size = 0;
          }
          {
            match = {
              float = false;
              workspace = "w[tv1]";
            };
            rounding = 0;
          }
          {
            match = {
              float = false;
              workspace = "f[1]";
            };
            border_size = 0;
          }
          {
            match = {
              float = false;
              workspace = "f[1]";
            };
            rounding = 0;
          }
        ];

        # hl.workspace_rule(...)
        workspace_rule = [
          {
            workspace = "w[tv1]";
            gaps_out = 0;
            gaps_in = 0;
          }
          {
            workspace = "f[1]";
            gaps_out = 0;
            gaps_in = 0;
          }
        ];

        # hl.device(...)
        device = {
          name = "cx-2.4g-receiver-mouse";
          sensitivity = -0.7;
        };

        # gestures = {
        #   workspace_swipe = false;
        # };
      };

      extraConfig = ''
        -- Dynamic monitors: hyprdynamicmonitors writes hyprlang-style lines to
        -- ~/.config/hypr/monitors.conf (e.g. `monitor = DP-1,2560x1440@59.95,0x0,1`
        -- or `monitor = eDP-1,disable`). Lua mode has no `source` directive, so
        -- translate that file into hl.monitor(...) calls here. `hyprctl reload`
        -- (run by hyprdynamicmonitors' post_apply_exec) re-runs this file, which
        -- picks up the new profile on lid/external-monitor changes.
        do
          local f = io.open(os.getenv("HOME") .. "/.config/hypr/monitors.conf", "r")
          if f then
            for line in f:lines() do
              local output, rest = line:match("^%s*monitor%s*=%s*([^,]+),%s*(.-)%s*$")
              if output then
                output = output:gsub("%s+$", "")
                if rest == "disable" then
                  hl.monitor({ output = output, disabled = true })
                else
                  local mode, position, scale = rest:match("^([^,]*),%s*([^,]*),%s*([^,]*)$")
                  local t = { output = output }
                  if mode and mode ~= "" then t.mode = mode end
                  if position and position ~= "" then t.position = position end
                  if scale and scale ~= "" then t.scale = scale end
                  hl.monitor(t)
                end
              end
            end
            f:close()
          end
        end

        -- AUTOSTART
        hl.on("hyprland.start", function()
          hl.exec_cmd(terminal)
          hl.exec_cmd("wl-paste --watch cliphist store &")
          hl.exec_cmd("nm-applet & blueman-applet")
          hl.exec_cmd("~/.config/waybar/launch.sh & swaync")
        end)

        -- KEYBINDINGS
        -- mainMod, terminal, fileManager, menu are the locals from `settings`.
        -- The script ~/.config/waybar/launch.sh is managed by Nix.
        hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("~/.config/waybar/launch.sh"))
        hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
        hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
        hl.bind(mainMod .. " + C", hl.dsp.window.close())
        hl.bind(mainMod .. " + x", hl.dsp.exit())
        hl.bind(mainMod .. " + f", hl.dsp.exec_cmd(fileManager))
        hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd([[cliphist list | rofi -dmenu -p "Clipboard" -display-columns 2 | cliphist decode | wl-copy]]))
        hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
        hl.bind(mainMod .. " + SHIFT + m", hl.dsp.exec_cmd("rofi -show window"))
        hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
        hl.bind(mainMod .. " + m", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
        -- "$mainMod, m, fullscreenstate, 0 2" # Original commented out
        hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("~/.config/hypr/scripts/cycle-next-fullscreen.sh"))
        hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
        hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region"))
        hl.bind("CTRL + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
        hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
        hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
        hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
        hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
        hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
        hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
        hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
        hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
        hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
        hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
        hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
        hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
        hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
        hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
        hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
        hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
        hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
        hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
        hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
        hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
        hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
        hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
        hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
        hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))
        hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
        hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
        hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
        hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
        hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }))
        hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }))
        hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.resize({ x = 0, y = 10, relative = true }))
        hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.resize({ x = 0, y = -10, relative = true }))
        hl.bind(mainMod .. " + ALT + h", hl.dsp.window.move({ direction = "left" }))
        hl.bind(mainMod .. " + ALT + l", hl.dsp.window.move({ direction = "right" }))
        hl.bind(mainMod .. " + ALT + k", hl.dsp.window.move({ direction = "up" }))
        hl.bind(mainMod .. " + ALT + j", hl.dsp.window.move({ direction = "down" }))

        -- Mouse bindings (hyprlang bindm)
        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        -- Laptop multimedia keys (hyprlang bindel: locked + repeating)
        hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
        hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

        -- Media keys (hyprlang bindl: locked)
        hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
        hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
      '';
    };
  };
}
