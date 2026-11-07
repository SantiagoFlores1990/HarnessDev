// Pruebas de API (Supertest) sobre app.js con los SERVICIOS sustituidos por dobles:
// verifican rutas, validación Zod, autenticación, roles, códigos HTTP y formato de error.
// No tocan la base de datos.
import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

vi.mock("../../src/services/auth.service.js");
vi.mock("../../src/services/catalog.service.js");
vi.mock("../../src/services/ingredient.service.js");
vi.mock("../../src/services/presetPizza.service.js");
vi.mock("../../src/services/quote.service.js");
vi.mock("../../src/services/order.service.js");
vi.mock("../../src/services/health.service.js");

import { createApp } from "../../src/app.js";
import { AppError, notFound } from "../../src/utils/AppError.js";
import * as authService from "../../src/services/auth.service.js";
import * as catalogService from "../../src/services/catalog.service.js";
import * as ingredientService from "../../src/services/ingredient.service.js";
import * as presetService from "../../src/services/presetPizza.service.js";
import * as quoteService from "../../src/services/quote.service.js";
import * as orderService from "../../src/services/order.service.js";
import * as healthService from "../../src/services/health.service.js";
import {
  adminToken,
  bearer,
  clientToken,
  expiredToken,
  ADMIN_ID,
  CLIENT_ID,
} from "../helpers/tokens.js";
import { uid } from "../helpers/catalog.js";

const app = createApp();
const API = "/api/v1";
const admin = () => bearer(adminToken());
const client = () => bearer(clientToken());
const ID = uid(42);

const customItem = {
  type: "CUSTOM",
  sizeCode: "MEDIUM",
  doughId: uid(1),
  sauceId: uid(2),
  toppings: [{ ingredientId: uid(3), portions: 3 }],
  quantity: 1,
};
const presetItem = {
  type: "PRESET",
  presetPizzaId: uid(100),
  sizeCode: "FAMILY",
  extras: [{ ingredientId: uid(3), portions: 1 }],
  quantity: 2,
};

const sizeValues = [
  { sizeCode: "INDIVIDUAL", price: "1.00", calories: 80 },
  { sizeCode: "MEDIUM", price: 1.5, calories: 110 },
  { sizeCode: "FAMILY", price: "2.20", calories: 160 },
];
const ingredientBody = {
  code: "que-moz",
  name: "Queso mozzarella",
  categoryCode: "CHEESE",
  vatRateCode: "VAT_15",
  active: true,
  stock: 120,
  sizeValues,
};
const recipe = [
  { ingredientId: uid(1), portions: 1 },
  { ingredientId: uid(2), portions: 1 },
];

beforeEach(() => {
  vi.resetAllMocks();
});

const expectError = (res, status, code) => {
  expect(res.status).toBe(status);
  expect(res.body).toEqual({
    error: { code, message: expect.any(String), details: expect.any(Array) },
  });
};

describe("Formato de error uniforme y rutas inexistentes", () => {
  it("ruta inexistente -> 404 ROUTE_NOT_FOUND", async () => {
    expectError(
      await request(app).get(`${API}/no-existe`),
      404,
      "ROUTE_NOT_FOUND",
    );
  });
  it("DELETE /ingredients/:id no existe (S-23) -> 404 ROUTE_NOT_FOUND", async () => {
    expectError(
      await request(app).delete(`${API}/ingredients/${ID}`).set(admin()),
      404,
      "ROUTE_NOT_FOUND",
    );
  });
  it("DELETE /preset-pizzas/:id no existe (baja lógica) -> 404 ROUTE_NOT_FOUND", async () => {
    expectError(
      await request(app).delete(`${API}/preset-pizzas/${ID}`).set(admin()),
      404,
      "ROUTE_NOT_FOUND",
    );
  });
  it("no hay cancelación ni edición de pedidos -> 404 ROUTE_NOT_FOUND", async () => {
    expectError(
      await request(app).delete(`${API}/orders/${ID}`).set(client()),
      404,
      "ROUTE_NOT_FOUND",
    );
    expectError(
      await request(app).put(`${API}/orders/${ID}`).set(client()).send({}),
      404,
      "ROUTE_NOT_FOUND",
    );
  });
  it("JSON mal formado -> 400 VALIDATION_ERROR", async () => {
    const res = await request(app)
      .post(`${API}/auth/login`)
      .set("Content-Type", "application/json")
      .send("{no-json");
    expectError(res, 400, "VALIDATION_ERROR");
  });
  it("cuerpo mayor a 100 KB -> 400 VALIDATION_ERROR", async () => {
    const res = await request(app)
      .post(`${API}/auth/login`)
      .send({ email: "a@b.co", password: "x".repeat(150000) });
    expectError(res, 400, "VALIDATION_ERROR");
  });
  it("error inesperado -> 500 INTERNAL_ERROR sin stack ni detalles internos", async () => {
    orderService.list.mockRejectedValue(
      new Error("fallo interno con secreto xyz"),
    );
    const res = await request(app).get(`${API}/orders`).set(client());
    expectError(res, 500, "INTERNAL_ERROR");
    expect(JSON.stringify(res.body)).not.toContain("secreto");
    expect(JSON.stringify(res.body)).not.toContain("stack");
  });
  it("cabeceras de seguridad de helmet presentes y sin X-Powered-By", async () => {
    healthService.checkHealth.mockResolvedValue({});
    const res = await request(app).get(`${API}/health`);
    expect(res.headers["x-powered-by"]).toBeUndefined();
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
  });
});

