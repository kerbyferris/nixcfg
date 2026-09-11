# overlays/default.nix
{inputs, ...}: {
  additions = final: prev: {
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};
    pi-commandcode-provider = final.callPackage ../pkgs/pi-commandcode-provider.nix {};
    immich-go = final.callPackage ../pkgs/immich-go.nix {};
    omp-commandcode-plugin = final.callPackage ../pkgs/omp-commandcode-plugin.nix {};
    refern = final.callPackage ../pkgs/refern.nix {};
    bitwig-connect-control-panel = final.callPackage ../pkgs/bitwig-connect-control-panel.nix {
      src = /home/kerby/.local/share/nixcfg-vendor/bitwig-connect-control-panel-1.0.deb;
    };
  };

  modifications = final: prev: {
    # Pin Wine to nixpkgs-stable (25.05) — Eagle won't start with Wine 11.x
    wineWow64Packages = final.stable.wineWow64Packages;
    wine = final.stable.wine;
    wine64 = final.stable.wine64;
    winetricks = final.stable.winetricks;

    # nixpkgs pins the DaVinci Resolve installer as a fixed-output derivation, but
    # Blackmagic re-uploaded the 21.1 Linux installer (last-modified 2026-09-10)
    # after that hash was taken. Unfree packages are never built by Hydra, so the
    # stale hash never surfaces upstream. Re-instantiate the package with the src
    # hash patched. If Blackmagic re-uploads again the build fails with a hash
    # mismatch whose "got" value goes in here.
    davinci-resolve = prev.callPackage (prev.path + "/pkgs/by-name/da/davinci-resolve/package.nix") {
      runCommandLocal = name: attrs: script:
        prev.runCommandLocal
        name
        (
          if name == "davinci-resolve-src.zip"
          then attrs // {outputHash = "sha256-+3SB32EHpH9/0hM3h8CrO6f7V4ZAmxUFh3P8m6QDeO0=";}
          else attrs
        )
        script;
    };

    bitwig-studio6 = prev.bitwig-studio6.overrideAttrs (oldAttrs: {
      version = "6.1.1";
      src = final.fetchurl {
        name = "bitwig-studio-6.1.1.deb";
        url = "https://www.bitwig.com/dl/Bitwig%20Studio/6.1.1/installer_linux";
        hash = "sha256-FBe0R6YW4IS1OPvCwWseQvJnn7OrPn1uZ0v/GKRIIYE=";
      };
    });

    # patool 4.0.5 tests fail with nixpkgs-unstable's gnutar/file — MIME detection regressions
    python3Packages =
      prev.python3Packages
      // {
        patool = prev.python3Packages.patool.overridePythonAttrs (_: {
          doCheck = false;
        });
      };

    # hyprland 0.56.1 CMake FetchContent tries to download glaze from GitHub,
    # which fails in the sandbox (no network). Point it at nixpkgs' glaze instead.
    hyprland = prev.hyprland.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [final.git];
      cmakeFlags =
        (oldAttrs.cmakeFlags or [])
        ++ [
          "-DFETCHCONTENT_SOURCE_DIR_GLAZE=${final.glaze.src}"
        ];
    });
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}
