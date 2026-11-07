import { defineConfig } from "vitest/config";

// Valores FIJOS de prueba (no son secretos reales). Anulan lo que cargue dotenv-cli desde .env.local.
export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.js"],
    setupFiles: ["tests/helpers/setup.js"],
    testTimeout: 30000,
    hookTimeout: 60000,
    // Un solo proceso para los archivos con BD real evita carreras entre ellos.
    fileParallelism: false,
    env: {
      NODE_ENV: "test",
      PORT: "0",
      JWT_SECRET: "test-access-secret-0123456789-abcdefghijklmnop",
      JWT_REFRESH_SECRET: "test-refresh-secret-0123456789-abcdefghijklmnop",
      JWT_ACCESS_EXPIRES_IN: "15m",
      JWT_REFRESH_EXPIRES_IN: "7d",
      BCRYPT_COST: "4",
      RATE_LIMIT_WINDOW_MS: "900000",
      RATE_LIMIT_MAX: "100000",
      AUTH_RATE_LIMIT_MAX: "100000",
      LOG_LEVEL: "silent",
      CORS_ORIGINS: "http://localhost:3000",
    },
    coverage: {
      provider: "v8",
      include: ["src/**/*.js"],
    },
  },
});
