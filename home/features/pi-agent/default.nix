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
in {
  # Manage ~/.pi/agent/extensions/hermes-ssh.ts — the Hermes SSH bridge extension.
  # Declarative: edit ~/nixcfg/home/features/pi-agent/hermes-ssh.ts, then rebuild.
  home.file."${extensionDir}/hermes-ssh.ts".source = ./hermes-ssh.ts;

  # Manage ~/.omp/agent/config.yml — agent runtime settings (theme, models, memory).
  # WARNING: runtime edits to this file are overwritten on the next nixos-rebuild.
  # To make permanent changes, edit home/features/pi-agent/omp-config.yml and rebuild.
  home.file.".omp/agent/config.yml".source = ./omp-config.yml;

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
}
