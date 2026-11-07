import { z } from "zod";
import {
  MAX_ITEMS_PER_ORDER,
  MAX_PIZZAS_PER_LINE,
  MAX_PORTIONS_PER_INGREDIENT,
  MAX_TOPPINGS_PER_PIZZA,
  ORDER_STATUSES,
  SIZE_CODES,
} from "../config/constants.js";
import { pageQuery } from "./common.js";

const portionInput = z
  .object({
    ingredientId: z.string().uuid(),
    portions: z.number().int().min(1).max(MAX_PORTIONS_PER_INGREDIENT),
  })
  .strict();

const quantity = z.number().int().min(1).max(MAX_PIZZAS_PER_LINE);

const customItem = z
  .object({
    type: z.literal("CUSTOM"),
    sizeCode: z.enum(SIZE_CODES),
    doughId: z.string().uuid().nullish(),
    sauceId: z.string().uuid().nullish(),
    toppings: z.array(portionInput).max(MAX_TOPPINGS_PER_PIZZA).default([]),
    quantity,
  })
  .strict();

const presetItem = z
  .object({
    type: z.literal("PRESET"),
    presetPizzaId: z.string().uuid(),
    sizeCode: z.enum(SIZE_CODES),
    extras: z.array(portionInput).max(MAX_TOPPINGS_PER_PIZZA).default([]),
    quantity,
  })
  .strict();

export const pizzaItem = z.discriminatedUnion("type", [customItem, presetItem]);

const items = z.array(pizzaItem).min(1).max(MAX_ITEMS_PER_ORDER);

export const quoteBody = z.object({ items }).strict();

export const createOrderBody = z
  .object({
    items,
    expectedTotal: z
      .string()
      .regex(/^\d{1,10}(\.\d{1,2})?$/, "Importe inválido.")
      .optional(),
  })
  .strict();

const ymd = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine(
    (s) => !Number.isNaN(Date.parse(`${s}T00:00:00Z`)),
    "Fecha inválida.",
  );

export const listOrdersQuery = z
  .object({
    status: z.enum(ORDER_STATUSES).optional(),
    from: ymd.optional(),
    to: ymd.optional(),
    search: z.string().trim().max(100).optional(),
    ...pageQuery,
  })
  .strict()
  .refine((q) => !q.from || !q.to || q.from <= q.to, {
    message: "`from` no puede ser posterior a `to`.",
    path: ["from"],
  });

export const statusBody = z.object({ status: z.enum(ORDER_STATUSES) }).strict();
