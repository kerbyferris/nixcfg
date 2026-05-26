# overlays/default.nix
{inputs, ...}: {
  additions = final: prev: {
    # It will build vidplayvst by calling the file and finding all its
    # dependencies (stdenv, lib, etc) from nixpkgs.
    vidplayvst = final.callPackage ../pkgs/vidplayvst.nix {};

    # It will build bitwig-fhs by calling the file and finding dependencies.
    # It finds `buildFHSUserEnv`, `bitwig-studio6`, and `findutils` in nixpkgs.
    # It finds `vidplayvst` because we just defined it above.
    bitwig-fhs = final.callPackage ../pkgs/bitwig-fhs.nix {};
  };

  # Your other overlays below are fine and should remain
  modifications = final: prev: {};

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