describe("1. GET /health", () => {
  it("200 público con status, database, version y time", async () => {
    healthService.checkHealth.mockResolvedValue({
      status: "ok",
      database: "ok",
      version: "0.1.0",
      time: "2026-11-06T15:04:05.123Z",
    });
    const res = await request(app).get(`${API}/health`);
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      status: "ok",
      database: "ok",
      version: "0.1.0",
      time: "2026-11-06T15:04:05.123Z",
    });
  });
  it("503 SERVICE_UNAVAILABLE si la BD no responde", async () => {
    healthService.checkHealth.mockRejectedValue(
      new AppError(503, "SERVICE_UNAVAILABLE", "La base de datos no responde."),
    );
    expectError(
      await request(app).get(`${API}/health`),
      503,
      "SERVICE_UNAVAILABLE",
    );
  });
});

describe("2-6. Autenticación", () => {
  const session = {
    user: {
      id: ID,
      fullName: "Ana Pérez",
      email: "ana@ejemplo.com",
      role: "CLIENT",
    },
    accessToken: "jwt",
    accessTokenExpiresIn: 900,
    refreshToken: "jwt2",
    refreshTokenExpiresIn: 604800,
  };

  it("2. register: 201 con usuario y tokens; normaliza el email", async () => {
    authService.register.mockResolvedValue(session);
    const res = await request(app).post(`${API}/auth/register`).send({
      fullName: " Ana Pérez ",
      email: "ANA@Ejemplo.com",
      password: "minimo8car",
    });
    expect(res.status).toBe(201);
    expect(res.body.data).toEqual(session);
    expect(authService.register).toHaveBeenCalledWith({
      fullName: "Ana Pérez",
      email: "ana@ejemplo.com",
      password: "minimo8car",
    });
  });
  it("2. register: contraseña < 8 -> 400 con el mensaje exacto del contrato", async () => {
    const res = await request(app)
      .post(`${API}/auth/register`)
      .send({ fullName: "Ana", email: "ana@ejemplo.com", password: "corta" });
    expectError(res, 400, "VALIDATION_ERROR");
    expect(res.body.error.details).toContainEqual({
      path: "password",
      message: "La contraseña debe tener al menos 8 caracteres.",
    });
    expect(authService.register).not.toHaveBeenCalled();
  });
  it("2. register: un campo `role` en el body -> 400 (siempre se crea CLIENT, S-14)", async () => {
    const res = await request(app).post(`${API}/auth/register`).send({
      fullName: "Ana",
      email: "ana@ejemplo.com",
      password: "minimo8car",
      role: "ADMIN",
    });
    expectError(res, 400, "VALIDATION_ERROR");
    expect(authService.register).not.toHaveBeenCalled();
  });
  it("2. register: email inválido o faltante -> 400", async () => {
    expectError(
      await request(app).post(`${API}/auth/register`).send({
        fullName: "Ana",
        email: "no-es-email",
        password: "minimo8car",
      }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .post(`${API}/auth/register`)
        .send({ fullName: "Ana", password: "minimo8car" }),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("2. register: 409 EMAIL_ALREADY_EXISTS", async () => {
    authService.register.mockRejectedValue(
      new AppError(
        409,
        "EMAIL_ALREADY_EXISTS",
        "Ya existe una cuenta con ese email.",
      ),
    );
    expectError(
      await request(app).post(`${API}/auth/register`).send({
        fullName: "Ana",
        email: "ana@ejemplo.com",
        password: "minimo8car",
      }),
      409,
      "EMAIL_ALREADY_EXISTS",
    );
  });
  it("3. login: 200 con tokens", async () => {
    authService.login.mockResolvedValue(session);
    const res = await request(app)
      .post(`${API}/auth/login`)
      .send({ email: "ana@ejemplo.com", password: "cualquiera" });
    expect(res.status).toBe(200);
    expect(res.body.data.accessToken).toBe("jwt");
  });
  it("3. login: 401 INVALID_CREDENTIALS y 400 sin cuerpo", async () => {
    authService.login.mockRejectedValue(
      new AppError(
        401,
        "INVALID_CREDENTIALS",
        "Email o contraseña incorrectos.",
      ),
    );
    expectError(
      await request(app)
        .post(`${API}/auth/login`)
        .send({ email: "ana@ejemplo.com", password: "mala" }),
      401,
      "INVALID_CREDENTIALS",
    );
    expectError(
      await request(app).post(`${API}/auth/login`).send({}),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("3. login: 403 FORBIDDEN para usuario desactivado", async () => {
    authService.login.mockRejectedValue(
      new AppError(403, "FORBIDDEN", "Tu cuenta está desactivada."),
    );
    expectError(
      await request(app)
        .post(`${API}/auth/login`)
        .send({ email: "ana@ejemplo.com", password: "x" }),
      403,
      "FORBIDDEN",
    );
  });
  it("4. refresh: 200 con nuevo par de tokens; 401 INVALID_REFRESH_TOKEN; 400", async () => {
    authService.refresh.mockResolvedValueOnce({
      accessToken: "a",
      accessTokenExpiresIn: 900,
      refreshToken: "r",
      refreshTokenExpiresIn: 604800,
    });
    const ok = await request(app)
      .post(`${API}/auth/refresh`)
      .send({ refreshToken: "x".repeat(20) });
    expect(ok.status).toBe(200);
    expect(ok.body.data).toEqual({
      accessToken: "a",
      accessTokenExpiresIn: 900,
      refreshToken: "r",
      refreshTokenExpiresIn: 604800,
    });
    authService.refresh.mockRejectedValueOnce(
      new AppError(401, "INVALID_REFRESH_TOKEN", "La sesión no es válida."),
    );
    expectError(
      await request(app)
        .post(`${API}/auth/refresh`)
        .send({ refreshToken: "x".repeat(20) }),
      401,
      "INVALID_REFRESH_TOKEN",
    );
    expectError(
      await request(app).post(`${API}/auth/refresh`).send({}),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("5. logout: 204 sin cuerpo (idempotente) y 400 sin token", async () => {
    authService.logout.mockResolvedValue(undefined);
    const res = await request(app)
      .post(`${API}/auth/logout`)
      .send({ refreshToken: "x".repeat(20) });
    expect(res.status).toBe(204);
    expect(res.text).toBe("");
    expectError(
      await request(app).post(`${API}/auth/logout`).send({}),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("6. me: 200 con el usuario; 401 sin token", async () => {
    authService.me.mockResolvedValue(session.user);
    const res = await request(app).get(`${API}/auth/me`).set(client());
    expect(res.body.data).toEqual(session.user);
    expect(authService.me).toHaveBeenCalledWith(CLIENT_ID);
    expectError(
      await request(app).get(`${API}/auth/me`),
      401,
      "UNAUTHENTICATED",
    );
  });
});

describe("Autenticación de acceso (requireAuth)", () => {
  it("sin cabecera -> 401 UNAUTHENTICATED", async () => {
    expectError(await request(app).get(`${API}/sizes`), 401, "UNAUTHENTICATED");
  });
  it("token mal formado o firmado con otro secreto -> 401 UNAUTHENTICATED", async () => {
    expectError(
      await request(app).get(`${API}/sizes`).set(bearer("basura")),
      401,
      "UNAUTHENTICATED",
    );
    expectError(
      await request(app)
        .get(`${API}/sizes`)
        .set({ Authorization: "Basic abc" }),
      401,
      "UNAUTHENTICATED",
    );
  });
  it("access token caducado -> 401 TOKEN_EXPIRED", async () => {
    expectError(
      await request(app).get(`${API}/sizes`).set(bearer(expiredToken())),
      401,
      "TOKEN_EXPIRED",
    );
  });
});

describe("7-9. Catálogos", () => {
  it("7. GET /sizes (Auth)", async () => {
    catalogService.listSizes.mockResolvedValue([
      { code: "INDIVIDUAL", name: "Individual", sortOrder: 1 },
    ]);
    const res = await request(app).get(`${API}/sizes`).set(client());
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      data: [{ code: "INDIVIDUAL", name: "Individual", sortOrder: 1 }],
    });
  });
  it("8. GET /ingredient-categories (Auth)", async () => {
    catalogService.listCategories.mockResolvedValue([
      { code: "DOUGH", name: "Masa", sortOrder: 1 },
    ]);
    const res = await request(app)
      .get(`${API}/ingredient-categories`)
      .set(client());
    expect(res.status).toBe(200);
    expect(res.body.data[0].code).toBe("DOUGH");
  });
  it("9. GET /vat-rates: ADMIN 200; CLIENT 403", async () => {
    catalogService.listVatRates.mockResolvedValue([
      {
        code: "VAT_15",
        name: "IVA 15 %",
        ratePercent: "15.00",
        isDefault: true,
      },
    ]);
    expect(
      (await request(app).get(`${API}/vat-rates`).set(admin())).status,
    ).toBe(200);
    expectError(
      await request(app).get(`${API}/vat-rates`).set(client()),
      403,
      "FORBIDDEN",
    );
    expectError(
      await request(app).get(`${API}/vat-rates`),
      401,
      "UNAUTHENTICATED",
    );
  });
});

describe("10-11. Ingredientes (lectura)", () => {
  it("10. GET /ingredients: pasa el usuario y la consulta validada al servicio", async () => {
    ingredientService.list.mockResolvedValue({ data: [] });
    const res = await request(app)
      .get(
        `${API}/ingredients?category=CHEESE&search=moz&includeInactive=true&page=2&pageSize=5`,
      )
      .set(admin());
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ data: [] });
    expect(ingredientService.list).toHaveBeenCalledWith(
      { id: ADMIN_ID, role: "ADMIN" },
      {
        category: "CHEESE",
        search: "moz",
        includeInactive: true,
        page: 2,
        pageSize: 5,
      },
    );
  });
  it("10. GET /ingredients: parámetros inválidos -> 400", async () => {
    expectError(
      await request(app).get(`${API}/ingredients?category=PIZZA`).set(client()),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .get(`${API}/ingredients?pageSize=1000&page=1`)
        .set(client()),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app).get(`${API}/ingredients?foo=1`).set(client()),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("10. GET /ingredients: sin token 401", async () => {
    expectError(
      await request(app).get(`${API}/ingredients`),
      401,
      "UNAUTHENTICATED",
    );
  });
  it("11. GET /ingredients/:id: 200, 400 (id no UUID), 404", async () => {
    ingredientService.getById.mockResolvedValueOnce({ id: ID });
    expect(
      (await request(app).get(`${API}/ingredients/${ID}`).set(client())).body,
    ).toEqual({ data: { id: ID } });
    expectError(
      await request(app).get(`${API}/ingredients/abc`).set(client()),
      400,
      "VALIDATION_ERROR",
    );
    ingredientService.getById.mockRejectedValueOnce(notFound());
    expectError(
      await request(app).get(`${API}/ingredients/${ID}`).set(client()),
      404,
      "NOT_FOUND",
    );
  });
});

describe("12-15. Ingredientes (administración)", () => {
  it("12. POST /ingredients: 201 y normaliza (código en mayúsculas, precio a string 2 decimales)", async () => {
    ingredientService.create.mockResolvedValue({ id: ID });
    const res = await request(app)
      .post(`${API}/ingredients`)
      .set(admin())
      .send(ingredientBody);
    expect(res.status).toBe(201);
    const [, body] = ingredientService.create.mock.calls[0];
    expect(body.code).toBe("QUE-MOZ");
    expect(body.sizeValues.map((s) => s.price)).toEqual([
      "1.00",
      "1.50",
      "2.20",
    ]);
  });
  it("12. POST /ingredients: precio negativo, con 3 decimales o stock negativo -> 400", async () => {
    const bad = (patch) =>
      request(app)
        .post(`${API}/ingredients`)
        .set(admin())
        .send({ ...ingredientBody, ...patch });
    expectError(
      await bad({
        sizeValues: [{ sizeCode: "MEDIUM", price: -1, calories: 1 }],
      }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await bad({
        sizeValues: [{ sizeCode: "MEDIUM", price: "1.505", calories: 1 }],
      }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await bad({
        sizeValues: [{ sizeCode: "MEDIUM", price: 1.001, calories: 1 }],
      }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(await bad({ stock: -1 }), 400, "VALIDATION_ERROR");
    expectError(await bad({ code: "con espacios" }), 400, "VALIDATION_ERROR");
    expectError(await bad({ categoryCode: "PIZZA" }), 400, "VALIDATION_ERROR");
    expectError(await bad({ extra: true }), 400, "VALIDATION_ERROR");
    expect(ingredientService.create).not.toHaveBeenCalled();
  });
  it("12. POST /ingredients: CLIENT 403; sin token 401; errores del servicio se propagan (409, 422)", async () => {
    expectError(
      await request(app)
        .post(`${API}/ingredients`)
        .set(client())
        .send(ingredientBody),
      403,
      "FORBIDDEN",
    );
    expectError(
      await request(app).post(`${API}/ingredients`).send(ingredientBody),
      401,
      "UNAUTHENTICATED",
    );
    ingredientService.create.mockRejectedValueOnce(
      new AppError(409, "INGREDIENT_CODE_EXISTS", "Código duplicado."),
    );
    expectError(
      await request(app)
        .post(`${API}/ingredients`)
        .set(admin())
        .send(ingredientBody),
      409,
      "INGREDIENT_CODE_EXISTS",
    );
    ingredientService.create.mockRejectedValueOnce(
      new AppError(422, "MISSING_SIZE_VALUES", "Faltan tamaños.", [
        { missing: ["FAMILY"] },
      ]),
    );
    const res = await request(app)
      .post(`${API}/ingredients`)
      .set(admin())
      .send(ingredientBody);
    expectError(res, 422, "MISSING_SIZE_VALUES");
    expect(res.body.error.details).toEqual([{ missing: ["FAMILY"] }]);
  });
  it("13. PUT /ingredients/:id: 200; no admite stock ni active; CLIENT 403; 404", async () => {
    const { stock: _s, active: _a, ...putBody } = ingredientBody;
    ingredientService.update.mockResolvedValueOnce({ id: ID });
    expect(
      (
        await request(app)
          .put(`${API}/ingredients/${ID}`)
          .set(admin())
          .send(putBody)
      ).status,
    ).toBe(200);
    expectError(
      await request(app)
        .put(`${API}/ingredients/${ID}`)
        .set(admin())
        .send(ingredientBody),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .put(`${API}/ingredients/${ID}`)
        .set(client())
        .send(putBody),
      403,
      "FORBIDDEN",
    );
    ingredientService.update.mockRejectedValueOnce(notFound());
    expectError(
      await request(app)
        .put(`${API}/ingredients/${ID}`)
        .set(admin())
        .send(putBody),
      404,
      "NOT_FOUND",
    );
    ingredientService.update.mockRejectedValueOnce(
      new AppError(422, "INGREDIENT_CATEGORY_LOCKED", "Bloqueada.", [
        { presetPizzas: ["Margarita"] },
      ]),
    );
    expectError(
      await request(app)
        .put(`${API}/ingredients/${ID}`)
        .set(admin())
        .send(putBody),
      422,
      "INGREDIENT_CATEGORY_LOCKED",
    );
  });
  it("14. PATCH /ingredients/:id/stock: SET y ADD; validaciones; 422 STOCK_WOULD_BE_NEGATIVE", async () => {
    ingredientService.updateStock.mockResolvedValue({ id: ID });
    const patch = (body, headers = admin()) =>
      request(app)
        .patch(`${API}/ingredients/${ID}/stock`)
        .set(headers)
        .send(body);
    expect((await patch({ operation: "SET", value: 150 })).status).toBe(200);
    expect(ingredientService.updateStock).toHaveBeenLastCalledWith(
      { id: ADMIN_ID, role: "ADMIN" },
      ID,
      { operation: "SET", value: 150 },
    );
    expect((await patch({ operation: "ADD", value: -5 })).status).toBe(200);
    expectError(
      await patch({ operation: "SET", value: -1 }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await patch({ operation: "ADD", value: 0 }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await patch({ operation: "ADD", value: 1.5 }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await patch({ operation: "MUL", value: 2 }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await patch({ operation: "SET", value: 1 }, client()),
      403,
      "FORBIDDEN",
    );
    ingredientService.updateStock.mockRejectedValueOnce(
      new AppError(422, "STOCK_WOULD_BE_NEGATIVE", "Negativo."),
    );
    expectError(
      await patch({ operation: "ADD", value: -999 }),
      422,
      "STOCK_WOULD_BE_NEGATIVE",
    );
    ingredientService.updateStock.mockRejectedValueOnce(notFound());
    expectError(await patch({ operation: "SET", value: 1 }), 404, "NOT_FOUND");
  });
  it("15. PATCH /ingredients/:id/status: 200; body inválido 400; CLIENT 403; 422", async () => {
    ingredientService.setActive.mockResolvedValue({ id: ID, active: false });
    const patch = (body, headers = admin()) =>
      request(app)
        .patch(`${API}/ingredients/${ID}/status`)
        .set(headers)
        .send(body);
    const res = await patch({ active: false });
    expect(res.status).toBe(200);
    expect(ingredientService.setActive).toHaveBeenCalledWith(
      { id: ADMIN_ID, role: "ADMIN" },
      ID,
      false,
    );
    expectError(await patch({ active: "no" }), 400, "VALIDATION_ERROR");
    expectError(await patch({ active: true }, client()), 403, "FORBIDDEN");
    ingredientService.setActive.mockRejectedValueOnce(
      new AppError(422, "MISSING_SIZE_VALUES", "Faltan."),
    );
    expectError(await patch({ active: true }), 422, "MISSING_SIZE_VALUES");
  });
});

describe("16-20. Pizzas predefinidas", () => {
  it("16. GET /preset-pizzas: 200 para ambos roles; includeInactive validado", async () => {
    presetService.list.mockResolvedValue([{ id: ID }]);
    const res = await request(app)
      .get(`${API}/preset-pizzas?includeInactive=true`)
      .set(admin());
    expect(res.body).toEqual({ data: [{ id: ID }] });
    expect(presetService.list).toHaveBeenCalledWith(
      { id: ADMIN_ID, role: "ADMIN" },
      { includeInactive: true },
    );
    expect(
      (await request(app).get(`${API}/preset-pizzas`).set(client())).status,
    ).toBe(200);
    expectError(
      await request(app)
        .get(`${API}/preset-pizzas?includeInactive=maybe`)
        .set(client()),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app).get(`${API}/preset-pizzas`),
      401,
      "UNAUTHENTICATED",
    );
  });
  it("17. GET /preset-pizzas/:id: 200, 400, 404", async () => {
    presetService.getById.mockResolvedValueOnce({ id: ID });
    expect(
      (await request(app).get(`${API}/preset-pizzas/${ID}`).set(client())).body
        .data.id,
    ).toBe(ID);
    expectError(
      await request(app).get(`${API}/preset-pizzas/xyz`).set(client()),
      400,
      "VALIDATION_ERROR",
    );
    presetService.getById.mockRejectedValueOnce(notFound());
    expectError(
      await request(app).get(`${API}/preset-pizzas/${ID}`).set(client()),
      404,
      "NOT_FOUND",
    );
  });
  const body = {
    code: "margherita",
    name: "Margarita",
    description: "Tomate",
    active: true,
    sortOrder: 1,
    recipe,
  };
  it("18. POST /preset-pizzas: 201, normaliza código, sin campo de precio, permisos", async () => {
    presetService.create.mockResolvedValue({ id: ID });
    const res = await request(app)
      .post(`${API}/preset-pizzas`)
      .set(admin())
      .send(body);
    expect(res.status).toBe(201);
    expect(presetService.create.mock.calls[0][0].code).toBe("MARGHERITA");
    expectError(
      await request(app)
        .post(`${API}/preset-pizzas`)
        .set(admin())
        .send({ ...body, price: "5.00" }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .post(`${API}/preset-pizzas`)
        .set(admin())
        .send({ ...body, recipe: [{ ingredientId: uid(1), portions: 4 }] }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app).post(`${API}/preset-pizzas`).set(client()).send(body),
      403,
      "FORBIDDEN",
    );
  });
  it("18. POST /preset-pizzas: propaga 409 y 422 INVALID_RECIPE con violaciones", async () => {
    presetService.create.mockRejectedValueOnce(
      new AppError(409, "PRESET_CODE_EXISTS", "Duplicado."),
    );
    expectError(
      await request(app).post(`${API}/preset-pizzas`).set(admin()).send(body),
      409,
      "PRESET_CODE_EXISTS",
    );
    presetService.create.mockRejectedValueOnce(
      new AppError(409, "PRESET_NAME_EXISTS", "Duplicado."),
    );
    expectError(
      await request(app).post(`${API}/preset-pizzas`).set(admin()).send(body),
      409,
      "PRESET_NAME_EXISTS",
    );
    presetService.create.mockRejectedValueOnce(
      new AppError(422, "INVALID_RECIPE", "Receta inválida.", [
        { code: "DOUGH_REQUIRED" },
      ]),
    );
    const res = await request(app)
      .post(`${API}/preset-pizzas`)
      .set(admin())
      .send(body);
    expectError(res, 422, "INVALID_RECIPE");
    expect(res.body.error.details[0].code).toBe("DOUGH_REQUIRED");
  });
  it("19. PUT /preset-pizzas/:id: 200 sin `active`; 404; 403", async () => {
    const { active: _a, ...putBody } = body;
    presetService.update.mockResolvedValueOnce({ id: ID });
    expect(
      (
        await request(app)
          .put(`${API}/preset-pizzas/${ID}`)
          .set(admin())
          .send(putBody)
      ).status,
    ).toBe(200);
    expectError(
      await request(app)
        .put(`${API}/preset-pizzas/${ID}`)
        .set(admin())
        .send(body),
      400,
      "VALIDATION_ERROR",
    );
    presetService.update.mockRejectedValueOnce(notFound());
    expectError(
      await request(app)
        .put(`${API}/preset-pizzas/${ID}`)
        .set(admin())
        .send(putBody),
      404,
      "NOT_FOUND",
    );
    expectError(
      await request(app)
        .put(`${API}/preset-pizzas/${ID}`)
        .set(client())
        .send(putBody),
      403,
      "FORBIDDEN",
    );
  });
  it("20. PATCH /preset-pizzas/:id/status: 200, 400, 403, 404", async () => {
    presetService.setActive.mockResolvedValueOnce({ id: ID, active: false });
    expect(
      (
        await request(app)
          .patch(`${API}/preset-pizzas/${ID}/status`)
          .set(admin())
          .send({ active: false })
      ).status,
    ).toBe(200);
    expect(presetService.setActive).toHaveBeenCalledWith(ID, false);
    expectError(
      await request(app)
        .patch(`${API}/preset-pizzas/${ID}/status`)
        .set(admin())
        .send({}),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .patch(`${API}/preset-pizzas/${ID}/status`)
        .set(client())
        .send({ active: false }),
      403,
      "FORBIDDEN",
    );
    presetService.setActive.mockRejectedValueOnce(notFound());
    expectError(
      await request(app)
        .patch(`${API}/preset-pizzas/${ID}/status`)
        .set(admin())
        .send({ active: true }),
      404,
      "NOT_FOUND",
    );
  });
});

describe("21. POST /orders/quote", () => {
  const quoteResult = {
    valid: true,
    violations: [],
    items: [],
    totals: { total: "21.31" },
    stock: [],
  };
  it("200 para CLIENT y ADMIN con la lista de ítems validada", async () => {
    quoteService.quote.mockResolvedValue(quoteResult);
    for (const headers of [client(), admin()]) {
      const res = await request(app)
        .post(`${API}/orders/quote`)
        .set(headers)
        .send({ items: [customItem, presetItem] });
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual(quoteResult);
    }
    expect(quoteService.quote).toHaveBeenCalledWith([customItem, presetItem]);
  });
  it("acepta CUSTOM sin masa ni salsa (cálculo parcial en vivo)", async () => {
    quoteService.quote.mockResolvedValue(quoteResult);
    const { doughId: _d, sauceId: _s, ...partial } = customItem;
    expect(
      (
        await request(app)
          .post(`${API}/orders/quote`)
          .set(client())
          .send({ items: [partial] })
      ).status,
    ).toBe(200);
  });
  it("400 por forma del payload: items vacío, > 50, cantidad 0 o 21, porciones 0 o 4, > 30 toppings, tipo inválido", async () => {
    const post = (items) =>
      request(app).post(`${API}/orders/quote`).set(client()).send({ items });
    expectError(await post([]), 400, "VALIDATION_ERROR");
    expectError(
      await post(Array(51).fill(customItem)),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([{ ...customItem, quantity: 0 }]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([{ ...customItem, quantity: 21 }]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([
        { ...customItem, toppings: [{ ingredientId: uid(3), portions: 0 }] },
      ]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([
        { ...customItem, toppings: [{ ingredientId: uid(3), portions: 4 }] },
      ]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([
        {
          ...customItem,
          toppings: Array(31).fill({ ingredientId: uid(3), portions: 1 }),
        },
      ]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([{ ...customItem, sizeCode: "XL" }]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([{ ...customItem, type: "OTRA" }]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([
        {
          ...presetItem,
          extras: Array(31).fill({ ingredientId: uid(3), portions: 1 }),
        },
      ]),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await post([{ ...customItem, campoExtra: 1 }]),
      400,
      "VALIDATION_ERROR",
    );
    expect(quoteService.quote).not.toHaveBeenCalled();
  });
  it("401 sin token", async () => {
    expectError(
      await request(app)
        .post(`${API}/orders/quote`)
        .send({ items: [customItem] }),
      401,
      "UNAUTHENTICATED",
    );
  });
});

describe("22. POST /orders", () => {
  const order = { id: ID, orderNumber: "GP-20261106-0001", status: "PENDING" };
  it("201 para CLIENT con Location y expectedTotal opcional", async () => {
    orderService.create.mockResolvedValue(order);
    const res = await request(app)
      .post(`${API}/orders`)
      .set(client())
      .send({ items: [customItem], expectedTotal: "21.31" });
    expect(res.status).toBe(201);
    expect(res.headers.location).toBe(`/api/v1/orders/${ID}`);
    expect(res.body.data).toEqual(order);
    expect(orderService.create).toHaveBeenCalledWith(CLIENT_ID, {
      items: [customItem],
      expectedTotal: "21.31",
    });
  });
  it("sin expectedTotal también es válido", async () => {
    orderService.create.mockResolvedValue(order);
    expect(
      (
        await request(app)
          .post(`${API}/orders`)
          .set(client())
          .send({ items: [presetItem] })
      ).status,
    ).toBe(201);
  });
  it("ADMIN -> 403 FORBIDDEN (solo el rol Cliente confirma pedidos)", async () => {
    expectError(
      await request(app)
        .post(`${API}/orders`)
        .set(admin())
        .send({ items: [customItem] }),
      403,
      "FORBIDDEN",
    );
    expect(orderService.create).not.toHaveBeenCalled();
  });
  it("401 sin token; 400 por payload o expectedTotal inválido", async () => {
    expectError(
      await request(app)
        .post(`${API}/orders`)
        .send({ items: [customItem] }),
      401,
      "UNAUTHENTICATED",
    );
    expectError(
      await request(app)
        .post(`${API}/orders`)
        .set(client())
        .send({ items: [] }),
      400,
      "VALIDATION_ERROR",
    );
    expectError(
      await request(app)
        .post(`${API}/orders`)
        .set(client())
        .send({ items: [customItem], expectedTotal: "abc" }),
      400,
      "VALIDATION_ERROR",
    );
  });
  it("propaga 409 INSUFFICIENT_STOCK, 409 PRICE_CHANGED y 422 PIZZA_RULES_VIOLATED con detalles", async () => {
    const post = () =>
      request(app)
        .post(`${API}/orders`)
        .set(client())
        .send({ items: [customItem] });
    orderService.create.mockRejectedValueOnce(
      new AppError(
        409,
        "INSUFFICIENT_STOCK",
        "No hay stock suficiente de Queso mozzarella: solicitado 6, disponible 4.",
        [
          {
            ingredientId: uid(3),
            code: "QUE-MOZ",
            name: "Queso mozzarella",
            requested: 6,
            available: 4,
          },
        ],
      ),
    );
    const a = await post();
    expectError(a, 409, "INSUFFICIENT_STOCK");
    expect(a.body.error.details[0]).toMatchObject({
      requested: 6,
      available: 4,
    });
    orderService.create.mockRejectedValueOnce(
      new AppError(409, "PRICE_CHANGED", "Cambió.", [
        { quote: { items: [], totals: {} } },
      ]),
    );
    expectError(await post(), 409, "PRICE_CHANGED");
    orderService.create.mockRejectedValueOnce(
      new AppError(422, "PIZZA_RULES_VIOLATED", "Reglas.", [
        { code: "MIN_TOPPINGS_NOT_MET" },
      ]),
    );
    expectError(await post(), 422, "PIZZA_RULES_VIOLATED");
  });
});

describe("23-24. Consulta de pedidos", () => {
  it("23. GET /orders: el servicio recibe usuario y filtros; respuesta paginada tal cual", async () => {
    orderService.list.mockResolvedValue({
      data: [],
      page: 1,
      pageSize: 20,
      total: 0,
    });
    const res = await request(app)
      .get(
        `${API}/orders?status=PENDING&from=2026-11-01&to=2026-11-30&search=ana&page=1&pageSize=20`,
      )
      .set(admin());
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ data: [], page: 1, pageSize: 20, total: 0 });
    expect(orderService.list).toHaveBeenCalledWith(
      { id: ADMIN_ID, role: "ADMIN" },
      {
        status: "PENDING",
        from: "2026-11-01",
        to: "2026-11-30",
        search: "ana",
        page: 1,
        pageSize: 20,
      },
    );
  });
  it("23. GET /orders: CLIENT lista con su propio id (filtro por dueño en el servicio)", async () => {
    orderService.list.mockResolvedValue({
      data: [],
      page: 1,
      pageSize: 20,
      total: 0,
    });
    await request(app).get(`${API}/orders`).set(client());
    expect(orderService.list.mock.calls[0][0]).toEqual({
      id: CLIENT_ID,
      role: "CLIENT",
    });
  });
  it("23. GET /orders: filtros inválidos -> 400; sin token -> 401", async () => {
    for (const q of [
      "status=OTRO",
      "from=2026-13-45",
      "from=ayer",
      "pageSize=101",
      "page=0",
      "from=2026-12-01&to=2026-11-01",
    ]) {
      expectError(
        await request(app).get(`${API}/orders?${q}`).set(client()),
        400,
        "VALIDATION_ERROR",
      );
    }
    expectError(
      await request(app).get(`${API}/orders`),
      401,
      "UNAUTHENTICATED",
    );
  });
  it("24. GET /orders/:id: 200; 400 id no UUID; 404 ajeno u inexistente; 401", async () => {
    orderService.getById.mockResolvedValueOnce({ id: ID });
    const ok = await request(app).get(`${API}/orders/${ID}`).set(client());
    expect(ok.body).toEqual({ data: { id: ID } });
    expect(orderService.getById).toHaveBeenCalledWith(
      { id: CLIENT_ID, role: "CLIENT" },
      ID,
    );
    expectError(
      await request(app).get(`${API}/orders/no-uuid`).set(client()),
      400,
      "VALIDATION_ERROR",
    );
    orderService.getById.mockRejectedValueOnce(
      notFound("Pedido no encontrado."),
    );
    expectError(
      await request(app).get(`${API}/orders/${ID}`).set(client()),
      404,
      "NOT_FOUND",
    );
    expectError(
      await request(app).get(`${API}/orders/${ID}`),
      401,
      "UNAUTHENTICATED",
    );
  });
});

describe("25. PATCH /orders/:id/status", () => {
  const patch = (body, headers = admin()) =>
    request(app).patch(`${API}/orders/${ID}/status`).set(headers).send(body);
  it("ADMIN 200 con el id del admin y el nuevo estado", async () => {
    orderService.updateStatus.mockResolvedValue({
      id: ID,
      status: "IN_PREPARATION",
    });
    const res = await patch({ status: "IN_PREPARATION" });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("IN_PREPARATION");
    expect(orderService.updateStatus).toHaveBeenCalledWith(
      ADMIN_ID,
      ID,
      "IN_PREPARATION",
    );
  });
  it("CLIENT -> 403 (US-20); sin token 401; estado inválido 400; id inválido 400", async () => {
    expectError(
      await patch({ status: "IN_PREPARATION" }, client()),
      403,
      "FORBIDDEN",
    );
    expectError(
      await request(app)
        .patch(`${API}/orders/${ID}/status`)
        .send({ status: "DELIVERED" }),
      401,
      "UNAUTHENTICATED",
    );
    expectError(await patch({ status: "CANCELLED" }), 400, "VALIDATION_ERROR");
    expectError(
      await request(app)
        .patch(`${API}/orders/xx/status`)
        .set(admin())
        .send({ status: "DELIVERED" }),
      400,
      "VALIDATION_ERROR",
    );
    expect(orderService.updateStatus).not.toHaveBeenCalled();
  });
  it("IT-B02: DELIVERED -> PENDING -> 422 INVALID_STATUS_TRANSITION con from/to/allowed", async () => {
    orderService.updateStatus.mockRejectedValue(
      new AppError(422, "INVALID_STATUS_TRANSITION", "No permitido.", [
        { from: "DELIVERED", to: "PENDING", allowed: [] },
      ]),
    );
    const res = await patch({ status: "PENDING" });
    expectError(res, 422, "INVALID_STATUS_TRANSITION");
    expect(res.body.error.details).toEqual([
      { from: "DELIVERED", to: "PENDING", allowed: [] },
    ]);
  });
  it("404 si el pedido no existe", async () => {
    orderService.updateStatus.mockRejectedValue(notFound());
    expectError(await patch({ status: "IN_PREPARATION" }), 404, "NOT_FOUND");
  });
});
