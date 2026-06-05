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
# Pi agent extensions and skills managed here:
#   - hermes-ssh.ts — SSH bridge to the Raspberry Pi agent (Hermes)
#   - tavily-web-search.ts — Web search via Tavily API (TAVILY_API_KEY)
#   - pre-commit-hook.skill.md — Skill to install pre-commit secret scanner
#   - ollama-tunnel — systemd user service: SSH tunnel to mac's ollama (qwen2.5:14b-64k)
#     via autossh, exposing the remote model server at localhost:11435 for explicit discovery
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
      smol: ollama/qwen2.5-coder:3b:minimal
      task: ollama/qwen2.5-coder:3b:minimal
      slow: openrouter/anthropic/claude-sonnet-4.6:high
    memory:
      backend: mnemopi
    mnemopi:
      scoping: per-project-tagged
      noEmbeddings: true
  '';

  # Seed models.yml for ~/.omp/agent/models.yml — registers mac's ollama at the tunnel port.
  seedModels = pkgs.writeText "omp-models-seed" ''
    # Seeded by home-manager — mac's ollama via SSH tunnel (localhost:11435).
    # Local ollama at localhost:11434 is auto-discovered by omp's implicit discovery.
    providers:
      ollama-mac:
        baseUrl: http://127.0.0.1:11435
        api: openai-responses
        auth: none
        discovery:
          type: ollama
  '';
in {
  # autossh is required for the persistent SSH tunnel to mac's ollama
  home.packages = with pkgs; [
    autossh
  ];
  # Manage ~/.pi/agent/extensions/hermes-ssh.ts — the Hermes SSH bridge extension.
  # Declarative: edit ~/nixcfg/home/features/pi-agent/hermes-ssh.ts, then rebuild.
  home.file."${extensionDir}/hermes-ssh.ts".source = ./hermes-ssh.ts;

  # Manage ~/.pi/agent/extensions/tavily-web-search.ts — Web search via Tavily API.
  # Uses TAVILY_API_KEY from /run/secrets/agent-env (sops-managed).
  home.file."${extensionDir}/tavily-web-search.ts".source = ./tavily-web-search.ts;

  # Manage agent skills at ~/.omp/agent/skills/ — instructional markdown files
  # the agent reads on startup to guide its behavior.
  home.file.".omp/agent/skills/pre-commit-hook.skill.md".source = ./pre-commit-hook.skill.md;
  home.file.".omp/agent/skills/usage-optimizer.skill.md".source = ./usage-optimizer.skill.md;

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

  # Manage ~/.omp/agent/models.yml — registers the mac ollama provider (via SSH tunnel).
  # The local ollama at localhost:11434 is auto-discovered by omp's implicit discovery.
  home.file.".omp/agent/models.yml".source = seedModels;

  # ~/.omp/agent/config.yml is NOT managed via home.file (it must be writable
  # at runtime for provider settings from /login). Instead, the activation
  # script seeds it on first install and ensures memory config on subsequent
  # rebuilds without overwriting runtime changes.
  systemd.user.services.ollama-tunnel = {
    Unit = {
      Description = "SSH tunnel to mac ollama (qwen2.5:14b-64k)";
      After = ["network.target"];
      Wants = ["network.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.autossh}/bin/autossh -M 0 -N -L 11435:localhost:11434 mac -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
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
