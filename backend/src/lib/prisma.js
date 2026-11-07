import { PrismaClient } from '@prisma/client';

// Instancia única. La URL sale de DATABASE_URL (en pruebas, el setup la fuerza al esquema `test`).
export const prisma = new PrismaClient();
