# /path/to/your/flake/pkgs/vidplayvst.nix
{
  stdenv,
  lib,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  libx11,
  libxext,
  libxfixes,
  libGL,
  zlib,
  libXrender,
  libXcursor,
  libXft,
  fontconfig,
  libXinerama,
}:
stdenv.mkDerivation rec {
  pname = "vidplayvst";
  version = "2.6.0";
  src = ../vendor/VidPlayVST-${version}-Setup.run;

  nativeBuildInputs = [autoPatchelfHook makeWrapper];
  buildInputs = [
    alsa-lib
    libx11
    libxext
    libxfixes
    stdenv.cc.cc.lib
    libGL
    zlib
    libXrender
    libXcursor
    libXft
    fontconfig
    libXinerama
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    sh $src --noexec --target extracted
    mkdir -p $out/lib/vst
    mkdir -p $out/lib/vidplayvst-libs

    install -m755 -D extracted/vst/VidPlayVSTv2.so $out/lib/vst/VidPlayVSTv2.so
    install -m755 -D extracted/vst/VidRenderVSTv1.so $out/lib/vst/VidRenderVSTv1.so

    # Copy the dependency libraries
    cp -r extracted/vidplayvst/* $out/lib/vidplayvst-libs/

    # Find all shared libraries (.so files) in our output and make them
    # executable, which is required for them to be loaded.
    find $out -name '*.so' -exec chmod +x {} +

    runHook postInstall
  '';

  meta = with lib; {
    description = "A VST plugin to play videos in sync with your DAW";
    homepage = "https://vidplayvst.com/";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [maintainers.kerbyferris];
  };
}
