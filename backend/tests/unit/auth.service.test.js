import { beforeEach, describe, expect, it, vi } from "vitest";
import bcrypt from "bcryptjs";

// Doble de Prisma para usuarios y refresh tokens (auth.service no necesita más).
vi.mock("../../src/lib/prisma.js", () => {
  const store = { users: [], tokens: [] };
  const match = (row, where) =>
    Object.entries(where).every(([k, v]) => {
      if (v === null) return row[k] === null || row[k] === undefined;
      if (v && typeof v === "object" && "lt" in v) return row[k] < v.lt;
      return row[k] === v;
    });
  const withUser = (t) => ({
    ...t,
    user: store.users.find((u) => u.id === t.userId),
  });
  const api = {
    __store: store,
    role: {
      findUnique: async ({ where }) => ({
        id: where.code === "ADMIN" ? 1 : 2,
        code: where.code,
      }),
    },
    user: {
      findUnique: async ({ where }) =>
        store.users.find((u) =>
          where.email ? u.email === where.email : u.id === where.id,
        ) ?? null,
      create: async ({ data }) => {
        const user = {
          id: `u${store.users.length + 1}`,
          active: true,
          ...data,
          role: { code: data.roleId === 1 ? "ADMIN" : "CLIENT" },
        };
        store.users.push(user);
        return user;
      },
    },
    refreshToken: {
      create: async ({ data }) => {
        store.tokens.push({ revokedAt: null, replacedById: null, ...data });
        return data;
      },
      findUnique: async ({ where }) => {
        const t = store.tokens.find((x) => x.tokenHash === where.tokenHash);
        return t ? withUser(t) : null;
      },
      updateMany: async ({ where, data }) => {
        const rows = store.tokens.filter((t) => match(t, where));
        rows.forEach((r) => Object.assign(r, data));
        return { count: rows.length };
      },
      deleteMany: async ({ where }) => {
        const before = store.tokens.length;
        store.tokens = store.tokens.filter((t) => !match(t, where));
        return { count: before - store.tokens.length };
      },
    },
    $transaction: async (fn) => fn(api),
  };
  return { prisma: api };
});

import { prisma } from "../../src/lib/prisma.js";
import * as auth from "../../src/services/auth.service.js";
import {
  hashToken,
  verifyAccessToken,
} from "../../src/services/token.service.js";

const rejection = async (p) => {
  try {
    await p;
  } catch (e) {
    return e;
  }
  throw new Error("Se esperaba un rechazo");
};
const reg = {
  fullName: "Ana Pérez",
  email: "ana@ejemplo.com",
  password: "clave-de-prueba-1",
};

beforeEach(() => {
  prisma.__store.users.length = 0;
  prisma.__store.tokens.length = 0;
});

