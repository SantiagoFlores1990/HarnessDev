// Aplica las migraciones de Prisma SOLO al esquema de pruebas (`test`) usando DATABASE_URL_TEST.
// Uso: npm run db:test:migrate   (carga .env.local con dotenv-cli)
// Seguridad: se niega a ejecutar si la URL no apunta explícitamente a ?schema=test.
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";

const url = process.env.DATABASE_URL_TEST;
if (!url) {
  console.error("Falta la variable DATABASE_URL_TEST en backend/.env.local.");
  console.error(
    'Agrega: DATABASE_URL_TEST="postgresql://USUARIO:CONTRASENA@localhost:5432/pizzeria?schema=test" (mismas credenciales que DATABASE_URL, con ?schema=test).',
  );
  process.exit(1);
}

let schema;
try {
  schema = new URL(url).searchParams.get("schema");
} catch {
  console.error("DATABASE_URL_TEST no es una URL válida.");
  process.exit(1);
}
if (schema !== "test") {
  console.error(
    `DATABASE_URL_TEST debe terminar en ?schema=test (esquema actual: "${schema ?? "ninguno"}"). Abortado para no tocar otros esquemas.`,
  );
  process.exit(1);
}

const prismaCli = createRequire(import.meta.url).resolve(
  "prisma/build/index.js",
);
const result = spawnSync(process.execPath, [prismaCli, "migrate", "deploy"], {
  stdio: "inherit",
  env: { ...process.env, DATABASE_URL: url },
});
process.exit(result.status ?? 1);
