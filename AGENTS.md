# AGENTS.md

## Build & Rebuild

- Format all `.nix` files before committing: `alejandra .`
- Rebuild `nixos` host: `sudo nixos-rebuild switch --flake .#nixos --impure` (--impure required for vendor .deb at /home/kerby/.local/share/nixcfg-vendor/)
- The helper script `bin/nix-rebuild.sh` chains format → rebuild → git commit with generation metadata

There is no CI, no lint step, and no test suite. A successful `nixos-rebuild switch` is the only validation.

## Architecture

Flake-based NixOS + Home Manager config for the `nixos` laptop. Home Manager is used *only* as a NixOS module — there is no standalone `home-manager switch`.

Module layout:
- `hosts/<host>/` — NixOS system config per machine
- `hosts/common/` — shared system modules (neovim via nixvim, users)
- `hosts/features/` — optional system features gated by `lib.mkEnableOption` + `lib.mkIf cfg.enable`
- `home/kerby/` — user `kerby` home-manager profiles; `home.nix` is shared, `<host>.nix` per host
- `home/common/` — shared home-manager config
- `home/features/` — optional home features (same enable/disable pattern)
- `pkgs/` — custom derivations (vidplayvst, bitwig-fhs)
- `overlays/default.nix` — `additions` (pkgs/), `modifications` (empty), `stable-packages` (from `nixpkgs-stable`)

Key import chain: `hosts/users/kerby.nix` → `../../../home/kerby/${hostName}.nix` → `../common` + `../features/**` + `./home.nix`

## Conventions

- State version locked to **24.11** for both NixOS and Home Manager. Do not bump without explicit instruction.
- Feature flags: `hosts/features/default.nix` aggregates system-level toggles; individual hosts enable them via `features.<name>.enable = true`
- `specialArgs.{inputs, outputs}` is passed to all NixOS modules — `inputs` and `outputs` are available in module arguments
- Custom packages are exported for 5 systems (`x86_64-linux`, `aarch64-linux`, `i686-linux`, `x86_64-darwin`, `aarch64-darwin`) but only `x86_64-linux` is actually used
- `allowUnfree = true` is set in the flake's package exports
