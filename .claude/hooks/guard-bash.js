#!/usr/bin/env node
// PreToolUse (Bash): bloquea comandos destructivos o que exponen secretos.
// Exit 2 = bloquear y devolver el motivo a Claude.
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let cmd = '';
  try {
    cmd = (JSON.parse(raw).tool_input || {}).command || '';
  } catch {
    process.exit(0);
  }

  const rules = [
    [/rm\s+-[a-z]*r[a-z]*f?[a-z]*\s+(\/|~|\*|\.\.?)(\s|$)/i, 'rm -rf sobre raíz, home o directorio actual'],
    [/Remove-Item\s+.*-Recurse.*\s+(\\|[A-Z]:\\?)(\s|$)/i, 'Remove-Item recursivo sobre una raíz'],
    [/git\s+push\s+.*(--force|-f)(\s|$)/i, 'git push --force'],
    [/git\s+reset\s+--hard/i, 'git reset --hard'],
    [/drop\s+(database|table)/i, 'DROP DATABASE/TABLE'],
    [/(cat|type|Get-Content|less|more)\s+.*\.env(\s|$|\.)/i, 'lectura de archivos .env'],
    [/curl[^|]*\|\s*(sh|bash)/i, 'curl | sh'],
    [/(format|diskpart|mkfs)\b/i, 'comando de formateo de disco'],
  ];

  for (const [re, why] of rules) {
    if (re.test(cmd)) {
      console.error(`Bloqueado por hook guard-bash: ${why}. Usa una alternativa segura.`);
      process.exit(2);
    }
  }
  process.exit(0);
});
