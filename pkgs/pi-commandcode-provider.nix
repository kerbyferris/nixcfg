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
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "patlux";
    repo = "pi-commandcode-provider";
    rev = "4b6e1cd85af0481b4a3433d919ceb841363a8ef2";
    hash = "sha256-Q8QqhEWWUSTneUV9oTKXWch7XTUOoOW1UpqgRtQi14s=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-l0hoR4vpMmV/x9Q8LtCB5/iNCV3t2414j8GkLe1H6ZA=";
  };

  # Command Code API rejects `null` for these optional fields; must be empty strings
  postPatch = ''
    substituteInPlace src/core.ts \
      --replace-fail 'memory: null,' 'memory: "",' \
      --replace-fail 'taste: null,' 'taste: "",' \
      --replace-fail 'skills: null,' 'skills: "",'
  '';

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
