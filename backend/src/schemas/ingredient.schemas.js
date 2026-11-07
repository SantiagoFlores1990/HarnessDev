import { z } from "zod";
import {
  CATEGORY_CODES,
  MAX_STOCK_VALUE,
  SIZE_CODES,
} from "../config/constants.js";
import { boolString, moneyInput, pageQuery } from "./common.js";

const sizeValue = z
  .object({
    sizeCode: z.enum(SIZE_CODES),
    price: moneyInput,
    calories: z.number().int().min(0).max(100000),
  })
  .strict();

const baseFields = {
  code: z
    .string()
    .trim()
    .toUpperCase()
    .min(2)
    .max(20)
    .regex(/^[A-Z0-9-]+$/, "El código solo admite letras, números y guiones."),
  name: z.string().trim().min(2).max(80),
  categoryCode: z.enum(CATEGORY_CODES),
  vatRateCode: z.string().trim().min(1).max(20).optional(),
  // La cantidad exacta (uno por tamaño) se valida en el servicio: 422 MISSING_SIZE_VALUES.
  sizeValues: z.array(sizeValue).max(10),
};

export const createIngredientBody = z
  .object({
    ...baseFields,
    active: z.boolean().optional(),
    stock: z.number().int().min(0).max(MAX_STOCK_VALUE).optional(),
  })
  .strict();

export const updateIngredientBody = z.object(baseFields).strict();

export const stockBody = z.discriminatedUnion("operation", [
  z
    .object({
      operation: z.literal("SET"),
      value: z.number().int().min(0).max(MAX_STOCK_VALUE),
    })
    .strict(),
  z
    .object({
      operation: z.literal("ADD"),
      value: z
        .number()
        .int()
        .min(-MAX_STOCK_VALUE)
        .max(MAX_STOCK_VALUE)
        .refine((v) => v !== 0, "El ajuste no puede ser 0."),
    })
    .strict(),
]);

export const activeBody = z.object({ active: z.boolean() }).strict();

export const listIngredientsQuery = z
  .object({
    category: z.enum(CATEGORY_CODES).optional(),
    search: z.string().trim().max(80).optional(),
    includeInactive: boolString.optional(),
    ...pageQuery,
  })
  .strict();
