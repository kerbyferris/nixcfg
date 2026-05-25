{
  buildFHSUserEnv,
  bitwig-studio6,
  vidplayvst,
  # We add extra tools to the FHS env for debugging
  bash,
  coreutils,
  findutils,
  gawk,
  gnugrep,
  gnused,
  glibc,
}:
buildFHSUserEnv {
  name = "bitwig-studio-fhs-env-debug-shell"; # <-- New name
  targetPkgs = _pkgs: [
    bitwig-studio6
    # Make sure debugging tools are available inside the bubble
    bash
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    glibc # Provides ldd
  ];

  # We use the exact same build commands to ensure the environment is identical
  extraInstallCommands = ''
    mkdir -p $out/usr/share
    cp -r ${vidplayvst}/lib/vidplayvst-libs $out/usr/share/vidplayvst
    find $out/usr/share/vidplayvst -type d -exec chmod 755 {} +
    find $out/usr/share/vidplayvst -type f -exec chmod 644 {} +
    find $out/usr/share/vidplayvst -name '*.so' -exec chmod 755 {} +
  '';

  extraBuildCommands = ''
    mkdir -p $out/lib
    ln -s ${vidplayvst}/lib/vst $out/lib/vst
  '';

  # Instead of launching Bitwig, it will launch a shell.
  runScript = "bash";
}
