# overlays/default.nix
{inputs, ...}: {
  additions = final: prev: {
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};
    pi-commandcode-provider = final.callPackage ../pkgs/pi-commandcode-provider.nix {};
    immich-go = final.callPackage ../pkgs/immich-go.nix {};
    omp-commandcode-plugin = final.callPackage ../pkgs/omp-commandcode-plugin.nix {};
    refern = final.callPackage ../pkgs/refern.nix {};
    m5burner = final.callPackage ../pkgs/m5burner.nix {};
    # Shadows nixpkgs' logseq (0.10.15, pinned to electron_39, which this
    # nixpkgs refuses to evaluate as EOL) with upstream's 2.x "DB version"
    # release. See pkgs/logseq.nix.
    logseq = final.callPackage ../pkgs/logseq.nix {};
    bitwig-connect-control-panel = final.callPackage ../pkgs/bitwig-connect-control-panel.nix {
      src = /home/kerby/.local/share/nixcfg-vendor/bitwig-connect-control-panel-1.0.deb;
    };
  };

  # ArtCraft apps (ipeglin/artcraft-nix) with native file drag-and-drop made to
  # work. winit only implements native DnD on X11, so under a native Wayland
  # session the apps disable it and say so ("Native file drag-and-drop is
  # unavailable — ... run PhotoCraft under XWayland with `WAYLAND_DISPLAY= ...`").
  # Re-wrap each binary so WAYLAND_DISPLAY is dropped whenever an X display
  # exists, which makes winit pick the X11 backend — XWayland, where XDND works
  # (the apps' X11 backend has it compiled in). Pure-Wayland hosts with no
  # XWayland keep the native backend, since DISPLAY is unset there.
  # `pkgs.artcraftX11.<app>` is the newest release of each app.
  artcraftX11 = final: prev: let
    lib = final.lib;
    artcraft = import "${inputs.artcraft}/default.nix" {pkgs = final;};
    newest = lib.filterAttrs (name: _: !(lib.hasInfix "_" name)) (removeAttrs artcraft ["default"]);
    withX11Dnd = drv:
      drv.overrideAttrs (old: {
        postFixup =
          (old.postFixup or "")
          + ''
            for bin in "$out"/bin/*; do
              wrapProgram "$bin" --run 'if [ -n "''${DISPLAY-}" ]; then unset WAYLAND_DISPLAY; fi'
            done
          '';
      });
  in {
    artcraftX11 = lib.mapAttrs (_: withX11Dnd) newest;
  };

  modifications = final: prev: {
    # Pin Wine to nixpkgs-stable (25.05) — Eagle won't start with Wine 11.x
    wineWow64Packages = final.stable.wineWow64Packages;
    wine = final.stable.wine;
    wine64 = final.stable.wine64;
    winetricks = final.stable.winetricks;

    bitwig-studio6 = prev.bitwig-studio6.overrideAttrs (oldAttrs: {
      version = "6.1.5";
      src = final.fetchurl {
        name = "bitwig-studio-6.1.5.deb";
        url = "https://www.bitwig.com/dl/Bitwig%20Studio/6.1.5/installer_linux";
        hash = "sha256-Q2j+exxDV3LuCb5JlQLZpZFP4nUm9treD+fJAT06rfY=";
      };
      # Bitwig bundles an old fontconfig that reads cache format 9 from
      # $XDG_CACHE_HOME/fontconfig. System fontconfig (2.18) writes format 12 and
      # additionally creates *compatibility symlinks* named `*-cache-9` pointing at
      # the cache-12 file; Bitwig follows such a symlink, mis-reads the newer format
      # and spins forever in FcPatternGetString during `initSkia` — symptom is the
      # log stopping at "begin skia initialization" with ~100% CPU and no window.
      # Give Bitwig its own cache root so no other fontconfig's output can poison it.
      postFixup =
        (oldAttrs.postFixup or "")
        + ''
          if ! grep -qF 'BITWIG_XDG_CACHE_HOME' "$out/bin/.bitwig-studio-wrapped"; then
            substituteInPlace "$out/bin/.bitwig-studio-wrapped" \
              --replace-fail \
              'currentDir="$(cd "$(dirname "$0")" && pwd)"' \
              'export XDG_CACHE_HOME="''${BITWIG_XDG_CACHE_HOME:-$HOME/.cache/bitwig-studio}"
          currentDir="$(cd "$(dirname "$0")" && pwd)"'
          fi
        '';
    });

    # patool 4.0.5 tests fail with nixpkgs-unstable's gnutar/file — MIME detection regressions
    python3Packages =
      prev.python3Packages
      // {
        patool = prev.python3Packages.patool.overridePythonAttrs (_: {
          doCheck = false;
        });

        # PyPI publishes this sdist with UNDERSCORES in the filename
        # (show_in_file_manager-1.1.6.tar.gz) while fetchPypi builds the URL from
        # `pname` (dashes) → 404, which blocked hydrus and everything downstream
        # (`error: cannot download show-in-file-manager-1.1.6.tar.gz from any
        # mirror`). 1.1.6 also builds with hatchling, not setuptools.
        # Same fix as upstream nixpkgs commit da9a3bc190 (2026-10-21); drop this
        # override once the pinned nixpkgs contains it.
        show-in-file-manager = prev.python3Packages.show-in-file-manager.overridePythonAttrs (old: {
          src = prev.fetchurl {
            url = "https://files.pythonhosted.org/packages/source/s/show_in_file_manager/show_in_file_manager-1.1.6.tar.gz";
            hash = "sha256-VZtZbj5WOADPadc0zSNoJCeanYINHYQWQMXxPgBY+bY=";
          };
          nativeBuildInputs =
            (old.nativeBuildInputs or [])
            ++ [
              prev.python3Packages.hatchling
              prev.python3Packages.hatch-argparse-manpage
            ];
        });

        # The test asserts on an exact TypeError message; Cython 3.3.0 reworded it
        # ("must be str" → "Expected str, got int"), so it fails while the other
        # 1678 tests pass. pyopenjtalk-plus commit 90b644f fixes the regex and
        # nixpkgs carries it via a fetchpatch (commit dfb035a649) that our pin
        # predates. Skip just this test; drop the override once the pin has it.
        pyopenjtalk-plus = prev.python3Packages.pyopenjtalk-plus.overridePythonAttrs (_: {
          disabledTests = ["test_run_njd_from_mecab_invalid_input_should_not_break_next_call"];
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
