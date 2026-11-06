#!/usr/bin/env node
// SessionStart: lo que se imprime por stdout se añade como contexto de la sesión.
const fs = require('node:fs');
const path = require('node:path');

const root = process.cwd();
const stages = [
  ['01-requirements', 'Requisitos'],
  ['02-architecture', 'Arquitectura'],
  ['03-design', 'Diseño UX'],
  ['04-backend', 'Backend'],
  ['05-frontend', 'Frontend'],
  ['06-qa', 'QA'],
  ['07-security', 'Seguridad'],
  ['08-devops', 'DevOps'],
  ['09-maintenance', 'Mantenimiento'],
];

const lines = ['Estado del SDLC en docs/:'];
for (const [dir, label] of stages) {
  const p = path.join(root, 'docs', dir);
  let n = 0;
  try {
    n = fs.readdirSync(p).filter((f) => f !== '.gitkeep').length;
  } catch {
    /* sin carpeta */
  }
  lines.push(`- ${label}: ${n > 0 ? `${n} artefacto(s)` : 'pendiente'}`);
}
lines.push('Usa /build-app <descripción> para generar todo, o /run-stage <agente> para una etapa.');
console.log(lines.join('\n'));
process.exit(0);
