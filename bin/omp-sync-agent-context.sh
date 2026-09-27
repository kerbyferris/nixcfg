#!/usr/bin/env bash
# omp-sync-agent-context.sh — vault <-> Pi sync + AGENTS.md compile (NixOS OMP agent)
#
# Rewritten 2026-09-27 after the 2026-09-12 incident, in which this script's
# `git stash --include-untracked -- _agents/` dance left uncommitted agent edits
# stranded in a stash (PROJECTS.md reverted to an older committed version) and left
# merge-conflict markers in the live context files, while Dropbox minted 81
# "(nixos's conflicted copy …)" files alongside them.
#
# New order of operations:
#   1. refuse to run if conflict markers are already present in _agents/
#   2. COMMIT dirty state first (whole vault) — nothing depends on a stash surviving
#   3. `git pull --rebase --autostash`; on conflict: abort the rebase, report, exit
#   4. push if ahead of upstream
#   5. compile ~/.omp/agent/AGENTS.md from the live files (always)
#
# Silent on a no-op run so cron stays quiet. Log: ~/.local/state/omp-agent-context-sync.log
# Related: Dropbox is told to ignore .git via the user.com.dropbox.ignored xattr.

set -u

VAULT_DIR="$HOME/Dropbox/obsidian/fruit-fruit-studio"
AGENTS_DIR="$VAULT_DIR/_agents"
OMP_AGENTS_FILE="$HOME/.omp/agent/AGENTS.md"
LOG="$HOME/.local/state/omp-agent-context-sync.log"
GIT_ID=(-c user.name="Fruit Fruit" -c user.email="fruitfruitstudio@gmail.com")

mkdir -p "$(dirname "$LOG")"
say() { echo "$*"; }
log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG"; }

cd "$VAULT_DIR" || { say "vault dir missing: $VAULT_DIR"; exit 1; }

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { say "not a git repo: $VAULT_DIR"; exit 1; }

# 1. never operate on a file with unresolved conflicts
markers=$(grep -rlE '^(<<<<<<<|>>>>>>>) ' "$AGENTS_DIR" --include='*.md' 2>/dev/null || true)
if [ -n "$markers" ]; then
  msg="REFUSING: conflict markers in _agents/ — resolve them first: $(echo "$markers" | tr '\n' ' ')"
  log "$msg"; say "$msg"; exit 2
fi

# 2. commit first (stash-free)
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  if git "${GIT_ID[@]}" commit -q -m "sync: vault snapshot [$(hostname -s)] $(date '+%F %H:%M')"; then
    say "Committed local vault changes ($(git rev-parse --short HEAD))"
  fi
fi

# 3. integrate remote work (autostash handles any incidental dirt, e.g. Obsidian's workspace file)
before=$(git rev-parse HEAD)
if ! git pull --rebase --autostash --quiet origin "$branch"; then
  git rebase --abort >/dev/null 2>&1 || true
  msg="ERROR: pull --rebase failed — rebase aborted, nothing pushed. Inspect $VAULT_DIR by hand."
  log "$msg"; say "$msg"; exit 3
fi
after=$(git rev-parse HEAD)
if [ "$before" != "$after" ]; then
  say "Pulled $(git rev-list --count "$before..$after") commit(s) from the Pi"
fi

# 4. publish
ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
if [ "$ahead" -gt 0 ]; then
  if git push --quiet origin HEAD; then
    say "Pushed $ahead commit(s) to the Pi"
  else
    msg="ERROR: push failed — local commits are intact, retry on the next tick."
    log "$msg"; say "$msg"
  fi
fi

# 5. compile the OMP agent context (excluding setup docs)
compile_agents() {
  local content content_hash old_hash
  content=$(
    cat \
      "$AGENTS_DIR/PREFERENCES.md" \
      "$AGENTS_DIR/INFRA.md" \
      "$AGENTS_DIR/RULES.md" \
      "$AGENTS_DIR/PROJECTS.md" \
      "$AGENTS_DIR/NIXOS_AGENT.md" \
      2>/dev/null
  )
  mkdir -p "$(dirname "$OMP_AGENTS_FILE")"
  old_hash=$(md5sum "$OMP_AGENTS_FILE" 2>/dev/null | cut -d' ' -f1 || echo "")
  content_hash=$(printf '%s' "$content" | md5sum | cut -d' ' -f1)
  if [ "$old_hash" != "$content_hash" ]; then
    printf '%s' "$content" > "$OMP_AGENTS_FILE"
    say "Updated OMP AGENTS.md ($(wc -c < "$OMP_AGENTS_FILE") bytes)"
    log "recompiled AGENTS.md ($(wc -c < "$OMP_AGENTS_FILE") bytes)"
  fi
}
compile_agents
exit 0
