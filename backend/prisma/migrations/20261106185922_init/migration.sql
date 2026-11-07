-- CreateEnum
CREATE TYPE "order_status" AS ENUM ('PENDING', 'IN_PREPARATION', 'DELIVERED');

-- CreateEnum
CREATE TYPE "pizza_kind" AS ENUM ('PRESET', 'CUSTOM');

-- CreateEnum
CREATE TYPE "pizza_component" AS ENUM ('DOUGH', 'SAUCE', 'TOPPING');

-- CreateTable
CREATE TABLE "roles" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(50) NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "full_name" VARCHAR(120) NOT NULL,
    "email" VARCHAR(254) NOT NULL,
    "password_hash" VARCHAR(100) NOT NULL,
    "role_id" INTEGER NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" VARCHAR(128) NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "replaced_by_id" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sizes" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "sort_order" SMALLINT NOT NULL,

    CONSTRAINT "sizes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ingredient_categories" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "sort_order" SMALLINT NOT NULL,

    CONSTRAINT "ingredient_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vat_rates" (
    "id" SERIAL NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "rate_percent" DECIMAL(5,2) NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "vat_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ingredients" (
    "id" UUID NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "category_id" INTEGER NOT NULL,
    "vat_rate_id" INTEGER NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "stock" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ingredient_size_values" (
    "id" UUID NOT NULL,
    "ingredient_id" UUID NOT NULL,
    "size_id" INTEGER NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "calories" INTEGER NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ingredient_size_values_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "preset_pizzas" (
    "id" UUID NOT NULL,
    "code" VARCHAR(30) NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "description" VARCHAR(300),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "preset_pizzas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "preset_pizza_ingredients" (
    "id" UUID NOT NULL,
    "preset_pizza_id" UUID NOT NULL,
    "ingredient_id" UUID NOT NULL,
    "portions" SMALLINT NOT NULL,

    CONSTRAINT "preset_pizza_ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "order_number" VARCHAR(20) NOT NULL,
    "order_date" DATE NOT NULL,
    "user_id" UUID NOT NULL,
    "customer_name_snapshot" VARCHAR(120) NOT NULL,
    "customer_email_snapshot" VARCHAR(254) NOT NULL,
    "status" "order_status" NOT NULL DEFAULT 'PENDING',
    "subtotal_vat15" DECIMAL(12,2) NOT NULL,
    "subtotal_vat0" DECIMAL(12,2) NOT NULL,
    "vat15_amount" DECIMAL(12,2) NOT NULL,
    "total" DECIMAL(12,2) NOT NULL,
    "total_calories" INTEGER NOT NULL,
    "status_changed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_daily_sequences" (
    "order_date" DATE NOT NULL,
    "last_value" INTEGER NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "order_daily_sequences_pkey" PRIMARY KEY ("order_date")
);

-- CreateTable
CREATE TABLE "order_status_history" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "from_status" "order_status",
    "to_status" "order_status" NOT NULL,
    "changed_by_id" UUID NOT NULL,
    "changed_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_pizzas" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "line_number" SMALLINT NOT NULL,
    "kind" "pizza_kind" NOT NULL,
    "preset_pizza_id" UUID,
    "preset_name_snapshot" VARCHAR(80),
    "size_id" INTEGER NOT NULL,
    "size_code_snapshot" VARCHAR(20) NOT NULL,
    "size_name_snapshot" VARCHAR(40) NOT NULL,
    "quantity" SMALLINT NOT NULL,
    "unit_price" DECIMAL(10,2) NOT NULL,
    "unit_calories" INTEGER NOT NULL,
    "unit_subtotal_vat15" DECIMAL(10,2) NOT NULL,
    "unit_subtotal_vat0" DECIMAL(10,2) NOT NULL,
    "line_subtotal" DECIMAL(12,2) NOT NULL,
    "line_calories" INTEGER NOT NULL,

    CONSTRAINT "order_pizzas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_pizza_ingredients" (
    "id" UUID NOT NULL,
    "order_pizza_id" UUID NOT NULL,
    "ingredient_id" UUID NOT NULL,
    "component" "pizza_component" NOT NULL,
    "ingredient_code_snapshot" VARCHAR(20) NOT NULL,
    "ingredient_name_snapshot" VARCHAR(80) NOT NULL,
    "category_code_snapshot" VARCHAR(20) NOT NULL,
    "recipe_portions" SMALLINT NOT NULL DEFAULT 0,
    "portions" SMALLINT NOT NULL,
    "unit_price" DECIMAL(10,2) NOT NULL,
    "unit_calories" INTEGER NOT NULL,
    "vat_rate_percent" DECIMAL(5,2) NOT NULL,
    "line_amount" DECIMAL(10,2) NOT NULL,
    "line_calories" INTEGER NOT NULL,

    CONSTRAINT "order_pizza_ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "roles_code_key" ON "roles"("code");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_role_id_idx" ON "users"("role_id");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens"("user_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_expires_at_idx" ON "refresh_tokens"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "sizes_code_key" ON "sizes"("code");

-- CreateIndex
CREATE UNIQUE INDEX "sizes_name_key" ON "sizes"("name");

-- CreateIndex
CREATE UNIQUE INDEX "sizes_sort_order_key" ON "sizes"("sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "ingredient_categories_code_key" ON "ingredient_categories"("code");

-- CreateIndex
CREATE UNIQUE INDEX "ingredient_categories_name_key" ON "ingredient_categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "vat_rates_code_key" ON "vat_rates"("code");

-- CreateIndex
CREATE UNIQUE INDEX "vat_rates_rate_percent_key" ON "vat_rates"("rate_percent");

-- CreateIndex
CREATE UNIQUE INDEX "ingredients_code_key" ON "ingredients"("code");

-- CreateIndex
CREATE INDEX "ingredients_category_id_idx" ON "ingredients"("category_id");

-- CreateIndex
CREATE INDEX "ingredients_vat_rate_id_idx" ON "ingredients"("vat_rate_id");

-- CreateIndex
CREATE INDEX "ingredients_active_category_id_idx" ON "ingredients"("active", "category_id");

-- CreateIndex
CREATE INDEX "ingredient_size_values_size_id_idx" ON "ingredient_size_values"("size_id");

-- CreateIndex
CREATE UNIQUE INDEX "ingredient_size_values_ingredient_id_size_id_key" ON "ingredient_size_values"("ingredient_id", "size_id");

-- CreateIndex
CREATE UNIQUE INDEX "preset_pizzas_code_key" ON "preset_pizzas"("code");

-- CreateIndex
CREATE UNIQUE INDEX "preset_pizzas_name_key" ON "preset_pizzas"("name");

-- CreateIndex
CREATE INDEX "preset_pizzas_active_sort_order_idx" ON "preset_pizzas"("active", "sort_order");

-- CreateIndex
CREATE INDEX "preset_pizza_ingredients_ingredient_id_idx" ON "preset_pizza_ingredients"("ingredient_id");

-- CreateIndex
CREATE UNIQUE INDEX "preset_pizza_ingredients_preset_pizza_id_ingredient_id_key" ON "preset_pizza_ingredients"("preset_pizza_id", "ingredient_id");

-- CreateIndex
CREATE UNIQUE INDEX "orders_order_number_key" ON "orders"("order_number");

-- CreateIndex
CREATE INDEX "orders_user_id_created_at_idx" ON "orders"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "orders_status_created_at_idx" ON "orders"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "orders_order_date_idx" ON "orders"("order_date");

-- CreateIndex
CREATE INDEX "order_status_history_order_id_changed_at_idx" ON "order_status_history"("order_id", "changed_at");

-- CreateIndex
CREATE INDEX "order_status_history_changed_by_id_idx" ON "order_status_history"("changed_by_id");

-- CreateIndex
CREATE INDEX "order_pizzas_preset_pizza_id_idx" ON "order_pizzas"("preset_pizza_id");

-- CreateIndex
CREATE INDEX "order_pizzas_size_id_idx" ON "order_pizzas"("size_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_pizzas_order_id_line_number_key" ON "order_pizzas"("order_id", "line_number");

-- CreateIndex
CREATE INDEX "order_pizza_ingredients_ingredient_id_idx" ON "order_pizza_ingredients"("ingredient_id");

-- CreateIndex
CREATE UNIQUE INDEX "order_pizza_ingredients_order_pizza_id_ingredient_id_key" ON "order_pizza_ingredients"("order_pizza_id", "ingredient_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ingredients" ADD CONSTRAINT "ingredients_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "ingredient_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ingredients" ADD CONSTRAINT "ingredients_vat_rate_id_fkey" FOREIGN KEY ("vat_rate_id") REFERENCES "vat_rates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ingredient_size_values" ADD CONSTRAINT "ingredient_size_values_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "ingredients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ingredient_size_values" ADD CONSTRAINT "ingredient_size_values_size_id_fkey" FOREIGN KEY ("size_id") REFERENCES "sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "preset_pizza_ingredients" ADD CONSTRAINT "preset_pizza_ingredients_preset_pizza_id_fkey" FOREIGN KEY ("preset_pizza_id") REFERENCES "preset_pizzas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "preset_pizza_ingredients" ADD CONSTRAINT "preset_pizza_ingredients_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "ingredients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_pizzas" ADD CONSTRAINT "order_pizzas_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_pizzas" ADD CONSTRAINT "order_pizzas_preset_pizza_id_fkey" FOREIGN KEY ("preset_pizza_id") REFERENCES "preset_pizzas"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_pizzas" ADD CONSTRAINT "order_pizzas_size_id_fkey" FOREIGN KEY ("size_id") REFERENCES "sizes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_pizza_ingredients" ADD CONSTRAINT "order_pizza_ingredients_order_pizza_id_fkey" FOREIGN KEY ("order_pizza_id") REFERENCES "order_pizzas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_pizza_ingredients" ADD CONSTRAINT "order_pizza_ingredients_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "ingredients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
