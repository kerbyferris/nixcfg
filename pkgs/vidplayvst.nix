# /path/to/your/flake/pkgs/vidplayvst.nix
{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  libx11,
  libxext,
  libxfixes,
}:
stdenv.mkDerivation rec {
  pname = "vidplayvst";
  version = "2.6.0";

  src = ../vendor/VidPlayVST-${version}-Setup.run

  # Tools needed to build the package
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Runtime dependencies for the plugin and its libraries
  # These are common dependencies for graphical/audio applications on Linux.
  # autoPatchelfHook will use these to patch the binaries.
  buildInputs = [
    alsa-lib
    libx11
    libxext
    libxfixes
    stdenv.cc.cc.lib # for libstdc++
  ];

  # The VST plugin is pre-compiled
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Extract the .run file without executing its script
    sh $src --noexec --target extracted

    # Create the directory structure in the output path ($out)
    mkdir -p $out/lib/vst
    mkdir -p $out/lib/vidplayvst-libs

    # Copy the main VST plugin file
    install -m755 -D extracted/VidPlayVST.so $out/lib/vst/VidPlayVST.so

    # Copy all of its bundled libraries
    install -m644 extracted/lib/*.so $out/lib/vidplayvst-libs/

    # This is the crucial step!
    # We tell VidPlayVST.so where to find its libraries at runtime.
    # The RPATH is a search path embedded in the binary.
    patchelf --set-rpath "$out/lib/vidplayvst-libs" $out/lib/vst/VidPlayVST.so

    runHook postInstall
  '';

  meta = with stdenv.lib; {
    description = "A VST plugin to play videos in sync with your DAW";
    homepage = "https://vidplayvst.com/";
    license = licenses.unfree; # It's proprietary software
    platforms = platforms.linux;
    maintainers = [maintainers.you]; # Replace with your handle
  };
}
