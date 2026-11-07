// Seed idempotente con DATOS DE EJEMPLO (no son precios reales). Uso: npm run db:seed
// Contraseñas: SEED_ADMIN_PASSWORD / SEED_CLIENT_PASSWORD; si faltan se generan al azar y se
// imprimen UNA sola vez. Nunca se guardan en el código ni en el repositorio.
import { PrismaClient } from "@prisma/client";
import {
  seedIngredients,
  seedPresets,
  seedReference,
  seedUsers,
} from "./seed-lib.js";

const prisma = new PrismaClient();

async function main() {
  await seedReference(prisma);
  await seedIngredients(prisma);
  await seedPresets(prisma);
  const generated = await seedUsers(prisma, {
    adminEmail: process.env.SEED_ADMIN_EMAIL || "admin@goodpizza.local",
    adminPassword: process.env.SEED_ADMIN_PASSWORD,
    clientEmail: process.env.SEED_CLIENT_EMAIL || "cliente@goodpizza.local",
    clientPassword: process.env.SEED_CLIENT_PASSWORD,
    cost: Number(process.env.BCRYPT_COST) || 12,
  });

  const [ingredients, presets, users] = await Promise.all([
    prisma.ingredient.count(),
    prisma.presetPizza.count(),
    prisma.user.count(),
  ]);
  console.log(
    `Seed listo: ${ingredients} ingredientes, ${presets} pizzas predefinidas, ${users} usuarios (datos de ejemplo).`,
  );

  if (generated.length) {
    console.log(
      "\nContraseñas generadas (se muestran UNA sola vez; guárdalas ahora):",
    );
    for (const g of generated)
      console.log(`  ${g.role} ${g.email}: ${g.generatedPassword}`);
  }
}

main()
  .catch((err) => {
    console.error("Error en el seed:", err.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
