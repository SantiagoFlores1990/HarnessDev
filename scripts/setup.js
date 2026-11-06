#!/usr/bin/env node
// Configura el ambiente tras clonar el repositorio. Multiplataforma (solo requiere Node).
//   node scripts/setup.js           -> verifica herramientas, instala dependencias y crea backend/.env.local
//   node scripts/setup.js --check   -> solo verifica herramientas (no modifica nada)
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const backend = path.join(root, 'backend');
const checkOnly = process.argv.includes('--check');
const isWin = process.platform === 'win32';

const run = (cmd, args, cwd = root) =>
  spawnSync(cmd, args, { cwd, shell: true, encoding: 'utf8' });

const firstLine = (r) => (r.stdout || r.stderr || '').trim().split(/\r?\n/)[0];

const tools = [
  { name: 'Node.js', cmd: 'node', args: ['--version'], required: true, min: 20 },
  { name: 'npm', cmd: 'npm', args: ['--version'], required: true },
  { name: 'Git', cmd: 'git', args: ['--version'], required: true },
  { name: 'Flutter', cmd: 'flutter', args: ['--version', '--machine'], required: false, hint: 'https://docs.flutter.dev/get-started/install' },
  { name: 'PostgreSQL (psql)', cmd: 'psql', args: ['--version'], required: false, hint: isWin ? 'Suele estar en C:\\Program Files\\PostgreSQL\\<versión>\\bin; añádelo al PATH' : 'Instala postgresql-client' },
  { name: 'Claude Code', cmd: 'claude', args: ['--version'], required: false, hint: 'https://docs.claude.com/claude-code' },
];

let failed = false;
console.log('== Verificación de herramientas ==');
for (const t of tools) {
  const r = run(t.cmd, t.args);
  const ok = r.status === 0;
  let detail = ok ? firstLine(r).slice(0, 60) : 'no encontrado';
  if (ok && t.min) {
    const major = parseInt(detail.replace(/^v/, ''), 10);
    if (major < t.min) {
      detail += `  (se requiere >= ${t.min})`;
      if (t.required) failed = true;
    }
  }
  if (!ok && t.required) failed = true;
  const mark = ok ? 'OK    ' : t.required ? 'FALTA ' : 'aviso ';
  console.log(`${mark} ${t.name.padEnd(20)} ${detail}${!ok && t.hint ? '  -> ' + t.hint : ''}`);
}
if (failed) {
  console.error('\nFaltan herramientas obligatorias. Instálalas y vuelve a ejecutar.');
  process.exit(1);
}
if (checkOnly) process.exit(0);

console.log('\n== Dependencias del backend ==');
const install = spawnSync('npm', ['install'], { cwd: backend, shell: true, stdio: 'inherit' });
if (install.status !== 0) process.exit(install.status || 1);

console.log('\n== Variables de entorno ==');
const template = path.join(backend, 'env.template');
const target = path.join(backend, '.env.local');
if (fs.existsSync(target)) {
  console.log('backend/.env.local ya existe: no se modifica.');
} else {
  fs.copyFileSync(template, target);
  console.log('Creado backend/.env.local desde env.template.');
}

console.log(`
== Siguientes pasos ==
1. Edita backend/.env.local: DB_NAME, DB_USER, DB_PASSWORD y DATABASE_URL (y genera JWT_SECRET propios).
2. Crea la base de datos (reemplaza usuario y nombre):
     psql -U <usuario> -h localhost -c "CREATE DATABASE <nombre>;"
3. Si usarás Flutter: ejecuta "flutter doctor" y resuelve lo que marque en rojo.
4. Abre Claude Code en la raíz del repo y ejecuta:
     /build-app <descripción de tu aplicación>
`);
