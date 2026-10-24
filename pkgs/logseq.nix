# Logseq 2.x — the "DB version" (SQLite graphs), packaged from the official
# Linux release zip.
#
# Why not nixpkgs' `logseq`: that is still 0.10.15 (the file/markdown version)
# and it pins `electron_39`, which this nixpkgs refuses to evaluate (every
# electron < 42 carries `knownVulnerabilities`), so installing it is an
# evaluation error — see _agents/NIXOS_AGENT.md. 2.x bundles its own Electron
# (42.3.0 / Chromium 148 in 2.0.2), so nothing here depends on nixpkgs' electron
# and a nixpkgs bump cannot break it the same way.
#
# The zip is an *unpacked* Electron app (logseq + resources/app.asar + locales),
# not an AppImage and not a source build: no FHS wrapper and no yarn/Clojure
# build are needed, only patchelf work on the bundled ELF binaries and the two
# native node modules (keytar → libsecret, @zvec → the vector index).
#
# Upstream's electron-updater is inert here (the store is read-only and
# `resources/app-update.yml` is left alone): bump `version` + `hash` by hand.
# On first launch the app also writes a `~/.local/bin/logseq` CLI shim that
# hardcodes this store path — after an upgrade, start the app once so it
# rewrites the shim, or delete it.
#
# Deliberately not packaged: `resources/sidecar/embedding_server.py` needs a pip
# `sentence_transformers` plus a downloaded model. It is optional in the app
# (semantic search only) and has no effect on startup.
{
  lib,
  stdenv,
  fetchzip,
  python3,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk4,
  libaio,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libxkbcommon,
  libxshmfence,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  speechd-minimal,
  systemd,
  vulkan-loader,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbfile,
  libxrandr,
  libxrender,
  libxtst,
}: let
  # One list for both buildInputs (autoPatchelfHook resolves DT_NEEDED against
  # it) and the final RPATH. Electron *dlopens* EGL/GL/Vulkan, so the RPATH has
  # to be explicit — without it the GPU process dies with
  # "Could not dlopen native EGL: libEGL.so.1" and the window stays blank.
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libaio
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    libxshmfence
    nspr
    nss
    pango
    pciutils
    pipewire
    speechd-minimal
    systemd
    vulkan-loader
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbfile
    libxrandr
    libxrender
    libxtst
  ];

  libPath = lib.makeLibraryPath runtimeLibs;
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "logseq";
    version = "2.0.2";

    src = fetchzip {
      url = "https://github.com/logseq/logseq/releases/download/${finalAttrs.version}/Logseq-linux-x86_64-${finalAttrs.version}.zip";
      hash = "sha256-S9ajBEL3Sshwnz2vAkEaS/eYRdFWE8zPZbWlOgXVC0A=";
      # the zip has no single top-level directory
      stripRoot = false;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
      python3 # icon extraction from app.asar
    ];

    buildInputs = runtimeLibs ++ [stdenv.cc.cc.lib];

    # makeWrapper adds these to $out/bin/logseq by hand (below), so the hook
    # must not try to wrap anything inside $out/lib.
    dontWrapGApps = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/logseq
      cp -a $src/. $out/lib/logseq/
      chmod -R u+w $out/lib/logseq
      chmod +x $out/lib/logseq/logseq \
        $out/lib/logseq/chrome-sandbox \
        $out/lib/logseq/chrome_crashpad_handler

      # The window icon only exists inside resources/app.asar; pull the 512px
      # one out of the asar header table, so there is no second pinned URL.
      mkdir -p $out/share/icons/hicolor/512x512/apps
      python3 - $out/lib/logseq/resources/app.asar $out/share/icons/hicolor/512x512/apps/logseq.png <<'PY'
      import json, struct, sys
      asar, out = sys.argv[1], sys.argv[2]
      d = open(asar, "rb").read()
      jlen = struct.unpack("<I", d[12:16])[0]
      hdr = json.loads(d[16:16 + jlen])
      base = 8 + struct.unpack("<I", d[4:8])[0]
      node = hdr["files"]["icons"]["files"]["logseq.png"]
      off = base + int(node["offset"])
      open(out, "wb").write(d[off:off + int(node["size"])])
      PY

      # Written by hand rather than with makeDesktopItem: Exec must point at
      # THIS derivation's wrapper (the app drops a CLI shim at
      # ~/.local/bin/logseq, which precedes the profile in PATH, so a bare
      # `logseq` would launch the CLI instead of the GUI), and
      # `\${placeholder "out"}` inside makeDesktopItem resolves to the
      # desktop-item derivation's own out.
      mkdir -p $out/share/applications
      cat > $out/share/applications/Logseq.desktop <<EOF
      [Desktop Entry]
      Type=Application
      Version=1.5
      Name=Logseq
      Comment=Privacy-first, open-source platform for knowledge management and collaboration
      Exec=$out/bin/logseq %U
      Icon=logseq
      Terminal=false
      Categories=Utility;
      MimeType=x-scheme-handler/logseq;
      StartupWMClass=Logseq
      EOF

      runHook postInstall
    '';

    # `autoPatchelfHook` registers itself in postFixupHooks and its RPATH only
    # covers DT_NEEDED, so the dlopen'd paths and the bundled-vulkan swap must
    # run *after* it — a plain `postFixup` runs first and gets overwritten.
    preFixup = ''
      # Electron 30+ reads the ozone platform from this env var, which avoids
      # the fragile quoted --add-flags conditional (it leaked a literal
      # uninterpolated shell expansion into the app's argv). auto means Wayland
      # when WAYLAND_DISPLAY is set, X11 otherwise — no NIXOS_OZONE_WL gate.
      makeWrapper $out/lib/logseq/logseq $out/bin/logseq \
        "''${gappsWrapperArgs[@]}" \
        --set-default ELECTRON_OZONE_PLATFORM_HINT auto

      logseqRpathFixup() {
        patchelf --set-rpath "${libPath}:$out/lib/logseq" \
          $out/lib/logseq/logseq \
          $out/lib/logseq/chrome_crashpad_handler

        # Electron ships its own vulkan loader with compiled-in paths; use
        # nixpkgs' so the Mesa ICDs (RADV/Intel) are actually found.
        rm -f $out/lib/logseq/libvulkan.so.1
        ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/lib/logseq/libvulkan.so.1

        # libANGLE (libEGL/libGLESv2) dlopens the loader and the PCI database,
        # so autoPatchelfHook cannot infer them from DT_NEEDED.
        for f in $out/lib/logseq/lib*GL*; do
          patchelf --set-rpath "$out/lib/logseq:${lib.makeLibraryPath [
        libGL
        vulkan-loader
        pciutils
      ]}" "$f"
        done
      }
      postFixupHooks+=(logseqRpathFixup)
    '';

    meta = {
      description = "Privacy-first, open-source platform for knowledge management (DB version 2.x)";
      homepage = "https://logseq.com";
      license = lib.licenses.agpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "logseq";
      platforms = ["x86_64-linux"];
    };
  })
