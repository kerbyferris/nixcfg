#!/usr/bin/env bash
set -euo pipefail

# Bitwig version checker — probes Bitwig's download URLs to find newer releases
# than what's currently pinned in overlays/default.nix

OVERLAY_FILE="${OVERLAY_FILE:-overlays/default.nix}"

# Extract current pinned Bitwig version from overlay
current_version() {
  awk '/bitwig-studio6 = prev.bitwig-studio6/,/};/' "$OVERLAY_FILE" \
    | grep -oP 'version = "\K[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1
}

# Check if a version exists on Bitwig's servers
# Follows redirects and checks final HTTP status
version_exists() {
  local version="$1"
  local code
  code=$(curl -sIL "https://www.bitwig.com/dl/Bitwig%20Studio/${version}/installer_linux" 2>/dev/null | grep -i '^HTTP' | tail -1 | grep -oP '\d{3}')
  [[ "$code" == "200" ]]
}

# Get the latest "public" version from the download page
latest_public_version() {
  curl -sL "https://www.bitwig.com/download/" 2>/dev/null \
    | grep -oP 'Bitwig Studio \K[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1
}

# Probe for pre-release versions by incrementing patch, then minor
probe_versions() {
  local base="$1"
  local major minor patch
  major=$(echo "$base" | cut -d. -f1)
  minor=$(echo "$base" | cut -d. -f2)
  patch=$(echo "$base" | cut -d. -f3)

  # Try patch bumps first (most common for pre-releases)
  for p in $(seq $((patch + 1)) $((patch + 5))); do
    local v="${major}.${minor}.${p}"
    if version_exists "$v"; then
      echo "$v"
      return 0
    fi
  done

  # Try next minor version
  for m in $(seq $((minor + 1)) $((minor + 2))); do
    for p in 0 1 2; do
      local v="${major}.${m}.${p}"
      if version_exists "$v"; then
        echo "$v"
        return 0
      fi
    done
  done

  return 1
}

# Fetch the SRI hash for a given version
fetch_hash() {
  local version="$1"
  local base32
  base32=$(nix-prefetch-url \
    "https://www.bitwig.com/dl/Bitwig%20Studio/${version}/installer_linux" \
    --name "bitwig-studio-${version}.deb" 2>/dev/null)
  nix hash to-sri --type sha256 "$base32" 2>/dev/null
}

# Main
CURRENT=$(current_version)
PUBLIC=$(latest_public_version)

echo "Current pinned version: $CURRENT"
echo "Latest public version:  $PUBLIC"

if [[ "$PUBLIC" != "$CURRENT" ]]; then
  echo ""
  echo "⚠️  Public version ($PUBLIC) differs from pinned ($CURRENT)"
  echo "   Public may be newer OR the overlay may be ahead (pre-release)."
fi

echo ""
echo "Probing for newer versions..."
NEWER=$(probe_versions "$CURRENT" || true)

if [[ -n "${NEWER:-}" ]]; then
  echo ""
  echo "🎉 Newer version found: $NEWER"
  echo ""
  echo "Fetching hash..."
  HASH=$(fetch_hash "$NEWER")
  echo ""
  echo "Update overlays/default.nix with:"
  echo ""
  echo "  version = \"$NEWER\";"
  echo "  src = final.fetchurl {"
  echo "    name = \"bitwig-studio-${NEWER}.deb\";"
  echo "    url = \"https://www.bitwig.com/dl/Bitwig%20Studio/${NEWER}/installer_linux\";"
  echo "    hash = \"$HASH\";"
  echo "  };"
else
  echo ""
  echo "✅ No newer versions found. $CURRENT is current."
fi
