import { EnvError, getEnv } from "./config/env.js";

let env;
try {
  env = getEnv();
} catch (err) {
  if (err instanceof EnvError) {
    console.error(`[Good Pizza] ${err.message}`);
    console.error("Compara tu backend/.env.local con backend/env.template.");
    process.exit(1);
  }
  throw err;
}

// Se importan después de validar el entorno para fallar rápido y con mensaje claro.
const { createApp } = await import("./app.js");
const { logger } = await import("./lib/logger.js");
const { prisma } = await import("./lib/prisma.js");

const app = createApp(env);
const server = app.listen(env.PORT, () => {
  logger.info(
    { port: env.PORT, env: env.NODE_ENV },
    "Good Pizza API escuchando en /api/v1",
  );
});

const shutdown = async (signal) => {
  logger.info({ signal }, "Cerrando servidor");
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
};
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
