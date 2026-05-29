#!/usr/bin/env bash
set -euo pipefail

# pi-coding-agent version checker — queries GitHub releases API for newer tags

OVERLAY_FILE="${OVERLAY_FILE:-overlays/default.nix}"

# Extract current pinned version
current_version() {
  awk '/pi-coding-agent = prev.pi-coding-agent/,/};/' "$OVERLAY_FILE" \
    | grep -oP 'version = "\K[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1
}

# Fetch latest release from GitHub API
latest_release() {
  curl -sL "https://api.github.com/repos/earendil-works/pi/releases/latest" 2>/dev/null \
    | jq -r '.tag_name' \
    | sed 's/^v//'
}

# Fetch the SRI hash for a given version tag
fetch_hash() {
  local version="$1"
  local base32
  base32=$(nix-prefetch-url --unpack \
    "https://github.com/earendil-works/pi/archive/refs/tags/v${version}.tar.gz" 2>/dev/null)
  nix hash to-sri --type sha256 "$base32" 2>/dev/null
}

# Fetch npmDepsHash for a given version tag
fetch_npm_hash() {
  local version="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  curl -sL -o "$tmpdir/pi-${version}.tar.gz" \
    "https://github.com/earendil-works/pi/archive/refs/tags/v${version}.tar.gz" 2>/dev/null
  tar -xzf "$tmpdir/pi-${version}.tar.gz" -C "$tmpdir"

  nix run nixpkgs#prefetch-npm-deps -- \
    "$tmpdir/pi-${version}/package-lock.json" 2>/dev/null
}

# Main
CURRENT=$(current_version)
LATEST=$(latest_release)

echo "Current pinned version: $CURRENT"
echo "Latest GitHub release:  $LATEST"

if [[ "$LATEST" == "$CURRENT" ]]; then
  echo ""
  echo "✅ Already on latest."
  exit 0
fi

echo ""
echo "🎉 Newer version found: $LATEST"
echo ""
echo "Fetching hashes..."
echo ""

SRC_HASH=$(fetch_hash "$LATEST")
echo "src hash:    $SRC_HASH"

NPM_HASH=$(fetch_npm_hash "$LATEST")
echo "npmDepsHash: $NPM_HASH"

echo ""
echo "Update overlays/default.nix pi-coding-agent block with:"
echo ""
cat <<EOF
      version = "$LATEST";
      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        rev = "v$LATEST";
        hash = "$SRC_HASH";
      };
      npmDeps = final.fetchNpmDeps {
        src = newSrc;
        name = "pi-coding-agent-${LATEST}-npm-deps";
        hash = "$NPM_HASH";
      };
      npmDepsHash = "$NPM_HASH";
EOF
