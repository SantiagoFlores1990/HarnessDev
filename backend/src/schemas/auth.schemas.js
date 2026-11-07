import { z } from "zod";
import "../config/zodErrorMap.js";

export const registerBody = z
  .object({
    fullName: z.string().trim().min(2).max(120),
    email: z.string().trim().toLowerCase().email().max(254),
    password: z
      .string()
      .min(8, "La contraseña debe tener al menos 8 caracteres.")
      .max(72, "La contraseña no puede superar 72 caracteres."),
  })
  .strict();

export const loginBody = z
  .object({
    email: z.string().trim().toLowerCase().email().max(254),
    password: z.string().min(1).max(128),
  })
  .strict();

export const refreshBody = z
  .object({ refreshToken: z.string().min(10).max(4000) })
  .strict();
