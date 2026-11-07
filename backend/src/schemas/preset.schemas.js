import { z } from "zod";
import { MAX_PORTIONS_PER_INGREDIENT } from "../config/constants.js";
import { boolString } from "./common.js";

const recipeEntry = z
  .object({
    ingredientId: z.string().uuid(),
    portions: z.number().int().min(1).max(MAX_PORTIONS_PER_INGREDIENT),
  })
  .strict();

const baseFields = {
  code: z
    .string()
    .trim()
    .toUpperCase()
    .min(2)
    .max(30)
    .regex(
      /^[A-Z0-9_-]+$/,
      "El código solo admite letras, números, guiones y guion bajo.",
    ),
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).max(9999).optional(),
  recipe: z.array(recipeEntry).max(40),
};

export const createPresetBody = z
  .object({ ...baseFields, active: z.boolean().optional() })
  .strict();

export const updatePresetBody = z.object(baseFields).strict();

export const listPresetsQuery = z
  .object({ includeInactive: boolString.optional() })
  .strict();
