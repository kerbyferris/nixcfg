{pkgs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      bitwig-studio = prev.bitwig-studio.overrideAttrs (oldAttrs: {
        version = "6.0";
        src = pkgs.fetchurl {
          url = "https://downloads-secure.bitwig.com/6.0/bitwig-studio-6.0.deb";
          hash = "sha256-tASGO2pnkuJ9OIXDsaE47/oc4EEldg03vrZvVtwWmIQ=";
        };
        # Inherit the original package's meta information
        # meta = oldAttrs.meta;
      });
    })
  ];
}