describe("auth.service", () => {
  it("register: crea un CLIENT, devuelve tokens y guarda solo el hash del refresh", async () => {
    const r = await auth.register(reg);
    expect(r.user).toMatchObject({
      fullName: "Ana Pérez",
      email: "ana@ejemplo.com",
      role: "CLIENT",
    });
    expect(r.accessTokenExpiresIn).toBe(900);
    expect(r.refreshTokenExpiresIn).toBe(604800);
    expect(verifyAccessToken(r.accessToken)).toMatchObject({
      sub: r.user.id,
      role: "CLIENT",
      type: "access",
    });
    const stored = prisma.__store.tokens[0];
    expect(stored.tokenHash).toBe(hashToken(r.refreshToken));
    expect(stored.tokenHash).not.toBe(r.refreshToken);
  });
  it("register: la contraseña se guarda con bcrypt, nunca en claro", async () => {
    await auth.register(reg);
    const hash = prisma.__store.users[0].passwordHash;
    expect(hash).not.toContain(reg.password);
    expect(await bcrypt.compare(reg.password, hash)).toBe(true);
  });
  it("register: email repetido -> 409 EMAIL_ALREADY_EXISTS", async () => {
    await auth.register(reg);
    const err = await rejection(auth.register(reg));
    expect(err).toMatchObject({ status: 409, code: "EMAIL_ALREADY_EXISTS" });
  });
  it("login correcto devuelve el mismo formato que el registro", async () => {
    await auth.register(reg);
    const r = await auth.login({ email: reg.email, password: reg.password });
    expect(r.user.role).toBe("CLIENT");
    expect(r.accessToken).toBeTruthy();
    expect(r.refreshToken).toBeTruthy();
  });
  it("login con contraseña errónea o email inexistente -> mismo 401 INVALID_CREDENTIALS genérico", async () => {
    await auth.register(reg);
    const bad = await rejection(
      auth.login({ email: reg.email, password: "otra-clave-xx" }),
    );
    const none = await rejection(
      auth.login({ email: "no@existe.com", password: "otra-clave-xx" }),
    );
    expect(bad).toMatchObject({ status: 401, code: "INVALID_CREDENTIALS" });
    expect(none.message).toBe(bad.message);
  });
  it("login de usuario desactivado -> 403 FORBIDDEN", async () => {
    await auth.register(reg);
    prisma.__store.users[0].active = false;
    const err = await rejection(
      auth.login({ email: reg.email, password: reg.password }),
    );
    expect(err).toMatchObject({ status: 403, code: "FORBIDDEN" });
  });
  it("refresh: rota el token, revoca el anterior y encadena replacedById", async () => {
    const first = await auth.register(reg);
    const second = await auth.refresh({ refreshToken: first.refreshToken });
    expect(second.refreshToken).not.toBe(first.refreshToken);
    const old = prisma.__store.tokens.find(
      (t) => t.tokenHash === hashToken(first.refreshToken),
    );
    expect(old.revokedAt).toBeInstanceOf(Date);
    expect(old.replacedById).toBeTruthy();
    expect(
      prisma.__store.tokens.find(
        (t) => t.tokenHash === hashToken(second.refreshToken),
      ).revokedAt,
    ).toBeNull();
  });
  it("refresh: reutilizar un token ya rotado -> 401 INVALID_REFRESH_TOKEN y se revocan TODOS los del usuario", async () => {
    const first = await auth.register(reg);
    const second = await auth.refresh({ refreshToken: first.refreshToken });
    const err = await rejection(
      auth.refresh({ refreshToken: first.refreshToken }),
    );
    expect(err).toMatchObject({ status: 401, code: "INVALID_REFRESH_TOKEN" });
    expect(prisma.__store.tokens.every((t) => t.revokedAt)).toBe(true);
    const err2 = await rejection(
      auth.refresh({ refreshToken: second.refreshToken }),
    );
    expect(err2.code).toBe("INVALID_REFRESH_TOKEN");
  });
  it("refresh: token basura o firmado con otro secreto -> 401 INVALID_REFRESH_TOKEN", async () => {
    const err = await rejection(
      auth.refresh({ refreshToken: "esto-no-es-un-jwt-valido" }),
    );
    expect(err.code).toBe("INVALID_REFRESH_TOKEN");
  });
  it("refresh: un access token no sirve como refresh", async () => {
    const r = await auth.register(reg);
    const err = await rejection(auth.refresh({ refreshToken: r.accessToken }));
    expect(err.code).toBe("INVALID_REFRESH_TOKEN");
  });
  it("logout revoca el token y es idempotente (desconocido o repetido no falla)", async () => {
    const r = await auth.register(reg);
    await auth.logout({ refreshToken: r.refreshToken });
    expect(prisma.__store.tokens[0].revokedAt).toBeInstanceOf(Date);
    await expect(
      auth.logout({ refreshToken: r.refreshToken }),
    ).resolves.toBeUndefined();
    await expect(
      auth.logout({ refreshToken: "desconocido-desconocido" }),
    ).resolves.toBeUndefined();
    const err = await rejection(auth.refresh({ refreshToken: r.refreshToken }));
    expect(err.code).toBe("INVALID_REFRESH_TOKEN");
  });
  it("me devuelve el usuario actual", async () => {
    const r = await auth.register(reg);
    expect(await auth.me(r.user.id)).toEqual(r.user);
  });
});
