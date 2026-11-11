# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
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

  # Re-execs ollama when an AMD GPU (the RX 580 eGPU) enumerates or disappears.
  # ollama enumerates its Vulkan devices once, at start-up, and never rescans, so a
  # card that appears after the unit starts stays invisible to it for the rest of the
  # boot — and a card that DISAPPEARS leaves it holding a dead device, after which
  # every model load hangs (`load_duration` never completes, no error). Both events
  # need a restart; `$1` is `add` or `remove`.
  #
  # On `add` the udev event fires *before* amdgpu finishes probing, and a restart at
  # that moment still finds only the Intel iGPU — so wait for the AMD DRM card node.
  # On `remove` the card is already gone; wait a little in case it is a transient
  # re-enumeration (the add handler will cover that), then fall back to CPU.
  ollamaGpuRestart = pkgs.writeShellApplication {
    name = "ollama-gpu-restart";
    runtimeInputs = with pkgs; [systemd coreutils gnugrep];
    text = ''
      mode="''${1:-add}"

      amd_card() {
        for v in /sys/class/drm/card*/device/vendor; do
          [ -e "$v" ] || continue
          if [ "$(cat "$v" 2>/dev/null)" = "0x1002" ]; then
            echo "$v"
            return 0
          fi
        done
        return 1
      }

      if [ "$mode" = "remove" ]; then
        # Give a flapping link a chance to come straight back; the add handler
        # restarts ollama properly with the card once it re-enumerates.
        sleep 15
        if amd_card >/dev/null; then
          echo "AMD GPU came back within 15s — leaving the restart to the add handler"
          exit 0
        fi
        echo "AMD GPU disappeared; restarting ollama so it falls back instead of hanging"
        systemctl restart ollama.service
        exit 0
      fi

      found=""
      for _ in $(seq 1 120); do
        if found=$(amd_card); then
          break
        fi
        found=""
        sleep 1
      done

      if [ -z "$found" ]; then
        echo "no AMD DRM card after 120s — leaving ollama alone" >&2
        exit 0
      fi

      card=''${found%/device/vendor}
      echo "AMD GPU appeared at $card; settling for 5s"
      sleep 5
      if [ ! -e "$found" ]; then
        echo "$card disappeared again (amdgpu init failed?) — not restarting ollama" >&2
        exit 0
      fi

      echo "restarting ollama.service to pick up $card"
      systemctl restart ollama.service
      echo "ollama.service restarted; device enumeration:"
      journalctl -u ollama --no-pager --since "30 seconds ago" \
        | grep -iE 'inference compute|vulkan[0-9]|dropping integrated' || true
    '';
  };
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
  sops.secrets."TS_AUTH_KEY" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."proxmox-samba-username" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets."proxmox-samba-password" = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  # Credentials file for Proxmox Samba mounts (CIFS expects username= / password= format)
  sops.templates."proxmox-samba-credentials" = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      username=${config.sops.placeholder.proxmox-samba-username}
      password=${config.sops.placeholder.proxmox-samba-password}
    '';
  };

  # Additional hardware config for tap to click
  hardware.trackpoint.device = "TPPS/2 Synaptics TrackPoint";
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Important for some applications that might use 32-bit libs
    package = pkgs.mesa; # This ensures you're on the Mesa version NixOS provides for your channel.
    extraPackages = with pkgs; [
      intel-compute-runtime
      # VA-API (iHD) for the Meteor Lake iGPU — required for hardware video
      # decode. Without it libva finds no driver ("vaInitialize failed"), the
      # GStreamer `va` plugin registers 0 elements, and every H.264/HEVC frame
      # is decoded on the CPU: 4K50 HEVC measures ~1.2-1.4x realtime, i.e. no
      # headroom (refern/WebKit playback stutters, seeks crawl). With iHD the
      # same clip decodes at ~3-5x realtime with the CPU idle and vah265dec
      # (rank 257) outranks avdec_h265 (rank 256).
      intel-media-driver
    ];
  };

  # Bootloader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.catalogue.enable = true;

  # Bulk data pool: the former Windows p1-p4 region + the 'Shared' partition,
  # one btrfs volume spanning two partitions of the same NVMe.
  # Mounted by FILESYSTEM UUID, not a member PARTUUID: this is a multi-device
  # filesystem, so the filesystem — not any one device — is what we name; a
  # future mkfs yields a new UUID and makes the mount fail loudly instead of
  # silently attaching a fresh empty filesystem. No nofail, no automount: it
  # is local, always present, and a mount failure should be visible.
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/2f33dfb6-d596-4f5c-970a-cb1c7a89df46";
    fsType = "btrfs";
    options = ["noatime"];
  };

  # Kernel: rolling latest (7.3.x). Nothing is pinned; if Bluetooth or the
  # headset mic regresses, know that BOTH are kernel-sensitive on this box:
  #  - Intel AX211 HFP/SCO was broken on 7.x for a while (Sep 2026): log shows
  #    "SCO packet for unknown connection handle" / "corrupted SCO packet",
  #    headset mic + speaker dead during calls while A2DP still worked.
  #    2026-10-25: tested on 7.3.0 — HID mouse AND headset mic/speaker both fine
  #    in a Google Meet call, no SCO errors in the log, so the pin is gone.
  #  - 6.12.114 shipped an incomplete backport of "Bluetooth: L2CAP: convert to
  #    getsockopt_iter" (upstream bf01627cc04b) with no matching
  #    do_sock_getsockopt() dispatch, so every getsockopt() on an L2CAP socket
  #    returned EOPNOTSUPP and bluetoothd died at "Failed to create GATT
  #    database for adapter" / "Unable to register new adapter" — no controller,
  #    no mouse, no applet, while `systemctl status bluetooth` still said active.
  # Fallback if a future kernel reintroduces either bug: boot the previous
  # generation from the systemd-boot menu (Space at the splash), or pin
  # `boot.kernelPackages` to a known-good set. Diagnosis + the exact checks are
  # in the vault: _agents/NIXOS_AGENT.md → "Bluetooth on the AX211".
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  boot.kernelParams = [
    "i915.enable_fbc=0"
    "acpi.poweroff_on_fatal=0"
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

    wireplumber.extraConfig."98-boutique-resample" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {"node.name" = "~alsa_input.usb-Roland_Boutique.*";}
            {"node.name" = "~alsa_output.usb-Roland_Boutique.*";}
          ];
          actions = {
            "update-props" = {
              "resample.quality" = 14;
              "resample.n-taps" = 256;
              "resample.cutoff" = 0.99;
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
    # Nothing is preloaded any more. The `tiny` role (the only automatic ollama
    # consumer here) moved to a cloud model on 2026-11-01 precisely because a
    # second model request evicts the first, and that eviction tears the RX 580
    # down (see OLLAMA_KEEP_ALIVE below). With no preload, ollama holds nothing
    # until you ask for a model — and the one you ask for is then pinned.
    loadModels = [];
    # Never unload an idle model. The RX 580 does not survive a runner teardown on
    # this enclosure: `amdgpu … finishing device` is followed by
    # `SMU message 0x261 failed` and then `rlc is busy` / `Timeout wait for RLC
    # serdes`, after which the card is off the bus until the enclosure is power
    # cycled. Loading a SECOND model is the reliable way to trigger it, so: one
    # model at a time, kept resident (measured 2026-11-01).
    environmentVariables.OLLAMA_KEEP_ALIVE = "-1";
  };

  # Started by udev (rules in services.udev.extraRules) when an AMD GPU appears or
  # disappears. oneshot without RemainAfterExit, so the next hotplug can start it again.
  systemd.services.ollama-gpu-restart = {
    description = "Restart ollama after an AMD GPU (eGPU) enumerates";
    after = ["ollama.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ollamaGpuRestart}/bin/ollama-gpu-restart add";
      # the script waits up to 120s for the DRM node, then restarts ollama
      TimeoutStartSec = 300;
    };
  };
  systemd.services.ollama-gpu-lost = {
    description = "Restart ollama after an AMD GPU (eGPU) disappears";
    after = ["ollama.service"];
    serviceConfig = {
      Type = "oneshot";
      # 15s grace for a re-enumeration, then restart so it can't hang on a dead device
      ExecStart = "${ollamaGpuRestart}/bin/ollama-gpu-restart remove";
      TimeoutStartSec = 300;
    };
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

  # Flatpak's glycin-svg loader uses `flatpak-spawn --sandbox prlimit …` to
  # restrict memory of the SVG icon loader. On NixOS, prlimit is not at
  # /usr/bin/prlimit, so the sandboxed process fails silently, GTK hits a
  # fatal icon assertion, and the app crashes (observed: Bambu Studio).
  systemd.tmpfiles.rules = [
    "L+    /usr/bin/prlimit   -    -    -     -    ${pkgs.util-linux}/bin/prlimit"
  ];

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

  # XDG Portal — required for native file picker in Firefox/Zen on Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config = {
      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      };
    };
  };
  environment.sessionVariables.VA_DRIVERS_PATH = "/nix/store/7wpjbidyx1g9algql7jvzm00lzjrwaw6-intel-media-driver-25.1.4/lib/dri/";
  # VA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri"; # This assumes it's always in lib/dri.

  # Direct HDMI: aquamarine allocates tiled/CCS buffers (4_TILED_MTL_RC_CCS_CC) that the
  # HDMI-A-1 atomic commit rejects on this Intel MTL -> "atomic drm request: failed to
  # commit: Invalid argument"; every mode in the EDID is retried and rejected, so the
  # output stays disabled (dpms Off, mode 0x0). Linear buffers avoid the rejected
  # modifiers. Upstream workaround: hyprwm/Hyprland#10420. USB-C/DP outputs are unaffected.
  environment.sessionVariables.AQ_NO_MODIFIERS = "1";

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

      # nRF52 / nRF52840 Meshtastic boards — Seeed Wio Tracker L1 (e-ink), XIAO nRF52840,
      # Adafruit, RAK. Three enumerations to cover:
      #   2886:xxxx  Seeed — CDC-ACM app port + UF2 mass-storage in bootloader mode
      #   239a:xxxx  Adafruit nRF52 bootloader — serial DFU (adafruit-nrfutil) + UF2 drive
      #   1915:xxxx  Nordic S140 DFU port
      # The stock 50-udev-default rule only sets GROUP="dialout"; TAG+="uaccess" grants the
      # logged-in session user access on hotplug, and the ID_MM_* keys stop ModemManager from
      # probing/holding the CDC-ACM port — that probe is what breaks the 1200-baud DFU touch
      # ("port busy" / no DFU drive) and adafruit-nrfutil's dfu serial.
      ATTRS{idVendor}=="2886", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1", MODE="0660", TAG+="uaccess"
      ATTRS{idVendor}=="239a", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1", MODE="0660", TAG+="uaccess"
      ATTRS{idVendor}=="1915", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1", MODE="0660", TAG+="uaccess"

      # Espressif ESP32-S3 / ESP32-Cx native USB (303a:1001 = USB-Serial/JTAG, also
      # 303a:1000) — M5Stack Cardputer/Cardputer ADV, Heltec, and most devkits.
      # Two jobs: TAG+="uaccess" grants the seated user the port regardless of the
      # dialout group, and ID_MM_* stops ModemManager from probing/holding the
      # CDC-ACM node (which makes esptool see a busy port). platformio-core.udev
      # also matches 303a:1001, but it sets no GROUP at all — it sets MODE="0666",
      # and because 99-platformio-udev.rules sorts after 99-local.rules its MODE
      # wins, so the port ends up 0666 rather than the 0660 above. Harmless (more
      # permissive than intended, and TAG+="uaccess" from this file still applies).
      ATTRS{idVendor}=="303a", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1", MODE="0660", TAG+="uaccess"

      # AMD GPU (RX 580 eGPU on Thunderbolt) → restart ollama. ollama enumerates its
      # Vulkan devices ONCE at start-up and never rescans: a card that appears after
      # the unit starts stays invisible for the rest of the boot (symptom: "ollama ps"
      # reports CPU only, no "inference compute" line for the card), and one that
      # reappears after a Thunderbolt drop is missed entirely. Matched by vendor+class
      # (VGA) rather than device id, so a replacement card is covered too. The helper
      # unit waits for the AMD DRM card node before restarting, because udev fires
      # long before amdgpu has finished probing.
      SUBSYSTEM=="pci", ACTION=="add", ATTR{vendor}=="0x1002", ATTR{class}=="0x030000", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ollama-gpu-restart.service"
      SUBSYSTEM=="pci", ACTION=="remove", ATTR{vendor}=="0x1002", ATTR{class}=="0x030000", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ollama-gpu-lost.service"
    '';
  };

  # Enable Tailscale — auto-reconnects via sops-decrypted auth key
  services.tailscale.enable = true;
  services.tailscale.authKeyFile = config.sops.secrets."TS_AUTH_KEY".path;
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
