# Huly Issue Triage

When asked to work on a Huly issue, use the Huly MCP tools (list_issues, search_issues, get_issue, update_issue, add_comment, add_relation) to:

1. **Find the issue**: Use `search_issues` with the issue ID (e.g. "TSK-6") or `list_issues` with the project identifier and optional status filter.

2. **Understand the context**: Read the issue title, status, priority, assignee, and description. Check for comments, sub-issues, and related issues.

3. **Work on the task**: Make code changes, infrastructure changes, or whatever the issue requires. Default to taking action rather than asking for permission.

4. **Update the issue**: When done, use `update_issue` to mark the appropriate status (In Progress while working, Done when complete). Use `add_comment` to summarize what was done, including file paths changed, commands run, and verification steps.

5. **Link related issues**: Use `add_relation` to connect this issue to any other issues it relates to.

**Before considering a task done**, verify it works end-to-end — not just that code compiles or tests pass.

The `import-clickup.cjs` script at `~/git/huly-mcp/scripts/import-clickup.cjs` can import ClickUp CSV exports. Run with the CSV path as the only argument.

**MCP connection notes** (from past fixes):
- The MCP inherits HULY_EMAIL/HULY_PASSWORD/HULY_WORKSPACE from the session env (sops `agent-env`). If the MCP times out or returns "no issues found", check that the bot is a member of the project's `members` array.
- After `docker compose restart` on the Huly CT, nginx may return 502 on the transactor WebSocket. Fix: `ssh proxmox pct exec 102 -- docker restart huly_v7-nginx-1`.
