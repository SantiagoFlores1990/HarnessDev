#!/usr/bin/env node
// PostToolUse (Edit|Write): formatea el archivo editado si hay formateador disponible.
// Best-effort: nunca falla ni bloquea.
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw).tool_input || {};
    const file = input.file_path || input.path;
    if (!file || !fs.existsSync(file)) return process.exit(0);

    const ext = path.extname(file).toLowerCase();
    const opts = { stdio: 'ignore', shell: true, timeout: 20000 };

    if (ext === '.dart') {
      spawnSync('dart', ['format', `"${file}"`], opts);
    } else if (['.js', '.mjs', '.cjs', '.ts', '.json', '.md', '.yml', '.yaml'].includes(ext)) {
      const local = path.join(process.cwd(), 'backend', 'node_modules', '.bin', 'prettier');
      if (fs.existsSync(local) || fs.existsSync(local + '.cmd')) {
        spawnSync(`"${local}"`, ['--write', `"${file}"`], opts);
      }
    }
  } catch {
    /* ignorar */
  }
  process.exit(0);
});
