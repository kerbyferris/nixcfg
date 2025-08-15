# Common configuration for all hosts
{
  pkgs,
  lib,
  inputs,
  outputs,
  ...
}: {
  imports = [
    ./neovim
    ./users
    inputs.home-manager.nixosModules.home-manager
    inputs.nixvim.nixosModules.nixvim
  ];
  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs outputs;};
  };
  nix = {
    extraOptions = ''
      download-buffer-size = 104857600
    '';
  };
  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.stable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Lisbon";
  # time.timeZone = "Europe/Berlin";
  services.timesyncd.enable = true;
  services.geoclue2.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AG";
    LC_IDENTIFICATION = "en_AG";
    LC_MEASUREMENT = "en_AG";
    LC_MONETARY = "en_AG";
    LC_NAME = "en_AG";
    LC_NUMERIC = "en_AG";
    LC_PAPER = "en_AG";
    LC_TELEPHONE = "en_AG";
    LC_TIME = "en_AG";
  };

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    targets = {
      gtk.enable = true;
      nixvim.enable = false;
      qt.platform = lib.mkForce "qtct";
    };
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.flatpak.enable = true;
  # systemd.services.flatpak-repo = {
  #   wantedBy = ["multi-user.target"];
  #   path = [pkgs.flatpak];
  #   script = ''
  #     flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #   '';
  # };

  # Enable the X11 windowing system.
  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
      options = "ctrl:swapcaps,compose:ralt";
    };
  };

  hardware.keyboard.zsa.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  home-manager.backupFileExtension = "BAK";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    base16-schemes
    coreutils
    dfu-util
    dig
    fd
    fh
    file
    gcc
    git
    gnumake
    jq
    keymapp
    killall
    kmscon
    libinput
    nh
    pciutils
    procs
    python3
    ripgrep
    tree
    usbutils
    vim
    whois
    zip
  ];

  programs.zsh.enable = true;

  users.defaultUserShell = pkgs.zsh;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    allowSFTP = true;
  };

  # programs.ssh.startAgent = true;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = [
        "root"
        "kerby"
      ]; # Set users that are allowed to use the flake command
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 1d";
    };
    optimise.automatic = true;
    registry =
      (lib.mapAttrs (_: flake: {inherit flake;}))
      ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    #nixPath = [ "/etc/nix/path" ];
  };
}
