# overlays/default.nix
{inputs, ...}: {
  additions = final: prev: {
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};
    bitwig-connect-control-panel = final.callPackage ../pkgs/bitwig-connect-control-panel.nix {
      src = /home/kerby/.local/share/nixcfg-vendor/bitwig-connect-control-panel-1.0.deb;
    };
  };

  # Your other overlays below are fine and should remain
  modifications = final: prev: let
    newSrc = final.fetchFromGitHub {
      owner = "earendil-works";
      repo = "pi";
      rev = "v0.77.0";
      hash = "sha256-PJyhLWfqoPjHoYl4pKJVD3uMD5YjQB5YIk5mBZvGi8E=";
    };
  in {
    pi-coding-agent = prev.pi-coding-agent.overrideAttrs (oldAttrs: {
      version = "0.77.0";
      src = newSrc;
      npmDeps = final.fetchNpmDeps {
        src = newSrc;
        name = "pi-coding-agent-0.77.0-npm-deps";
        hash = "sha256-X0qMLqAi5pgrtTw5+DfSPsgIEngUnHwGxqYE6PL8NJU=";
      };
      npmDepsHash = "sha256-X0qMLqAi5pgrtTw5+DfSPsgIEngUnHwGxqYE6PL8NJU=";
    });

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
