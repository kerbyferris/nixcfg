# refern — desktop reference manager for artists (Eagle alternative)
# Native Linux .deb → unpacked with ar/tar → wrapped in an FHS env
# (WebKitGTK 4.1 app; NixOS has no /lib64 loader, so the FHS is required).
# Version + hash pinned; bump by updating both below.
{
  lib,
  fetchurl,
  buildFHSEnv,
  runCommand,
  binutils,
  gnutar,
  gtk3,
  webkitgtk_4_1,
  cairo,
  glib,
  gdk-pixbuf,
  libheif,
  openssl,
  libsoup_3,
  libgbm,
  libayatana-appindicator,
  desktop-file-utils,
  wayland,
  xorg,
  gst_all_1,
}: let
  version = "1.8.1";
  src = fetchurl {
    url = "https://storage.googleapis.com/refern-releases/releases/v${version}/refern_${version}_amd64.deb";
    hash = "sha256-2T3Q08go3BwG1u13NeI6OaRvQf6S0UJ4qLr/cNmt26M=";
  };
  unpacked =
    runCommand "refern-unpacked-${version}" {
      nativeBuildInputs = [
        binutils
        gnutar
      ];
    } ''
      mkdir -p $out
      cd $out
      ar x ${src}
      tar -xf data.tar.gz
    '';
  fhs = buildFHSEnv {
    name = "refern";

    targetPkgs = pkgs: [
      gtk3
      webkitgtk_4_1
      cairo
      glib
      gdk-pixbuf
      libheif
      openssl
      libsoup_3
      libgbm
      libayatana-appindicator
      # 1.8.1's tauri-plugin-deep-link setup runs `update-desktop-database`
      # (desktop-file-utils) on startup; without it in PATH the app panics in
      # its setup hook with "No such file or directory".
      desktop-file-utils
      wayland
      xorg.libxcb
      # Video playback: refern previews media through WebKitGTK's <video> element,
      # which decodes via GStreamer. Without codec plugins, MP4 (H.264/HEVC)
      # renders black. base/good = demuxers+parsers, bad = h265parse etc,
      # libav = ffmpeg-based decoders (avdec_h264/avdec_h265).
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-libav
    ];

    # /usr/bin symlinks inside the FHS env: the FHS profile prepends /usr/bin
    # to PATH, so `refern` resolves here (avoids recursion back into the
    # host-side wrapper script). refern-ffmpeg/ffprobe are the bundled
    # binaries used for probing/thumbnails.
    extraBuildCommands = ''
      mkdir -p $out/usr/bin
      ln -s ${unpacked}/usr/bin/refern $out/usr/bin/refern
      ln -s ${unpacked}/usr/bin/refern-ffmpeg $out/usr/bin/refern-ffmpeg
      ln -s ${unpacked}/usr/bin/refern-ffprobe $out/usr/bin/refern-ffprobe
    '';

    # WebKitGTK decodes <video> through GStreamer; without codec plugins MP4
    # (H.264/HEVC) playback renders black. Pin the full plugin path so the
    # refern process finds demuxers/parsers (base/good/bad) and decoders (libav).
    # NOTE: buildFHSEnv wraps runScript as `exec <runScript> "$@"`, so a
    # multi-line runScript becomes `exec export …` and fails — env must go
    # through extraBwrapArgs --setenv.
    extraBwrapArgs =
      [
        "--setenv"
        "GST_PLUGIN_SYSTEM_PATH_1_0"
        (lib.concatStringsSep ":" [
          "${gst_all_1.gst-libav}/lib/gstreamer-1.0"
          "${gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
          "${gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
          "${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
          "${gst_all_1.gstreamer.out}/lib/gstreamer-1.0"
        ])
      ]
      ++ [
        # WebKit's sandboxed WebProcess cannot exec the forked gst-plugin-scanner
        # helper, so a cold/invalid registry cache (~/.cache/gstreamer-1.0) makes
        # the scan silently yield an empty plugin registry -> "appsink not found"
        # -> MP4/H.264 playback fails with MEDIA_ERR_SRC_NOT_SUPPORTED.
        # In-process scanning (fork disabled) fixes cold starts.
        "--setenv"
        "GST_REGISTRY_FORK"
        "no"
      ];

    runScript = "refern";
  };
in
  # buildFHSEnv's output is a bare wrapper file (home-manager installs it as
  # bin/<name>). Build a proper package dir: bin wrapper + desktop entry + icons,
  # so refern shows up in the app launcher (profile share/ dirs).
  runCommand "refern-pkg-${version}" {} ''
    mkdir -p $out/bin $out/share/applications $out/share/icons
    ln -s ${fhs}/bin/refern $out/bin/refern
    ln -s ${unpacked}/usr/share/applications/refern.desktop $out/share/applications/refern.desktop
    ln -s ${unpacked}/usr/share/icons/hicolor $out/share/icons/hicolor
  ''
