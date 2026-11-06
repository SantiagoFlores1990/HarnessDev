#!/usr/bin/env node
// Registra eventos del ciclo (UserPromptSubmit, SubagentStop, Stop) en .claude/logs/events.jsonl
const fs = require('node:fs');
const path = require('node:path');

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(raw);
    const dir = path.join(process.cwd(), '.claude', 'logs');
    fs.mkdirSync(dir, { recursive: true });
    const entry = {
      ts: new Date().toISOString(),
      event: data.hook_event_name,
      session: data.session_id,
      agent: data.agent_type || data.subagent_type || undefined,
      prompt: data.prompt ? String(data.prompt).slice(0, 200) : undefined,
    };
    fs.appendFileSync(path.join(dir, 'events.jsonl'), JSON.stringify(entry) + '\n');
  } catch {
    /* ignorar */
  }
  process.exit(0);
});
