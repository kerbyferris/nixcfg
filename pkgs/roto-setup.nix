# ROTO-SETUP — Melbourne Instruments' companion app for the ROTO-CONTROL
# motorised-knob controller (firmware updates, knob/button label + haptic
# config, and it installs the Ableton / Bitwig / Logic integration files).
#
# Packaged from the vendor's x64 AppImage rather than run ad hoc with
# `appimage-run` (the way the AFFiNE desktop AppImage is) because this one is
# plugged into hardware: it must be on PATH, appear in the launcher, and be able
# to open the device's serial port.
#
# AppImage type 2, Electron 32.3.3 (Chromium 128), 114 MB. The extract contains
# the app plus the DAW integration payloads — `resources/app.asar.unpacked/`
# (ableton/ROTO_CONTROL.py, bitwig/Roto-Control.bwextension, logic/) and the
# RP2040 firmware UF2 in `resources/firmware/` — so the AppImage *is* the
# installer; there is no separate download step for the Bitwig extension.
#
# `wrapType2` builds an FHS environment (buildFHSEnv + bwrap) around the
# extracted tree, which is what supplies glibc/GTK/ALSA/NSS to the bundled
# Electron and patches the two native node modules the app loads for the device
# (`@serialport/bindings-cpp`, `usb` → libudev). The FHS env dev-binds /dev and
# bind-mounts /sys and /run, so the serial/usb modules can still enumerate and
# open the controller.
#
# The controller is an RP2040 exposing two USB identities: 2e8a:f010 with the
# application firmware (two CDC-ACM interfaces — the app opens /dev/ttyACM0 as
# its "main port" and also opens the raw USB node) and 2e8a:0003 for the ROM
# bootloader while flashing. Both need udev rules or the app cannot reach it —
# see the 2e8a block in hosts/nixos/configuration.nix.
#
# Runtime state lives in `~/.config/ROTO-SETUP` (Electron userData). The in-app
# update check fails here with `Error fetching version file: Forbidden` — the
# vendor CDN ACLs everything that is not a release asset (403 on every plain
# path, same class as the M5Burner Referer lock) — so it is cosmetic: updates
# come from bumping this derivation.
#
# Bump: replace `version` + the URL, and `nix-prefetch-url <url>` for the hash.
# The vendor URL pattern is stable and the bytes it serves are what other
# machines get, so the hash is pinned against the download rather than a local
# copy (a local `~` path would need `--impure` and break the moment the file
# moves).
{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
}: let
  pname = "roto-setup";
  version = "3.2.1";
in
  appimageTools.wrapType2 (
    finalAttrs: let
      # The vendor's entry runs `AppRun --no-sandbox`; not needed here. Inside
      # the FHS env Chromium starts with its namespace sandbox intact (verified:
      # no `--no-sandbox` in any child's cmdline and the app comes up), so the
      # flag would only weaken it.
      # `desktopItems` is NOT honoured by buildFHSEnv in this nixpkgs (it is
      # silently ignored), so the entry is installed by hand below.
      desktopItem = makeDesktopItem {
        name = pname;
        exec = "${pname} %U";
        icon = pname;
        desktopName = "ROTO-SETUP";
        comment = "Firmware and controller setup for the Melbourne Instruments ROTO-CONTROL";
        categories = ["Utility" "Settings"];
        startupWMClass = "ROTO-SETUP";
      };
    in {
      inherit pname version;

      src = fetchurl {
        url = "https://update.melbourneinstruments.com/roto-control/ROTO-SETUP-${finalAttrs.version}-x64.AppImage";
        hash = "sha256-Ye/miLuLUE+o6r1FH2x9sNyAj8XR85edjbPhDdq/bYY=";
      };

      extraInstallCommands = ''
        install -Dm444 ${finalAttrs.contents}/roto-setup.png \
          $out/share/icons/hicolor/512x512/apps/${pname}.png
        install -Dm444 ${desktopItem}/share/applications/${pname}.desktop \
          $out/share/applications/${pname}.desktop
      '';

      meta = with lib; {
        description = "Companion app for the Melbourne Instruments ROTO-CONTROL controller";
        homepage = "https://www.melbourneinstruments.com/roto";
        license = licenses.unfree;
        sourceProvenance = with sourceTypes; [binaryNativeCode];
        platforms = ["x86_64-linux"];
        mainProgram = pname;
      };
    }
  )
