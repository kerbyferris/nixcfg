# omp-commandcode-plugin — Command Code model provider for Oh My Pi (omp)
#
# Fetched from npm registry. Has only devDependencies (type-only imports
# provided by the omp runtime), so no npm install needed — just unpack.
#
# Auto-discovered by omp from ~/.omp/plugins/node_modules/ via the
# `omp.extensions` field in package.json.
#
# Auth is handled by omp's native /login OAuth flow — no API key in env vars.
# Model IDs use the `commandcode/<id>` prefix (e.g. commandcode/deepseek/deepseek-v4-flash).
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "omp-commandcode-plugin";
  version = "0.1.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/oh-my-pi-plugin-command-code/-/oh-my-pi-plugin-command-code-${version}.tgz";
    hash = "sha256-LIEQfLFax17EzKlhrK0wLIfhmx9uj2N5ki7ulIvo2ks=";
  };

  installPhase = ''
    cp -r . $out
  '';

  meta = {
    description = "Oh My Pi plugin: Command Code model provider with native OAuth login";
    homepage = "https://github.com/metaphorics/oh-my-pi-plugin-command-code";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
