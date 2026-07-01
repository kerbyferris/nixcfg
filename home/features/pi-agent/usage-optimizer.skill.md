---
name: usage-optimizer
description: |
  Monitors OpenRouter usage and optimizes the four-tier model topology
  based on actual spend patterns. Adjusts routing so expensive models
  are only used when genuinely needed.
---

# Usage Optimizer

This machine has a four-tier model topology configured in `modelRoles`:

| Role | Model | Cost/M in | Cost/M out |
|---|---|---|---|
| `default` | DeepSeek V4 Pro (via Command Code) | unknown | unknown |
| `slow` | Claude Sonnet 4.6 | $3.00 | $15.00 |
| `smol` / `task` | Qwen2.5-Coder-3B (local) | $0.00 | $0.00 |
| mac fallback | Qwen2.5:14b-64k (tunnel) | $0.00 | $0.00 |

The optimizer's goal is to keep the monthly OpenRouter spend as low as possible
while ensuring `slow` is used when the default model isn't sufficient.

**Always available models (zero cost):**
- Local 3B (smol/task): always on, fastest response
- Tunneled 14B (mac): free fallback, slower

## Checking Usage

The agent can check OpenRouter usage at any time:

```bash
OR_KEY=$(python3 -c "import sys,json; j=json.load(open('/home/kerby/.local/share/opencode/auth.json')); print(j['openrouter']['key'])")
curl -s -H "Authorization: Bearer \$OR_KEY" https://openrouter.ai/api/v1/auth/key
```

The response includes `usage_monthly` (total $ spent this month) and
`limit_remaining` (remaining credit). If the key is not in opencode's auth.json,
use `~/.config/opencode/config.yaml` instead.

## Optimization Rules

**Monthly budget: $5 on OpenRouter.** Spend patterns to watch for:

1. **Slow model overuse.** If Claude Sonnet spend exceeds 20% of total,
   the agent should re-examine whether it's being used for tasks that V4 Pro
   could handle. Consider lowering the `slow` thinking level or switching
   to a cheaper fallback.

2. **Pro doing heavy lifting.** If DeepSeek V4 Pro is consistently consuming
   large token volumes for tasks that could use the local 3B, consider
   switching those subagent tasks to `smol`/`task` roles.

3. **Subagent routing.** If `smol`/`task` models are generating poor results,
   consider dropping the `modelRoles.smol` thinking level from `:minimal`
   to `:low` or `:medium`.

4. **Credit running low.** If `limit_remaining` drops below $1, suggest
   topping up or shifting more work to the free local/tunneled models until
   the account is refilled.

## Automatic Adjustments

When usage data reveals an imbalance, the agent SHOULD:

1. Suggest any changes to `modelRoles` in the nix config.
2. Run `alejandra .` and `sudo nixos-rebuild switch --flake .#nixos --impure`
   to apply the changes.
3. Update this topology documentation in AGENTS.md to match.

Do NOT change the seed config without also committing the updated AGENTS.md.
