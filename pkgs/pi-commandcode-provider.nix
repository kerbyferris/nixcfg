# pi-commandcode-provider — Command Code API provider for pi/omp
#
# Fetched from GitHub, production npm dependencies installed, placed in
# ~/.pi/agent/node_modules/ so pi auto-discovers the extension.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
}:
buildNpmPackage rec {
  pname = "pi-commandcode-provider";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "patlux";
    repo = "pi-commandcode-provider";
    rev = "a35c2b1e8301ce6cae4440a1054b974b87fb54c2";
    hash = "sha256-puSMHdv9aDoG4KV5ZLBoXfjbQ6gSeZlaUHgWrya7ZfY=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-gmoaugROC8e4u7Mq7dl/kkWoYq9SwmEg7E9tUa/+TZQ=";
  };

  # Pure TypeScript source — pi loads .ts files via tsx at runtime, no build step
  buildPhase = "true";

  installPhase = ''
    cp -r . $out
  '';

  # Only the source files, node_modules, and package metadata are needed at runtime
  meta = {
    description = "Pi/omp custom provider for the Command Code API — 18 models including Claude, GPT, DeepSeek";
    homepage = "https://github.com/patlux/pi-commandcode-provider";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
