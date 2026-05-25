{pkgs, ...}: {
  # Define your custom packages here
  #  my-package = pkgs.callPackage ./my-package {};
  vidplayvst = pkgs.callPackage ./vidplayvst.nix {};
}
