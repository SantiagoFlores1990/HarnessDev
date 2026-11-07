import { z } from 'zod';

const isTest = process.env.NODE_ENV === 'test';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(0).max(65535).default(3000),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(1),
  JWT_REFRESH_SECRET: z.string().min(1),
  JWT_ACCESS_EXPIRES_IN: z.string().min(2).default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().min(2).default('7d'),
  BCRYPT_COST: z.coerce
    .number()
    .int()
    .min(isTest ? 4 : 12)
    .max(15)
    .default(12),
  CORS_ORIGINS: z.string().default(''),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(900000),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(300),
  AUTH_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(10),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
});

export class EnvError extends Error {
  constructor(problems) {
    super(
      'Configuración inválida. Revisa estas variables de entorno (backend/.env.local): ' +
        problems.map((p) => `${p.name} (${p.reason})`).join(', ')
    );
    this.name = 'EnvError';
    this.problems = problems;
  }
}

/** Valida variables; nunca incluye valores en el mensaje, solo nombres. */
export function loadEnv(source = process.env) {
  const result = schema.safeParse(source);
  const problems = [];
  if (!result.success) {
    for (const issue of result.error.issues) {
      const name = String(issue.path[0] ?? '?');
      const missing = source[name] === undefined || source[name] === '';
      problems.push({ name, reason: missing ? 'falta' : 'valor inválido' });
    }
    throw new EnvError(problems);
  }
  const env = result.data;
  if (env.NODE_ENV === 'production') {
    if (env.JWT_SECRET.length < 32) problems.push({ name: 'JWT_SECRET', reason: 'mínimo 32 caracteres' });
    if (env.JWT_REFRESH_SECRET.length < 32)
      problems.push({ name: 'JWT_REFRESH_SECRET', reason: 'mínimo 32 caracteres' });
    if (env.JWT_SECRET === env.JWT_REFRESH_SECRET)
      problems.push({ name: 'JWT_REFRESH_SECRET', reason: 'debe ser distinto de JWT_SECRET' });
    if (problems.length) throw new EnvError(problems);
  }
  return {
    ...env,
    corsOrigins: env.CORS_ORIGINS.split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  };
}

let cached;
export function getEnv() {
  if (!cached) cached = loadEnv(process.env);
  return cached;
}
