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

## Secret Safety

This repo has a pre-commit hook in `.githooks/pre-commit` that scans staged
additions for common API key patterns (OpenRouter, Tavily, GitHub tokens, AWS
keys, and generic `*_KEY=` assignments). It also verifies that sops-encrypted
files are actually age-encrypted before commit.

If you're cloning fresh, activate the hook:
```bash
git config core.hooksPath .githooks
```

To bypass when you know the match is a false positive (e.g. env var name in
comments, test fixture, regex example):
```bash
git commit --no-verify
```

Key import chain: `hosts/users/kerby.nix` → `../../../home/kerby/${hostName}.nix` → `../common` + `../features/**` + `./home.nix`

### SOPS Secrets

API keys and secrets are managed via [sops-nix](https://github.com/Mic92/sops-nix)
using age encryption derived from SSH keys.

- **Edit a secret**: `cd ~/nixcfg && nix run nixpkgs#sops hosts/nixos/secrets/secrets.yaml`
  This opens the encrypted file in `$EDITOR`. On save, sops re-encrypts for all
  authorized recipients defined in `.sops.yaml`.
- **Add a new secret**: Declare it in `sops.secrets.<name>` in
  `hosts/nixos/configuration.nix` and add the key to `secrets.yaml` via the edit
  command above.
- **Add a recipient**: Generate an age public key from an SSH key, add it to
  `.sops.yaml`, then re-encrypt existing files with
  `nix run nixpkgs#sops -- updatekeys hosts/nixos/secrets/secrets.yaml`.
- **Decrypted paths**: Secrets appear at `/run/secrets/<name>`, owned by
  `root:root` with mode `0400`. Use `sops.secrets.<name>.owner` to change
  ownership (requires the user/group to already exist at activation time).
- **Key files**:
  - Admin age identity: `~/.config/sops/age/keys.txt` (derived from
    `~/.ssh/id_ed25519` via `ssh-to-age`)
  - Machine identity: `/etc/ssh/ssh_host_ed25519_key` (imported automatically by
    `sops-install-secrets` at boot)

Usage pattern for a systemd service that needs env vars:
```nix
sops.secrets."agent-env" = {};
systemd.services.my-service = {
  serviceConfig.EnvironmentFile = [ config.sops.secrets."agent-env".path ];
};
```

## Conventions

- State version locked to **24.11** for both NixOS and Home Manager. Do not bump without explicit instruction.
- Feature flags: `hosts/features/default.nix` aggregates system-level toggles; individual hosts enable them via `features.<name>.enable = true`
- `specialArgs.{inputs, outputs}` is passed to all NixOS modules — `inputs` and `outputs` are available in module arguments
- Custom packages are exported for 5 systems (`x86_64-linux`, `aarch64-linux`, `i686-linux`, `x86_64-darwin`, `aarch64-darwin`) but only `x86_64-linux` is actually used
- `allowUnfree = true` is set in the flake's package exports

## Declarative Configuration

**All changes to this machine's configuration must be made by editing Nix files
under ~/nixcfg/ and running `sudo nixos-rebuild switch --flake .#nixos`.** Never
edit files under ~/.pi/, ~/.config/, ~/.local/, or other runtime paths directly —
those are managed by Nix/home-manager and will be overwritten on the next rebuild.

### Agent Extensions

PI agent extensions live in `home/features/pi-agent/`:
- `default.nix` — home-manager module: manages ~/.pi/agent/extensions/ and settings.json
- `hermes-ssh.ts` — SSH bridge to the Raspberry Pi (Hermes). Activate with `pi --hermes`

To add a new extension: drop the `.ts` file in `home/features/pi-agent/` and add a
`home.file` entry in `default.nix`. Then rebuild.

### Rebuild Checklist
1. `alejandra .` (format all .nix files)
2. `sudo nixos-rebuild switch --flake .#nixos --impure`
3. Fix any errors before making further changes
