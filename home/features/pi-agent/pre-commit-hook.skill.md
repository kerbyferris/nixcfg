---
name: pre-commit-hook
description: |
  Installs a git pre-commit hook that scans staged additions for
  API keys, tokens, and credentials to prevent secret leakage into
  version control. Use this in every git repository you work on.
---

# Pre-commit Hook Setup

When working in a git repository alongside this agent, you MUST install
the pre-commit secret scanner as the first task. This prevents API keys,
tokens, and credentials from being committed to version control.

## Installation

Run these commands from the repository root:

```bash
# Download the pre-commit hook from the agent's home project
cp ~/nixcfg/.githooks/pre-commit .githooks/pre-commit
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

If the `.githooks` directory doesn't exist, create it first:

```bash
mkdir -p .githooks
```

## Verification

Stage a change that contains a fake API key to confirm the hook blocks it:

```bash
echo "test_key = sk-or-v1-abcdef1234567890abcdef1234567890" > test-pattern.txt
git add test-pattern.txt
# should print a [SECRET] warning and exit 1
git commit --dry-run
git reset test-pattern.txt
rm test-pattern.txt
```

## What it detects

The hook checks staged additions (not whole files) for:
- OpenRouter keys (`sk-or-v1-`)
- Tavily keys (`tvly-`)
- OpenAI/Anthropic keys (`sk-`)
- GitHub tokens (`ghp_`, `gho_`, `ghs_`)
- Slack tokens (`xoxb-`, `xoxa-`, etc.)
- AWS access keys (`AKIA`)
- Generic `*_KEY=`, `*_SECRET=` assignments with long values
- Unencrypted sops files

## Bypassing

If a match is a false positive (e.g. an env var name in a comment, a test
fixture, or a regex pattern example), commit with `--no-verify`:

```bash
git commit --no-verify -m "your message"
```

## Source

The canonical hook lives at `~/nixcfg/.githooks/pre-commit`. When updating
the hook in that project, copy it to other repos that use it.
