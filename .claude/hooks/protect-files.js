#!/usr/bin/env node
// PreToolUse (Edit|Write): impide modificar secretos, .git y archivos de bloqueo.
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let file = '';
  try {
    const input = JSON.parse(raw).tool_input || {};
    file = (input.file_path || input.path || '').replace(/\\/g, '/');
  } catch {
    process.exit(0);
  }

  const protectedPatterns = [
    /(^|\/)\.env(\.(?!example$)[^/]*)?$/,
    /(^|\/)\.git\//,
    /(^|\/)package-lock\.json$/,
    /(^|\/)pubspec\.lock$/,
    /\.(pem|key|p12|pfx|keystore|jks)$/i,
    /(^|\/)\.claude\/hooks\//,
  ];

  if (protectedPatterns.some((re) => re.test(file))) {
    console.error(`Bloqueado por hook protect-files: "${file}" está protegido. Si es necesario, pide permiso al usuario.`);
    process.exit(2);
  }
  process.exit(0);
});
