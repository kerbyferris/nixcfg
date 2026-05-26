# pkgs/bitwig-fhs.nix
{
  buildFHSUserEnv,
  bitwig-studio6,
  vidplayvst,
  findutils,
}:
buildFHSUserEnv {
  name = "bitwig-studio-fhs-env";
  targetPkgs = _pkgs: [bitwig-studio6];

  multiPkgs = null;

  extraInstallCommands = ''
    mkdir -p $out/usr/share
    cp -r ${vidplayvst}/lib/vidplayvst-libs $out/usr/share/vidplayvst
    # Force permissions now using the absolute path to find from findutils
    ${findutils}/bin/find $out/usr/share/vidplayvst -type d -exec chmod 755 {} +
    ${findutils}/bin/find $out/usr/share/vidplayvst -name '*.so' -exec chmod 755 {} +
  '';

  extraBuildCommands = ''
    mkdir -p $out/lib
    ln -s ${vidplayvst}/lib/vst $out/lib/vst
  '';

  runScript = "bitwig-studio6";
}
