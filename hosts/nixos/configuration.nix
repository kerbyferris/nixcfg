# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  lib,
  ...
}: let
  # Minimal allow-all seccomp profile for podman (development default)
  # Podman's compiled-in path /usr/share/containers/seccomp.json is
  # inaccessible on NixOS because /usr/share has root-only permissions.
  # We create it at boot via systemd-tmpfiles.
  podmanSeccomp = pkgs.writeText "seccomp.json" (builtins.toJSON {
    defaultAction = "SCMP_ACT_ALLOW";
    archMap = [];
    syscalls = [];
  });
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # SOPS secret management — decrypts secrets at boot via sops-nix
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.secrets."agent-env" = {
    owner = "kerby";
    group = "users";
  };

  # Additional hardware config for tap to click
  hardware.trackpoint.device = "TPPS/2 Synaptics TrackPoint";
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Important for some applications that might use 32-bit libs
    package = pkgs.mesa; # This ensures you're on the Mesa version NixOS provides for your channel.
    extraPackages = with pkgs; [
      intel-compute-runtime
    ];
  };

  # Bootloader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.catalogue.enable = true;

  # boot.loader.grub.devices = ["/dev/nvme0n1"];
  # boot.loader.grub.devices = ["nodev"];
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.useOSProber = false;

  # boot.loader.grub.extraEntries = ''
  #   menuentry "Windows 11 (T7 Shield)" {
  #      insmod part_gpt
  #      insmod fat
  #      insmod search_fs_uuid
  #      insmod chain
  #
  #      # Search for the T7 Shield's EFI partition by its UUID and set it as root
  #      search --fs-uuid --set=root 3E58-3647
  #
  #      # Chainload the Windows Boot Manager EFI application
  #      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
  #    }
  # '';

  time.hardwareClockInLocalTime = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "i915.enable_fbc=0"
  ];

  # Roland TR-09 ("Boutique", 0582:01cf): its playback + capture endpoints are
  # implicit-feedback coupled; on recent kernels opening both (duplex) fails
  # with "Incompatible EP setup for 0x8e". SKIP_IMPLICIT_FB (bit 18 = 0x40000)
  # decouples them so full duplex works in Bitwig (10 in / 2 out @ 44.1kHz).
  boot.extraModprobeConfig = ''
    options snd-usb-audio vid=0x0582 pid=0x01cf quirk_flags=0x40000
  '';

  networking.hostName = "nixos"; # Define your hostname.

  # Enable sound with pipewire.
  security.rtkit.enable = true;

  services.fwupd.enable = true;

  services.pipewire = {
    enable = true;
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 2048;
        "default.clock.min-quantum" = 2048;
        "default.clock.max-quantum" = 8192;
        # "default.clock.max-quantum" = 256;
        # "default.clock.allowed-rates" = [ 44100 48000 96000 ]; #add rates as needed.
        # "default.clock.quantum-limit" = 512;
        # "default.clock.force-quantum" = false;
        # "default.clock.prefer-quantum" = 128;
      };
    };
    alsa = {
      enable = true;
      support32Bit = true;
      # extraConfig = ''
      #   defaults.pcm.rate_converter "speex-float-1"
      # '';
    };
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;

    wireplumber.extraConfig."99-bitwig-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {"node.name" = "~alsa_output.usb-Bitwig_GmbH_Bitwig_Connect.*";}
          ];
          actions = {
            "update-props" = {
              "priority.session" = 2000;
            };
          };
        }
      ];
    };

    wireplumber.extraScripts."blender-routing.lua" = ''
      local log = Log.open_topic("s-blender-routing")
      local cutils = require("common-utils")

      -- iterate all sinks to find WH-1000XM4 by nick
      local function route_to_hp(node)
        local om = ObjectManager { Interest { type = "node",
          Constraint { "media.class", "=", "Audio/Sink" },
        }}
        om:activate()
        for sink in om:iterate { type = "SiLinkable" } do
          local nick = sink.properties["node.nick"]
          if nick and nick:find("WH%-1000XM4") then
            local meta = cutils.get_default_metadata_object()
            if meta then
              meta:set(node:get_id(), "target.object", tostring(sink:get_id()))
              log:info("Routed Blender to WH-1000XM4")
            end
            break
          end
        end
      end

      local b_om = ObjectManager {
        Interest { type = "node",
          Constraint { "node.name", "=", ".blender-wrapped" },
        },
      }
      b_om:connect("object-added", function(_, node) route_to_hp(node) end)
      b_om:activate()
    '';

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Local ollama server with Qwen2.5-Coder-3B for subagent/lightweight tasks.
  # Uses Vulkan acceleration via the RX 580 eGPU (RADV driver from Mesa).
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    loadModels = [
      "qwen2.5-coder:3b"
    ];
  };

  # Podman — daemonless container runtime (Docker-compatible)
  # Used by work-os for containerized dev/deploy workflow
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Point podman at our Nix-managed seccomp profile (used at runtime)
  virtualisation.containers.containersConf.settings = {
    engine.seccomp_profile = "${podmanSeccomp}";
  };
  # Podman's compiled-in seccomp path is /usr/share/containers/seccomp.json.
  # On NixOS, /usr/share has 0700 permissions (security hardening), which
  # prevents non-root processes from checking the default path. We relax
  # this so podman can verify its default seccomp profile exists.
  systemd.tmpfiles.settings."podman-seccomp" = {
    "/usr/share".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/usr/share/containers".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/usr/share/containers/seccomp.json".f = {
      mode = "0644";
      user = "root";
      group = "root";
      argument = builtins.toJSON {
        defaultAction = "SCMP_ACT_ALLOW";
        archMap = [];
        syscalls = [];
      };
    };
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kerby";

  services.upower.enable = true;

  services.logind = {
    enable = true;
    settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
  };

  # Fingerprint reader
  services.fprintd.enable = true;

  security.sudo.extraRules = [
    {
      users = ["kerby"];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # os-prober
    bitwig-fhs
    bitwig-connect-control-panel
    fwupd
    intel-media-driver
    libva
    # libva-intel-gpu
    podman-compose # drop-in replacement for docker-compose
    libva-utils
    ffmpeg
    libdrm
    intel-gmmlib
    tailscale
    nixd
    bash-language-server
  ];

  environment.sessionVariables.VA_DRIVERS_PATH = "/nix/store/7wpjbidyx1g9algql7jvzm00lzjrwaw6-intel-media-driver-25.1.4/lib/dri/";
  # VA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri"; # This assumes it's always in lib/dri.

  services.udev = {
    packages = with pkgs; [
      openocd
      platformio-core.udev
      clinfo
      bitwig-connect-control-panel
    ];

    extraRules = ''
      # 69-probe-rs.rules
      # ACTION!="add|change", GOTO="probe_rs_rules_end"
      # SUBSYSTEM=="gpio", MODE="0660", GROUP="plugdev", TAG+="uaccess"
      # SUBSYSTEM!="usb|tty|hidraw", GOTO="probe_rs_rules_end"
      # # STMicroelectronics STLINK-V3
      # ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", MODE="660", GROUP="plugdev", TAG+="uaccess"
      # ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", MODE="660", GROUP="plugdev", TAG+="uaccess"
      # ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", MODE="660", GROUP="plugdev", TAG+="uaccess"
      # ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", MODE="660", GROUP="plugdev", TAG+="uaccess"
      # ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3754", MODE="660", GROUP="plugdev", TAG+="uaccess"
      # # Raspberry Pi Pico
      # ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="[01]*", MODE:="0666", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
    '';
  };

  # Enable Tailscale
  services.tailscale.enable = true;
  # Syncthing — peer-to-peer file sync (runs as kerby, discoverable on LAN + Tailscale)
  services.syncthing = {
    enable = true;
    user = "kerby";
    group = "users";
    dataDir = "/home/kerby/.local/share/syncthing";
    configDir = "/home/kerby/.config/syncthing";
    openDefaultPorts = true;
  };

  # Networking
  # Enable SSH access in from Tailscale network 22
  # Enable http/s traffic to go through 80 and 443 for access n8n thorugh tailscale
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [3478];
    allowedTCPPorts = [22 443 80];
  };

  home-manager = {
    extraSpecialArgs = {inherit pkgs;};
    users.kerby = import ../../home/kerby/nixos.nix;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # system.stateVersion = "24.11"; # Did you read the comment?
  system.stateVersion = "24.11"; # Did you read the comment?
}
