import { describe, expect, it } from "vitest";
import { dec, money, roundHalfUp, vatOf } from "../../src/utils/money.js";
import { formatOrderNumber } from "../../src/utils/orderNumber.js";
import {
  dateOnlyToDate,
  dateToDateOnly,
  localDateString,
} from "../../src/utils/dates.js";
import { EnvError, loadEnv } from "../../src/config/env.js";

describe("money", () => {
  it("formatea siempre con 2 decimales", () => {
    expect(money("7.5")).toBe("7.50");
    expect(money(0)).toBe("0.00");
    expect(money("12")).toBe("12.00");
  });
  it("half-up (no half-even): 0.045 -> 0.05, 0.975 -> 0.98, 1.005 -> 1.01", () => {
    expect(roundHalfUp("0.045").toFixed(2)).toBe("0.05");
    expect(roundHalfUp("0.975").toFixed(2)).toBe("0.98");
    expect(roundHalfUp("1.005").toFixed(2)).toBe("1.01");
    expect(roundHalfUp("0.0525").toFixed(2)).toBe("0.05");
  });
  it("sin errores de coma flotante: 0.1 + 0.2 = 0.30", () => {
    expect(money(dec("0.1").plus(dec("0.2")))).toBe("0.30");
  });
  it("vatOf aplica 15 % sobre el subtotal", () => {
    expect(vatOf("15.40").toFixed(2)).toBe("2.31");
  });
});

describe("número de orden (UT-B09)", () => {
  it("formato GP-AAAAMMDD-NNNN", () => {
    expect(formatOrderNumber("2026-11-06", 1)).toBe("GP-20261106-0001");
    expect(formatOrderNumber("2026-11-06", 42)).toBe("GP-20261106-0042");
  });
  it("9999 -> 9999 y 10000 crece a 5 dígitos sin truncar", () => {
    expect(formatOrderNumber("2026-11-06", 9999)).toBe("GP-20261106-9999");
    expect(formatOrderNumber("2026-11-06", 10000)).toBe("GP-20261106-10000");
  });
});

describe("fechas (zona horaria del servidor)", () => {
  it("localDateString usa componentes locales", () => {
    expect(localDateString(new Date(2026, 10, 6, 23, 59))).toBe("2026-11-06");
    expect(localDateString(new Date(2026, 0, 2, 0, 1))).toBe("2026-01-02");
  });
  it("ida y vuelta de columna DATE", () => {
    expect(dateToDateOnly(dateOnlyToDate("2026-11-06"))).toBe("2026-11-06");
  });
});

describe("validación de variables de entorno", () => {
  const base = {
    DATABASE_URL: "postgresql://u:p@h:5432/db?schema=public",
    JWT_SECRET: "a".repeat(40),
    JWT_REFRESH_SECRET: "b".repeat(40),
  };
  it("acepta lo mínimo y aplica valores por defecto", () => {
    const env = loadEnv({ ...base, NODE_ENV: "test", BCRYPT_COST: "4" });
    expect(env.PORT).toBe(3000);
    expect(env.JWT_ACCESS_EXPIRES_IN).toBe("15m");
    expect(env.JWT_REFRESH_EXPIRES_IN).toBe("7d");
    expect(env.RATE_LIMIT_MAX).toBe(300);
  });
  it("si falta una variable, el mensaje nombra la variable y no imprime valores", () => {
    let error;
    try {
      loadEnv({
        DATABASE_URL: base.DATABASE_URL,
        JWT_REFRESH_SECRET: base.JWT_REFRESH_SECRET,
      });
    } catch (e) {
      error = e;
    }
    expect(error).toBeInstanceOf(EnvError);
    expect(error.message).toContain("JWT_SECRET (falta)");
    expect(error.message).not.toContain(base.DATABASE_URL);
    expect(error.message).not.toContain(base.JWT_REFRESH_SECRET);
  });
  it("un valor inválido se reporta como tal, sin mostrarlo", () => {
    expect(() => loadEnv({ ...base, PORT: "abc" })).toThrow(
      /PORT \(valor inválido\)/,
    );
  });
  it("en producción exige secretos largos y distintos", () => {
    const prod = { ...base, NODE_ENV: "production" };
    expect(() => loadEnv({ ...prod, JWT_SECRET: "corto" })).toThrow(
      /JWT_SECRET \(mínimo 32/,
    );
    expect(() =>
      loadEnv({ ...prod, JWT_REFRESH_SECRET: base.JWT_SECRET }),
    ).toThrow(/distinto/);
  });
});
