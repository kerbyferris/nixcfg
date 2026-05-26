# pkgs/bitwig-fhs.nix
{
  buildFHSEnv,
  bitwig-studio6,
  vidplayvst,
  findutils,
  coreutils,
  extraPkgs ? [],
}:
buildFHSEnv {
  name = "bitwig-studio-fhs-env";

  targetPkgs = _pkgs: [bitwig-studio6] ++ extraPkgs;

  buildInputs = [findutils coreutils];

  extraBuildCommands = ''
    # Part 1: Handle the dependency libraries
    mkdir -p $out/usr/share/vidplayvst
    cp -r ${vidplayvst}/lib/vidplayvst-libs/* $out/usr/share/vidplayvst/
    find $out/usr/share/vidplayvst -name '*.so' -exec chmod +x {} +

    # Part 2: Handle the main VST plugins
    mkdir -p $out/usr/lib64/vst
    ln -s ${vidplayvst}/lib/vst/*.so $out/usr/lib64/vst/

    # Part 3: Standard plugin directories
    mkdir -p $out/usr/lib64/vst3
    mkdir -p $out/usr/lib64/lv2
    mkdir -p $out/usr/lib64/clap
  '';

  runScript = ''
    bash -c '
      if [ $# -eq 0 ]; then
        bitwig-studio
      else
        "$@"
      fi
    ' -- "$@"
  '';
}
