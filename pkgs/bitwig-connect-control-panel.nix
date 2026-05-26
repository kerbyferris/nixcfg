{
  alsa-lib,
  atk,
  autoPatchelfHook,
  cairo,
  dpkg,
  fontconfig,
  freetype,
  gdk-pixbuf,
  giflib,
  glib,
  gtk3,
  harfbuzz,
  lcms2,
  lib,
  libglvnd,
  libjack2,
  libjpeg8,
  libusb1,
  libx11,
  libxcb,
  libxcursor,
  libxfixes,
  libxkbcommon,
  libxrender,
  libxtst,
  makeBinaryWrapper,
  pango,
  stdenv,
  systemd,
  vulkan-loader,
  wrapGAppsHook3,
  xcbutilwm,
  xcb-imdkit,
  zlib,
  src ? null,
}:
assert src != null;
  stdenv.mkDerivation (finalAttrs: {
    pname = "bitwig-connect-control-panel";
    version = "1.0";

    inherit src;

    strictDeps = true;

    nativeBuildInputs = [
      autoPatchelfHook
      dpkg
      makeBinaryWrapper
      wrapGAppsHook3
    ];

    buildInputs = [
      alsa-lib
      atk
      cairo
      fontconfig
      freetype
      gdk-pixbuf
      giflib
      glib
      gtk3
      harfbuzz
      lcms2
      libglvnd
      libjack2
      libjpeg8
      libusb1
      libx11
      libxcb
      libxcursor
      libxfixes
      libxkbcommon
      libxrender
      libxtst
      pango
      vulkan-loader
      xcb-imdkit
      xcbutilwm
      zlib
      (lib.getLib stdenv.cc.cc)
      systemd
    ];

    dontWrapGApps = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/libexec
      cp -r opt/bitwig-control-panel/* $out/libexec/

      mkdir -p $out/share
      cp -r usr/share/applications $out/share/
      cp -r usr/share/icons $out/share/
      cp -r usr/share/mime $out/share/

      runHook postInstall
    '';

    postFixup = let
      wrapperScript = ''
        #!${stdenv.shell}
        exec "''${BASH_SOURCE[0]%/*}"/../libexec/BitwigConnectControlPanel "$@"
      '';
    in ''
      wrapProgram "$out/libexec/bin/show-file-dialog-gtk3" \
        "''${gappsWrapperArgs[@]}"

      install -Dm755 /dev/stdin "$out/bin/bitwig-connect-control-panel" <<'EOF'
      ${wrapperScript}
      EOF

      ln -s bitwig-connect-control-panel "$out/bin/bitwig-control-panel"

      mkdir -p $out/etc/udev/rules.d
      cat > $out/etc/udev/rules.d/00-bitwig.rules <<'RULES'
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="17c8", ATTRS{idProduct}=="7010", MODE:="0666"
      KERNEL=="hidraw*", ATTRS{idVendor}=="17c8", ATTRS{idProduct}=="7010", MODE:="0666"

      SUBSYSTEMS=="usb", ATTRS{idVendor}=="17c8", ATTRS{idProduct}=="7011", MODE:="0666"
      RULES
    '';

    meta = {
      description = "Control panel for Bitwig Connect audio interface";
      homepage = "https://bitwig.com";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "bitwig-connect-control-panel";
    };
  })
