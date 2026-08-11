# immich-go — pre-built Go binary for Immich import/export
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}: let
  version = "0.32.0";
  srcs = {
    x86_64-linux = fetchurl {
      url = "https://github.com/simulot/immich-go/releases/download/v${version}/immich-go_Linux_x86_64.tar.gz";
      hash = "sha256-birYa6/a25Rm1lFd58uIJybArqGiHVEWTf82HX1ICpc=";
    };
  };
in
  stdenv.mkDerivation {
    pname = "immich-go";
    inherit version;
    src = srcs.${stdenv.hostPlatform.system} or (throw "immich-go not available for ${stdenv.hostPlatform.system}");

    nativeBuildInputs = [autoPatchelfHook];

    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out/bin
      install -m755 immich-go $out/bin/
    '';

    meta = {
      description = "Alternative to the immich-CLI for uploading large photo collections to Immich";
      homepage = "https://github.com/simulot/immich-go";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
      mainProgram = "immich-go";
    };
  }
