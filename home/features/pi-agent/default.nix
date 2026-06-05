# Pi agent (Oh My Pi) configuration.
#
# This machine's system configuration is managed declaratively via this Nix
# flake. All changes to ~/nixcfg/ are applied with `sudo nixos-rebuild switch
# --flake .#nixos` (or the helper at bin/nix-rebuild.sh). This includes:
#
#   - Installed packages (home.packages)
#   - Dotfiles and config files (home.file)
#   - System services and programs (programs.*)
#
# Any agent modifying this machine's configuration MUST edit the Nix files in
# ~/nixcfg/ and rebuild — never edit files under ~/.pi/, ~/.config/, or other
# runtime paths directly. Direct edits will be overwritten on the next rebuild.
#
# Pi agent extensions managed here:
#   - hermes-ssh.ts — SSH bridge to the Raspberry Pi agent (Hermes)
#   - settings.json — provider, model, and extension defaults
{
  config,
  lib,
  pkgs,
  ...
}: let
  extensionDir = "${config.home.homeDirectory}/.pi/agent/extensions";

  # Seed config for ~/.omp/agent/config.yml — used on first install only.
  # After that the agent owns the file; rebuilds only ensure memory config.
  seedConfig = pkgs.writeText "omp-config-seed" ''
    # Seeded by home-manager — agent may modify at runtime.
    symbolPreset: nerd
    theme:
      dark: dark-gruvbox
    setupVersion: 1
    hideThinkingBlock: true
    modelRoles:
      default: opencode-go/deepseek-v4-flash
    memory:
      backend: mnemopi
    mnemopi:
      scoping: per-project-tagged
      noEmbeddings: true
  '';
in {
  # Manage ~/.pi/agent/extensions/hermes-ssh.ts — the Hermes SSH bridge extension.
  # Declarative: edit ~/nixcfg/home/features/pi-agent/hermes-ssh.ts, then rebuild.
  home.file."${extensionDir}/hermes-ssh.ts".source = ./hermes-ssh.ts;

  # Manage ~/.pi/agent/settings.json — provider config and extension defaults.
  # The `hermes` flag is left unset by default; pass `--hermes` at runtime to
  # activate the SSH bridge. To make it persistent, add it to `flags` below.
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    # Extensions in auto-discovered paths are hot-reloadable with /reload

    # Provider defaults (set manually or via /login)
    defaultProvider = "openrouter";
    defaultModel = "openrouter/free";
    defaultThinkingLevel = "high";

    # Uncomment to always activate Hermes bridge on startup:
    # flags = {
    #   hermes = "";
    # };
  };

  # ~/.omp/agent/config.yml is NOT managed via home.file (it must be writable
  # at runtime for provider settings from /login). Instead, the activation
  # script seeds it on first install and ensures memory config on subsequent
  # rebuilds without overwriting runtime changes.
  home.activation.ensureAgentConfig = config.lib.dag.entryAfter ["writeBoundary"] ''
    cfg="$HOME/.omp/agent/config.yml"
    if [ ! -f "$cfg" ] || [ -L "$cfg" ]; then
      cp -f ${seedConfig} "$cfg" && chmod 644 "$cfg"
    elif ! ${pkgs.gnugrep}/bin/grep -q 'backend: mnemopi' "$cfg" 2>/dev/null; then
      # Migrate existing config from 'local' backend to mnemopi
      ${pkgs.gnused}/bin/sed -i '/^memory:/,/^[a-z]/ { /^memory:/d; s/backend:.*/  backend: mnemopi/; }' "$cfg"
      if ! ${pkgs.gnugrep}/bin/grep -q '^mnemopi:' "$cfg" 2>/dev/null; then
        printf '\nmnemopi:\n  scoping: per-project-tagged\n  noEmbeddings: true\n' >> "$cfg"
      fi
    fi
  '';
}
