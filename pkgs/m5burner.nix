# M5Burner — M5Stack's ESP32 firmware flasher (Electron).
#
# The vendor ships a generic-Linux zip and relies on the app updating itself:
# the downloadable "M5Burner-v3-beta-linux-x64.zip" is a 2023 bootstrap, and the
# current app is delivered as a per-OS "patch" zip (new app.asar + packages/{view,tool}
# + appVersion.info) that the app extracts over its own root directory. Two
# consequences for NixOS:
#
#  1. The app tree must be WRITABLE, so it cannot run out of the store. This
#     package installs the payload (bootstrap + the current patch, both pinned)
#     into the store, and the wrapper copies it to
#     `$XDG_DATA_HOME/m5burner/app` on first launch. Vendor self-updates land in
#     that copy; the store stays immutable and a rebuild never clobbers them.
#  2. The app shells out to bundled binaries. `nvs` is a normal ELF and
#     autoPatchelfHook fixes it. `esptool` is a generic-glibc PyInstaller binary
#     (`packages/tool/esptool.tmp`, renamed to `esptool` at startup) that NixOS
#     cannot execute, so the wrapper drops a shim onto nixpkgs esptool in its
#     place on every launch — which also repairs the tree after a self-update
#     re-drops `esptool.tmp`. `gen_esp32part.py` needs python3 on PATH.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  writeShellScript,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  xorg,
  python3,
  esptool,
}: let
  version = "3.0.0";

  # Current app build, dated. The app compares packages/appVersion.info against
  # http://m5burner-cdn.m5stack.com/appVersion.info and only self-updates when the
  # two differ, so seeding a matching value keeps first launch offline-clean.
  # Bump the URL + hash (and the bootstrap hash if the vendor rotates it) when a
  # newer build is wanted at install time; the in-app updater covers everything
  # in between.
  appBuild = "202609301800";

  # The CDN answers "denied by Referer ACL" without a docs.m5stack.com referer.
  cdnFetch = url: hash:
    fetchurl {
      inherit url hash;
      curlOptsList = [
        "-A"
        "Mozilla/5.0"
        "-e"
        "https://docs.m5stack.com/"
      ];
    };

  bootstrap = cdnFetch "https://m5burner-cdn.m5stack.com/app/M5Burner-v3-beta-linux-x64.zip" "sha256-oGLbbav6HiR/k0CLCgoBghe/1ohzO4z2WJCI9OMXYcU=";
  appPatch = cdnFetch "https://m5burner-cdn.m5stack.com/patch/${appBuild}-linux.zip" "sha256-3PjAqnUmnTQMHLXM/mxcBs/Bp3OoHRtlXL91ACeR/c8=";

  pythonEnv = python3.withPackages (ps: [ps.pyserial]);
  esptoolShim = writeShellScript "m5burner-esptool" ''
    exec ${esptool}/bin/esptool "$@"
  '';
in
  stdenv.mkDerivation {
    pname = "m5burner";
    inherit version;

    nativeBuildInputs = [
      unzip
      autoPatchelfHook
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libGL
      libnotify
      libpulseaudio
      libxkbcommon
      nspr
      nss
      pango
      systemd # usb-detection links libudev
      wayland
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxshmfence
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/m5burner
      cd $out/share/m5burner
      unzip -q ${bootstrap}
      # Overlay the current app build: replaces bin/resources/app.asar,
      # packages/{view,tool} and appVersion.info. The Electron runtime from the
      # bootstrap is intentionally kept (the patch never ships one).
      unzip -qo ${appPatch}

      # Generic-glibc PyInstaller esptool, plus the 2023 python esptool package
      # directory sitting at the same path. The wrapper installs a shim instead.
      rm -rf packages/tool/esptool packages/tool/esptool.tmp
      chmod +x bin/m5burner

      # autoPatchelfHook only inspects files that are executable or named *.so*,
      # so the Node native modules (usb-detection needs libudev, @serialport/bindings
      # needs libstdc++) would be skipped and fail dlopen at runtime. Give them the
      # exec bit *before* fixupPhase so the hook picks them up.
      find bin/resources/app.asar.unpacked -type f -name '*.node' -exec chmod +x {} +

      install -Dm644 packages/view/assets/images/logo.png \
        $out/share/icons/hicolor/256x256/apps/m5burner.png

      mkdir -p $out/share/applications
      cat > $out/share/applications/m5burner.desktop <<'DESKTOP'
      [Desktop Entry]
      Type=Application
      Name=M5Burner
      GenericName=ESP32 Firmware Flasher
      Comment=Flash M5Stack (and third-party) firmware to ESP32 devices
      Exec=m5burner %U
      Icon=m5burner
      Terminal=false
      Categories=Development;Electronics;
      Keywords=esp32;esp-idf;m5stack;firmware;flasher;
      DESKTOP

      mkdir -p $out/bin
      cat > $out/bin/m5burner <<WRAPPER
      #!${stdenv.shell}
      set -eu

      data="\''${XDG_DATA_HOME:-\$HOME/.local/share}/m5burner"
      app="\$data/app"

      # First launch: seed the writable app tree (≈300 MB, reflinked on btrfs)
      # from the store payload. Later vendor self-updates edit this copy only.
      # Store files are 0555/0444, so the copy must be made writable — both for the
      # esptool shim below and for the app's own patch extraction.
      if [ ! -x "\$app/bin/m5burner" ]; then
        mkdir -p "\$data"
        cp -a --reflink=auto $out/share/m5burner/. "\$app"
        chmod -R u+w "\$app"
      fi

      # The bundled esptool is a generic-glibc PyInstaller binary that cannot run
      # here, and a self-update re-drops it as esptool.tmp. Re-install the shim on
      # every launch so flashing keeps working across app updates.
      tool="\$app/packages/tool"
      if [ -d "\$tool" ]; then
        rm -rf "\$tool/esptool" "\$tool/esptool.tmp"
        install -m755 ${esptoolShim} "\$tool/esptool"
      fi

      export PATH="${pythonEnv}/bin:\$PATH"

      # usb-detection / @serialport are packaged INSIDE app.asar (the duplicate
      # app.asar.unpacked tree is not what Electron loads). Electron extracts a
      # packed .node to $TMPDIR and dlopens that copy, so the RPATH that
      # autoPatchelfHook put on the unpacked files never applies and libudev /
      # libstdc++ are reported missing. A library path entry fixes the dlopen
      # for any such extracted module, including ones a vendor self-update adds.
      export LD_LIBRARY_PATH=${lib.getLib systemd}/lib:${lib.getLib stdenv.cc.cc}/lib:${lib.getLib libGL}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

      exec "\$app/bin/m5burner" "\$@"
      WRAPPER
      chmod +x $out/bin/m5burner

      runHook postInstall
    '';

    meta = {
      description = "M5Stack firmware flasher (ESP32 / UIFlow / community firmwares)";
      homepage = "https://docs.m5stack.com/en/uiflow/m5burner/intro";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "m5burner";
      platforms = ["x86_64-linux"];
    };
  }
