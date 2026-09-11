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
#   - pi-commandcode-provider — Command Code API provider (for pi, old; COMMANDCODE_API_KEY)
#   - omp-commandcode-plugin — Command Code model provider for OMP (native /login)
#   - models.yml — custom model providers (Nous Portal)
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

  # Seed config for ~/.omp/agent/config.yml — used on first install only.
  # After that the agent owns the file; rebuilds only ensure memory config.
  seedConfig = pkgs.writeText "omp-config-seed" ''
    # Seeded by home-manager — agent may modify at runtime.
    extensions: []
    symbolPreset: nerd
    theme:
      dark: dark-gruvbox
    setupVersion: 1
    hideThinkingBlock: true
    modelRoles:
      default: opencode-go/deepseek-v4-flash:high
      smol: ollama/qwen2.5-coder:3b:minimal
      task: ollama/qwen2.5-coder:3b:minimal
      slow: openrouter/anthropic/claude-sonnet-4.6:high
      vision: openrouter/google/gemini-2.5-flash:high
    memory:
      backend: mnemopi
    mnemopi:
      scoping: per-project-tagged
      noEmbeddings: true
  '';

  # Seed settings for ~/.pi/agent/settings.json — used on first install only.
  seedSettings = pkgs.writeText "pi-settings-seed" ''
    {
      "providerSettings": {}
    }
  '';

  # Seed models.yml for ~/.omp/agent/models.yml — custom providers.
  # IMPORTANT: map form (provider-id key), NOT list form (`- id:`). OMP's schema
  # silently rejects list-form entries and skips the whole file.
  # Nous Portal inference API — OpenAI-compatible. Key in ~/.omp/agent/.env as
  # NOUS_API_KEY (sops agent-env). discovery pulls the full 370+ model catalog
  # from /v1/models at runtime; explicit models below guarantee the Nous family
  # is selectable even if discovery is unavailable.
  seedModels = pkgs.writeText "omp-models-seed" ''
    providers:
      nous:
        baseUrl: https://inference-api.nousresearch.com/v1
        api: openai-completions
        apiKey: NOUS_API_KEY
        authHeader: true
        discovery:
          type: openai-models-list
        models:
          - id: nousresearch/hermes-4-70b
            name: Hermes 4 70B
            contextWindow: 131072
            maxTokens: 131072
          - id: nousresearch/hermes-4-405b
            name: Hermes 4 405B
            contextWindow: 131072
            maxTokens: 131072
      deepseek:
        baseUrl: https://api.deepseek.com
        api: openai-completions
        apiKey: DEEPSEEK_API_KEY
        models:
          - id: deepseek-v4-flash
            name: DeepSeek V4 Flash
          - id: deepseek-v4-pro
            name: DeepSeek V4 Pro
  '';
in {
  # Manage ~/.pi/agent/extensions/hermes-ssh.ts — the Hermes SSH bridge extension.
  # Declarative: edit ~/nixcfg/home/features/pi-agent/hermes-ssh.ts, then rebuild.
  home.file."${extensionDir}/hermes-ssh.ts".source = ./hermes-ssh.ts;

  # Manage ~/.pi/agent/extensions/tavily-web-search.ts — Web search via Tavily API.
  # Uses TAVILY_API_KEY from /run/secrets/agent-env (sops-managed).
  home.file."${extensionDir}/tavily-web-search.ts".source = ./tavily-web-search.ts;

  # Manage ~/.pi/agent/extensions/pi-commandcode-provider/ — Command Code API provider (for pi, old).
  # Uses COMMANDCODE_API_KEY from /run/secrets/agent-env (sops-managed).
  home.file."${extensionDir}/pi-commandcode-provider".source = pkgs.pi-commandcode-provider;

  # OMP plugin: oh-my-pi-plugin-command-code — Command Code model provider with
  # native OAuth /login. Auto-discovered from ~/.omp/plugins/node_modules/ via
  # the `omp.extensions` field in package.json. No API key in env vars needed.
  # Model IDs use the `commandcode/<id>` prefix (e.g. commandcode/deepseek/deepseek-v4-flash).
  home.file.".omp/plugins/node_modules/oh-my-pi-plugin-command-code".source = pkgs.omp-commandcode-plugin;

  # Manage ~/.omp/agent/commands/huly.md — file-based slash command for issue triage.
  home.file.".omp/agent/commands/huly.md".source = ./huly.md;

  # Manage agent skills at ~/.omp/agent/skills/ — instructional markdown files
  # the agent reads on startup to guide its behavior.
  home.file.".omp/agent/skills/pre-commit-hook.skill.md".source = ./pre-commit-hook.skill.md;
  home.file.".omp/agent/skills/usage-optimizer.skill.md".source = ./usage-optimizer.skill.md;
  home.file.".omp/agent/skills/huly-triage.skill.md".source = ./huly-triage.skill.md;
  home.file.".omp/agent/keybindings.json".text = builtins.toJSON {
    "app.exit" = [];
  };
  # Manage ~/.omp/agent/models.yml — custom providers (see seedModels above).
  # The local ollama at localhost:11434 is auto-discovered by omp's implicit discovery.
  home.file.".omp/agent/models.yml".source = seedModels;
  # Manage ~/bin/huly — CLI for quick Huly issue lookup from the terminal.
  # Installed as a script so it's in PATH for ad-hoc issue triage.
  home.file."bin/huly" = {
    source = ./huly-cli.cjs;
    executable = true;
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
    # Seed ~/.pi/agent/settings.json on first install (must be writable at runtime)
    pisettings="$HOME/.pi/agent/settings.json"
    if [ ! -f "$pisettings" ] || [ -L "$pisettings" ]; then
      cp -f ${seedSettings} "$pisettings" && chmod 644 "$pisettings"
    fi
  '';
}
