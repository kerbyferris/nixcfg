# Bitwig Studio Upgrade Process

## Overview

Bitwig is pinned in `overlays/default.nix` under `modifications` as an overlay on
`nixpkgs`'s `bitwig-studio6` package. The overlay overrides `version`, `src`
(download URL), and `hash` — everything else comes from the nixpkgs derivation.

The FHS wrapper (`pkgs/bitwig-fhs.nix`) and desktop entry (`home/features/audio/default.nix`)
just reference `bitwig-studio6`; they don't need changes for version bumps.

## Files involved

|File|Role|
|---|---|
|`overlays/default.nix:19-26`|Version, URL, and hash — the only file that changes|
|`bin/check-bitwig-update.sh`|Helper: probes Bitwig's download servers for newer versions and fetches the hash|
|`pkgs/bitwig-fhs.nix`|FHS env wrapper (version-agnostic)|

## Step-by-step

### 1. Find the latest version

```bash
# Run the helper — it probes for versions newer than the pinned one
cd ~/nixcfg
bash bin/check-bitwig-update.sh
```

This prints the current pinned version, the latest public version from the download
page, and any intermediate versions found by probing URLs.

If the script finds a newer version it will attempt to fetch the hash. If it times
out (the `.deb` is ~300 MB), do it manually:

```bash
# Check if a specific version exists (HTTP 200 = yes)
curl -sIL "https://www.bitwig.com/dl/Bitwig%20Studio/<VERSION>/installer_linux" \
  | grep -i '^HTTP' | tail -1

# Fetch the hash
nix-prefetch-url \
  "https://www.bitwig.com/dl/Bitwig%20Studio/<VERSION>/installer_linux" \
  --name "bitwig-studio-<VERSION>.deb"
```

### 2. Convert the hash to SRI format

```bash
nix hash to-sri --type sha256 <RAW_HASH>
```

(The `nix-prefetch-url` output is the raw base32 hash — you need the `sha256-...` form.)

### 3. Update `overlays/default.nix`

Edit lines 19–26 — three fields change:

```nix
bitwig-studio6 = prev.bitwig-studio6.overrideAttrs (oldAttrs: {
  version = "<VERSION>";                                   # e.g. "6.0.11"
  src = final.fetchurl {
    name = "bitwig-studio-<VERSION>.deb";                  # e.g. "bitwig-studio-6.0.11.deb"
    url = "https://www.bitwig.com/dl/Bitwig%20Studio/<VERSION>/installer_linux";
    hash = "<SRI_HASH>";                                   # e.g. "sha256-rnr/Z8..."
  };
});
```

### 4. Rebuild

```bash
cd ~/nixcfg
alejandra .
sudo nixos-rebuild switch --flake .#nixos --impure
```

## What the helper script automates

`bin/check-bitwig-update.sh`:
1. Extracts the current pinned version from `overlays/default.nix`
2. Scrapes `bitwig.com/download/` for the latest public version
3. Probes download URLs for intermediate versions (patch → minor increments)
4. Fetches the SRI hash for the newest found version
5. Prints the overlay snippet ready to paste

It does **not** edit files or rebuild — those steps are manual.

## Notes

- Bitwig uses the pattern `6.0.x` for patch releases. Major/minor version changes
  (e.g. `6.1` or `7.0`) may need the download page URL pattern updated in the helper
  script — so far all 6.x releases have followed it.
- The `--impure` flag is required because `bitwig-connect-control-panel` references
  an absolute path outside the flake (see `AGENTS.md`).
- The FHS wrapper rebuilds automatically because it depends on `bitwig-studio6`.
  No changes needed in `bitwig-fhs.nix` or the desktop entry.
