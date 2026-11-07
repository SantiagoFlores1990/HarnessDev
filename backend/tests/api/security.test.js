import { describe, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";

vi.mock("../../src/services/health.service.js", () => ({
  checkHealth: async () => ({
    status: "ok",
    database: "ok",
    version: "0.1.0",
    time: "x",
  }),
}));

import { createApp } from "../../src/app.js";
import { createLimiter } from "../../src/middlewares/rateLimiters.js";
import { errorHandler } from "../../src/middlewares/errorHandler.js";
import { loadEnv } from "../../src/config/env.js";

describe("Rate limit (429 RATE_LIMITED con el formato de error uniforme)", () => {
  it("al superar el máximo responde 429 RATE_LIMITED", async () => {
    const app = express();
    app.use(createLimiter({ windowMs: 60000, max: 2 }));
    app.get("/ping", (_req, res) => res.json({ ok: true }));
    app.use(errorHandler);
    expect((await request(app).get("/ping")).status).toBe(200);
    expect((await request(app).get("/ping")).status).toBe(200);
    const res = await request(app).get("/ping");
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe("RATE_LIMITED");
    expect(res.body.error.details).toEqual([]);
  });

  it("el limitador de autenticación de la app aplica a /auth/login", async () => {
    const env = { ...loadEnv(process.env), AUTH_RATE_LIMIT_MAX: 2 };
    const app = createApp(env);
    const login = () => request(app).post("/api/v1/auth/login").send({});
    expect((await login()).status).toBe(400);
    expect((await login()).status).toBe(400);
    const res = await login();
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe("RATE_LIMITED");
  });
});

describe("CORS con lista blanca", () => {
  const app = createApp();
  it("origen permitido recibe Access-Control-Allow-Origin", async () => {
    const res = await request(app)
      .get("/api/v1/health")
      .set("Origin", "http://localhost:3000");
    expect(res.headers["access-control-allow-origin"]).toBe(
      "http://localhost:3000",
    );
  });
  it("origen no permitido no recibe la cabecera", async () => {
    const res = await request(app)
      .get("/api/v1/health")
      .set("Origin", "http://malo.example");
    expect(res.headers["access-control-allow-origin"]).toBeUndefined();
  });
  it("sin Origin (app Windows) se atiende normalmente", async () => {
    expect((await request(app).get("/api/v1/health")).status).toBe(200);
  });
});
