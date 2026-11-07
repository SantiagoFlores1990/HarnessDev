import pino from 'pino';

// Nunca se registran contraseñas ni tokens.
export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  redact: {
    paths: [
      'req.headers.authorization',
      'headers.authorization',
      'password',
      '*.password',
      'refreshToken',
      '*.refreshToken',
      'accessToken',
      '*.accessToken',
    ],
    censor: '[REDACTED]',
  },
});
