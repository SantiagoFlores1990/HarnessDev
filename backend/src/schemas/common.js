import { z } from "zod";
import "../config/zodErrorMap.js";

export const idParams = z.object({ id: z.string().uuid() }).strict();

/** Importe positivo con <= 2 decimales: acepta string "1.50" o número; se normaliza a string "1.50". */
export const moneyInput = z.any().transform((value, ctx) => {
  const bad = () => {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message:
        "Importe inválido: debe ser >= 0, con máximo 2 decimales y hasta 99999999.99.",
    });
    return z.NEVER;
  };
  if (typeof value === "string") {
    if (!/^\d{1,8}(\.\d{1,2})?$/.test(value.trim())) return bad();
    return Number(value).toFixed(2);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value) || value < 0 || value > 99999999.99)
      return bad();
    if (Math.abs(value * 100 - Math.round(value * 100)) > 1e-6) return bad();
    return value.toFixed(2);
  }
  return bad();
});

export const pageQuery = {
  page: z.coerce.number().int().min(1).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).optional(),
};

export const boolString = z
  .enum(["true", "false"])
  .transform((v) => v === "true");
