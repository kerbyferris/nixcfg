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
  vulkan-headers,
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
      vulkan-headers
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

      # Compile Vulkan XCB workaround shim
      mkdir -p $out/lib
      cat > vk_fix_xcb.c <<'VKCEOF'
#define _GNU_SOURCE
#define VK_USE_PLATFORM_XCB_KHR
#include <vulkan/vulkan.h>
#include <dlfcn.h>

static void *lib = NULL;
static PFN_vkCreateXcbSurfaceKHR real = NULL;

static void init(void) {
  if (!lib) {
    lib = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (lib)
      real = (PFN_vkCreateXcbSurfaceKHR)dlsym(lib, "vkCreateXcbSurfaceKHR");
    if (!real)
      __builtin_trap();
  }
}

VkResult vkCreateXcbSurfaceKHR(VkInstance instance,
    const VkXcbSurfaceCreateInfoKHR *pCreateInfo,
    const VkAllocationCallbacks *pAllocator, VkSurfaceKHR *pSurface) {
  init();
  VkXcbSurfaceCreateInfoKHR fixed = *pCreateInfo;
  fixed.sType = VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR;
  fixed.pNext = NULL;
  return real(instance, &fixed, pAllocator, pSurface);
}
VKCEOF
      $CC -shared -fPIC -O2 \
        -I${vulkan-headers}/include \
        -I${lib.getDev libxcb}/include \
        -o $out/lib/libvk_fix_xcb.so \
        vk_fix_xcb.c -ldl

      runHook postInstall
    '';

    postFixup = ''
      wrapProgram "$out/libexec/bin/show-file-dialog-gtk3" \
        "''${gappsWrapperArgs[@]}"

      makeWrapper "$out/libexec/BitwigConnectControlPanel" "$out/bin/bitwig-connect-control-panel" \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libxcb vulkan-loader libglvnd]} \
        --prefix LD_PRELOAD : $out/lib/libvk_fix_xcb.so

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
