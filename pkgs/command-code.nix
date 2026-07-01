# command-code — Command Code CLI for OAuth login and API access
#
# Fetched from npm registry, production dependencies installed.
# Provides the `commandcode` binary for OAuth login flow.
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
  python3,
}: let
  version = "0.33.0";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/command-code/-/command-code-${version}.tgz";
    hash = "sha256-/mPrYPcD2qsYbMojqjaBgs7BKgGx/KwCXSqIUGz02B0=";
  };
in
  buildNpmPackage rec {
    pname = "command-code";
    inherit version;

    src = tarball;

    # No lockfile in the npm tarball — use buildNpmPackage's auto-resolution
    npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will fail first time, then get correct hash

    buildPhase = "true";

    installPhase = ''
      mkdir -p $out/lib/node_modules/command-code
      cp -r . $out/lib/node_modules/command-code/
      mkdir -p $out/bin
      ln -s $out/lib/node_modules/command-code/dist/index.mjs $out/bin/commandcode
      ln -s $out/lib/node_modules/command-code/dist/index.mjs $out/bin/cmdc
    '';

    meta = {
      description = "Command Code CLI — coding agent and OAuth client for the Command Code API";
      homepage = "https://commandcode.ai";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  }
