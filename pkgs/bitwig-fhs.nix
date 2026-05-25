{
  buildFHSUserEnv,
  bitwig-studio6,
  vidplayvst,
}:
buildFHSUserEnv {
  name = "bitwig-studio-fhs-env";
  targetPkgs = _pkgs: [bitwig-studio6];

  # This creates the fake /usr/share/vidplayvst directory inside the bubble
  # and symlinks the plugin's real libraries into it.
  extraInstallCommands = ''
    mkdir -p $out/usr/share
    cp -r ${vidplayvst}/lib/vidplayvst-libs $out/usr/share/vidplayvst
    find $out/usr/share/vidplayvst -name '*.so' -exec chmod +x {} +
  '';

  # This ensures the VSTs themselves are discoverable inside the bubble
  extraBuildCommands = ''
    mkdir -p $out/lib
    ln -s ${vidplayvst}/lib/vst $out/lib/vst
  '';

  runScript = "bitwig-studio6";
}
