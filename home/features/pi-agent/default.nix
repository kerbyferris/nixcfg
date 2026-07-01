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
#   - pi-commandcode-provider — Command Code API provider (COMMANDCODE_API_KEY)
#   - pre-commit-hook.skill.md — Skill to install pre-commit secret scanner
#   - ollama-tunnel — systemd user service: SSH tunnel to mac's ollama (qwen2.5:14b-64k)
#     via autossh, exposing the remote model server at localhost:11435 for explicit discovery
#
# ~/.pi/agent/settings.json is NOT managed via home.file (it must be writable
# at runtime for provider settings). The activation script seeds it on first
# install without overwriting runtime changes, same as ~/.omp/agent/config.yml.
{
  config,
  lib,
  pkgs,
  ...
}: let
  extensionDir = "${config.home.homeDirectory}/.pi/agent/extensions";
  ompExtensionDir = "${config.home.homeDirectory}/.omp/agent/extensions";

  # Seed config for ~/.omp/agent/config.yml — used on first install only.
  # After that the agent owns the file; rebuilds only ensure memory config.
  seedConfig = pkgs.writeText "omp-config-seed" ''
    # Seeded by home-manager — agent may modify at runtime.
    extensions:
      - /home/kerby/.omp/agent/extensions/commandcode-omp.ts
    symbolPreset: nerd
    theme:
      dark: dark-gruvbox
    setupVersion: 1
    hideThinkingBlock: true
    modelRoles:
      default: commandcode/deepseek/deepseek-v4-flash:high
      smol: ollama/qwen2.5-coder:3b:minimal
      task: ollama/qwen2.5-coder:3b:minimal
      slow: openrouter/anthropic/claude-sonnet-4.6:high
    memory:
      backend: mnemopi
    mnemopi:
      scoping: per-project-tagged
      noEmbeddings: true
  '';

  # Seed settings for ~/.pi/agent/settings.json — used on first install only.
  seedSettings = pkgs.writeText "pi-settings-seed" ''
    {
      "defaultProvider": "openrouter",
      "defaultModel": "openrouter/free",
      "defaultThinkingLevel": "high"
    }
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

  # Manage ~/.pi/agent/extensions/pi-commandcode-provider/ — Command Code API provider.
  # Symlinked as a subdirectory with package.json (pi.extensions), so pi auto-discovers
  # it in extensions/ (unlike node_modules/ which is skipped during auto-discovery).
  # Uses COMMANDCODE_API_KEY from /run/secrets/agent-env (sops-managed).
  home.file."${extensionDir}/pi-commandcode-provider".source = pkgs.pi-commandcode-provider;

  # Manage ~/.omp/agent/settings.json — OMP settings including extension paths.
  # The extensions array tells OMP to load the commandcode provider explicitly.
  home.file.".omp/agent/settings.json".text = ''
    {
      "extensions": ["/home/kerby/.omp/agent/extensions/commandcode-omp.ts"]
    }
  '';
  # OMP-compatible Command Code provider extension — avoids the legacy-pi-ai-shim
  # incompatibility in the Nix-packaged omp binary.
  home.file.".omp/agent/extensions/commandcode-omp.ts".source = ./commandcode-omp.ts;

  # Manage agent skills at ~/.omp/agent/skills/ — instructional markdown files
  # the agent reads on startup to guide its behavior.
  home.file.".omp/agent/skills/pre-commit-hook.skill.md".source = ./pre-commit-hook.skill.md;
  home.file.".omp/agent/skills/usage-optimizer.skill.md".source = ./usage-optimizer.skill.md;

  # Manage ~/.omp/agent/keybindings.json — overrides default keybindings.
  # Setting "app.exit": [] unbinds Ctrl+D from "exit when editor is empty" so
  # that Ctrl+D behaves as delete-char-forward (the default Emacs/Readline
  # binding) instead of accidentally killing the session. Exit via Ctrl+C twice
  # or /quit.
  home.file.".omp/agent/keybindings.json".text = builtins.toJSON {
    "app.exit" = [];
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
    # Seed ~/.pi/agent/settings.json on first install (must be writable at runtime)
    pisettings="$HOME/.pi/agent/settings.json"
    if [ ! -f "$pisettings" ] || [ -L "$pisettings" ]; then
      cp -f ${seedSettings} "$pisettings" && chmod 644 "$pisettings"
    fi
  '';
}
