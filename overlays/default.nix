# overlays/default.nix
{inputs, ...}: {
  additions = final: prev: {
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};
    bitwig-connect-control-panel = final.callPackage ../pkgs/bitwig-connect-control-panel.nix {
      src = /home/kerby/.local/share/nixcfg-vendor/bitwig-connect-control-panel-1.0.deb;
    };
  };

  modifications = final: prev: {
    bitwig-studio6 = prev.bitwig-studio6.overrideAttrs (oldAttrs: {
      version = "6.0.7";
      src = final.fetchurl {
        name = "bitwig-studio-6.0.7.deb";
        url = "https://www.bitwig.com/dl/Bitwig%20Studio/6.0.7/installer_linux";
        hash = "sha256-FantrFBb9Tl27mHZ28Mpm4rDQ/Sd2nAevGsKUfInZAI=";
      };
    });
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}
