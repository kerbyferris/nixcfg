{pkgs, ...}: {
  # Define your custom packages here
  #  my-package = pkgs.callPackage ./my-package {};
  vidplayvst = pkgs.callPackage ./vidplayvst.nix {};
  bitwig-fhs = pkgs.callPackage ./bitwig-fhs.nix {
    # Here we explicitly pass the Bitwig from Nixpkgs
    bitwig-studio6 = pkgs.bitwig-studio6;
  };
}
