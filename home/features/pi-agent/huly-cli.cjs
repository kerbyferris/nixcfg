#!/usr/bin/env node
/**
 * huly — Quick Huly issue lookup and management from the terminal.
 *
 * Usage:
 *   huly <issue-id>           Show issue details
 *   huly search <query>       Search issues
 *   huly list <project>       List issues in a project
 *   huly next                 Pick next unassigned backlog issue
 *
 * Requires HULY_EMAIL, HULY_PASSWORD, HULY_WORKSPACE in environment.
 */
const path = require('path');
const hulyMcpDir = path.resolve(__dirname, '../git/huly-mcp');
const { getConnection, closeConnection } = require(path.join(hulyMcpDir, 'dist/connection.js'));

async function showIssue(client, id) {
  const tracker = require('@hcengineering/tracker');
  // Try by identifier first
  const issue = await client.findOne(tracker.default.class.Issue, { identifier: id.toUpperCase() });
  if (!issue) {
    console.log(`Issue ${id} not found.`);
    return;
  }
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  ${issue.identifier}  |  ${issue.title}`);
  console.log(`  Status: ${issue.status}  |  Priority: ${issue.priority ?? 'N/A'}`);
  console.log(`  Assignee: ${issue.assignee ?? 'Unassigned'}`);
  if (issue.dueDate) console.log(`  Due: ${new Date(issue.dueDate).toISOString().slice(0, 10)}`);
  if (issue.description) {
    console.log(`\n  Description:`);
    const desc = typeof issue.description === 'string' ? issue.description : '(rich text)';
    console.log(`  ${desc.substring(0, 2000)}`);
  }
  console.log(`${'═'.repeat(60)}\n`);
}

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0] || 'next';

  const client = await getConnection();
  
  try {
    if (cmd === 'next') {
      // Find next unassigned backlog/todo issue
      const tracker = require('@hcengineering/tracker');
      const issues = await client.findAll(
        tracker.default.class.Issue,
        { assignee: null },
        { limit: 10 }
      );
      if (issues.length === 0) {
        console.log('No unassigned issues found.');
      } else {
        for (const issue of issues) {
          console.log(`  ${issue.identifier.padEnd(8)} ${(issue.title || '').substring(0, 70)}`);
        }
      }
    } else if (cmd === 'search') {
      const query = args.slice(1).join(' ');
      const tracker = require('@hcengineering/tracker');
      const issues = await client.findAll(
        tracker.default.class.Issue,
        {},
        { limit: 20 }
      );
      const matching = issues.filter(i =>
        (i.title || '').toLowerCase().includes(query.toLowerCase()) ||
        (i.identifier || '').toLowerCase().includes(query.toLowerCase())
      );
      for (const issue of matching) {
        console.log(`  ${issue.identifier.padEnd(8)} ${issue.title?.substring(0, 70) || '(no title)'}`);
      }
      if (!matching.length) console.log('No matches.');
    } else if (cmd === 'list') {
      const projectId = args[1] || 'TSK';
      const tracker = require('@hcengineering/tracker');
      const issues = await client.findAll(
        tracker.default.class.Issue,
        {},
        { limit: 50 }
      );
      // Filter by project identifier from issue's space or identifier prefix
      const matching = issues.filter(i => (i.identifier || '').startsWith(projectId.toUpperCase()));
      for (const issue of matching) {
        const status = issue.status || '?';
        console.log(`  ${issue.identifier.padEnd(8)} [${String(status).slice(-12).padEnd(12)}] ${issue.title?.substring(0, 50)}`);
      }
      if (!matching.length) console.log('No issues found.');
    } else {
      // Assume it's an issue ID
      await showIssue(client, cmd);
    }
  } finally {
    await closeConnection();
  }
}

main().catch(e => { console.error(e.message); process.exit(1); });
