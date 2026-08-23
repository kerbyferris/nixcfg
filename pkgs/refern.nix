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
  wayland,
  xorg,
  gst_all_1,
}:
let
  version = "1.5.0";
  src = fetchurl {
    url = "https://storage.googleapis.com/refern-releases/releases/v${version}/refern_${version}_amd64.deb";
    hash = "sha256-9gMMIrE+wVuboodP6GpafRGesJ+xQyE62RZ67SWgXjs=";
  };
  unpacked = runCommand "refern-unpacked-${version}" {
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
in
buildFHSEnv {
  name = "refern";

  targetPkgs =
    pkgs: [
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

  extraBuildCommands = ''
    mkdir -p $out/usr/bin
    ln -s ${unpacked}/usr/bin/refern $out/usr/bin/refern
    ln -s ${unpacked}/usr/bin/refern-ffmpeg $out/usr/bin/refern-ffmpeg
    ln -s ${unpacked}/usr/bin/refern-ffprobe $out/usr/bin/refern-ffprobe
  '';

  # WebKitGTK decodes <video> through GStreamer; without codec plugins MP4
  # (H.264/HEVC) playback renders black. Pin the full plugin path so the
  # refern process finds demuxers/parsers (base/good/bad) and decoders (libav).
  extraBwrapArgs = [
    "--setenv"
    "GST_PLUGIN_SYSTEM_PATH_1_0"
    (lib.concatStringsSep ":" [
      "${gst_all_1.gst-libav}/lib/gstreamer-1.0"
      "${gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
      "${gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
      "${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
      "${gst_all_1.gstreamer.out}/lib/gstreamer-1.0"
    ])
  ];

  runScript = "refern";

  meta = {
    description = "Desktop reference manager for artists: Eagle-style organization, infinite canvas, relationship graph";
    homepage = "https://www.refern.app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
