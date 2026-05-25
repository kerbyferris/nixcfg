# /path/to/your/flake/overlays/default.nix
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: prev: {
    # Define vidplayvst.
    # final.callPackage automatically finds its dependencies (stdenv, lib, etc.)
    # from the final package set.
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};

    # Define the bitwig-fhs wrapper.
    # It automatically finds its dependencies, including `vidplayvst` which we defined above,
    # because they all exist in the `final` package set being built.
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};

    # Define the debug shell in the same way.
    bitwig-debug-shell = final.callPackage ../pkgs/bitwig-debug-shell.nix {};
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
