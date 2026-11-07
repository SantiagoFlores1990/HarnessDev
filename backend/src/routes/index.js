import { Router } from "express";
import { asyncHandler as h } from "../utils/asyncHandler.js";
import { requireAuth } from "../middlewares/requireAuth.js";
import { requireRole } from "../middlewares/requireRole.js";
import { validate } from "../middlewares/validate.js";
import { createAuthLimiter } from "../middlewares/rateLimiters.js";
import { ROLES } from "../config/constants.js";
import { idParams } from "../schemas/common.js";
import * as authSchemas from "../schemas/auth.schemas.js";
import * as ingSchemas from "../schemas/ingredient.schemas.js";
import * as presetSchemas from "../schemas/preset.schemas.js";
import * as orderSchemas from "../schemas/order.schemas.js";
import * as health from "../controllers/health.controller.js";
import * as auth from "../controllers/auth.controller.js";
import * as catalog from "../controllers/catalog.controller.js";
import * as ingredients from "../controllers/ingredients.controller.js";
import * as presets from "../controllers/presetPizzas.controller.js";
import * as orders from "../controllers/orders.controller.js";

const { ADMIN, CLIENT } = ROLES;

/** Monta todas las rutas bajo /api/v1 (solo enrutado + middlewares por ruta). */
export function buildRouter(env) {
  const router = Router();
  const authLimiter = createAuthLimiter(env);

  // 1. Salud (pública)
  router.get("/health", h(health.health));

  // 2-6. Autenticación
  router.post(
    "/auth/register",
    authLimiter,
    validate({ body: authSchemas.registerBody }),
    h(auth.register),
  );
  router.post(
    "/auth/login",
    authLimiter,
    validate({ body: authSchemas.loginBody }),
    h(auth.login),
  );
  router.post(
    "/auth/refresh",
    authLimiter,
    validate({ body: authSchemas.refreshBody }),
    h(auth.refresh),
  );
  router.post(
    "/auth/logout",
    validate({ body: authSchemas.refreshBody }),
    h(auth.logout),
  );
  router.get("/auth/me", requireAuth, h(auth.me));

  // 7-9. Catálogos
  router.get("/sizes", requireAuth, h(catalog.sizes));
  router.get("/ingredient-categories", requireAuth, h(catalog.categories));
  router.get(
    "/vat-rates",
    requireAuth,
    requireRole(ADMIN),
    h(catalog.vatRates),
  );

  // 10-15. Ingredientes (sin DELETE: baja lógica)
  router.get(
    "/ingredients",
    requireAuth,
    validate({ query: ingSchemas.listIngredientsQuery }),
    h(ingredients.list),
  );
  router.get(
    "/ingredients/:id",
    requireAuth,
    validate({ params: idParams }),
    h(ingredients.getById),
  );
  router.post(
    "/ingredients",
    requireAuth,
    requireRole(ADMIN),
    validate({ body: ingSchemas.createIngredientBody }),
    h(ingredients.create),
  );
  router.put(
    "/ingredients/:id",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: ingSchemas.updateIngredientBody }),
    h(ingredients.update),
  );
  router.patch(
    "/ingredients/:id/stock",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: ingSchemas.stockBody }),
    h(ingredients.updateStock),
  );
  router.patch(
    "/ingredients/:id/status",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: ingSchemas.activeBody }),
    h(ingredients.setStatus),
  );

  // 16-20. Pizzas predefinidas (sin DELETE: baja lógica)
  router.get(
    "/preset-pizzas",
    requireAuth,
    validate({ query: presetSchemas.listPresetsQuery }),
    h(presets.list),
  );
  router.get(
    "/preset-pizzas/:id",
    requireAuth,
    validate({ params: idParams }),
    h(presets.getById),
  );
  router.post(
    "/preset-pizzas",
    requireAuth,
    requireRole(ADMIN),
    validate({ body: presetSchemas.createPresetBody }),
    h(presets.create),
  );
  router.put(
    "/preset-pizzas/:id",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: presetSchemas.updatePresetBody }),
    h(presets.update),
  );
  router.patch(
    "/preset-pizzas/:id/status",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: ingSchemas.activeBody }),
    h(presets.setStatus),
  );

  // 21-25. Pedidos
  router.post(
    "/orders/quote",
    requireAuth,
    validate({ body: orderSchemas.quoteBody }),
    h(orders.quote),
  );
  router.post(
    "/orders",
    requireAuth,
    requireRole(CLIENT),
    validate({ body: orderSchemas.createOrderBody }),
    h(orders.create),
  );
  router.get(
    "/orders",
    requireAuth,
    validate({ query: orderSchemas.listOrdersQuery }),
    h(orders.list),
  );
  router.get(
    "/orders/:id",
    requireAuth,
    validate({ params: idParams }),
    h(orders.getById),
  );
  router.patch(
    "/orders/:id/status",
    requireAuth,
    requireRole(ADMIN),
    validate({ params: idParams, body: orderSchemas.statusBody }),
    h(orders.updateStatus),
  );

  return router;
}
