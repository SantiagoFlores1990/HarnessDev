import { createRequire } from "node:module";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../utils/AppError.js";

const { version } = createRequire(import.meta.url)("../../package.json");

export async function checkHealth() {
  try {
    await prisma.$queryRaw`SELECT 1`;
  } catch {
    throw new AppError(
      503,
      "SERVICE_UNAVAILABLE",
      "La base de datos no responde.",
    );
  }
  return {
    status: "ok",
    database: "ok",
    version,
    time: new Date().toISOString(),
  };
}
