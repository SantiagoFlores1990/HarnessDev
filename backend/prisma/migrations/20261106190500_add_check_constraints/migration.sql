-- Restricciones CHECK (Prisma no las modela). data-model.md §5.1.
-- Nota: se agregan en una segunda migración porque la migración `init` ya había sido aplicada
-- cuando se detectó que faltaban; las migraciones aplicadas no se editan.
-- `stock >= 0` es la última defensa contra sobreventa (ADR-005).

ALTER TABLE "ingredients"              ADD CONSTRAINT "ingredients_stock_nonneg"        CHECK ("stock" >= 0);
ALTER TABLE "ingredient_size_values"   ADD CONSTRAINT "isv_price_nonneg"               CHECK ("price" >= 0);
ALTER TABLE "ingredient_size_values"   ADD CONSTRAINT "isv_calories_nonneg"            CHECK ("calories" >= 0);
ALTER TABLE "vat_rates"                ADD CONSTRAINT "vat_rates_percent_range"        CHECK ("rate_percent" >= 0 AND "rate_percent" <= 100);
ALTER TABLE "preset_pizza_ingredients" ADD CONSTRAINT "ppi_portions_range"             CHECK ("portions" BETWEEN 1 AND 3);
ALTER TABLE "order_pizzas"             ADD CONSTRAINT "order_pizzas_quantity_range"    CHECK ("quantity" BETWEEN 1 AND 20);
ALTER TABLE "order_pizza_ingredients"  ADD CONSTRAINT "opi_portions_range"             CHECK ("portions" BETWEEN 1 AND 3);
ALTER TABLE "order_pizza_ingredients"  ADD CONSTRAINT "opi_recipe_portions_range"      CHECK ("recipe_portions" BETWEEN 0 AND "portions");
ALTER TABLE "orders"                   ADD CONSTRAINT "orders_total_consistent"        CHECK ("total" = "subtotal_vat15" + "subtotal_vat0" + "vat15_amount");
