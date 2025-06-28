# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{pkgs, ...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Additional hardware config for tap to click
  hardware.trackpoint.device = "TPPS/2 Synaptics TrackPoint";
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Important for some applications that might use 32-bit libs
    # Uncomment the next line if you face issues or want to try newer Mesa versions
    # package = pkgs.mesa.latest; # Use the latest Mesa from Nixpkgs
    extraPackages = with pkgs; [
      intel-compute-runtime
    ];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "i915.enable_fbc=0"
  ];

  networking.hostName = "nixos"; # Define your hostname.

  # Enable sound with pipewire.
  security.rtkit.enable = true;
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
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kerby";

  # Fingerprint reader
  services.fprintd.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    intel-media-driver
    libva-utils
  ];

  services.udev = {
    packages = with pkgs; [
      openocd
      platformio-core.udev
      clinfo
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
