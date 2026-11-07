import bcrypt from "bcryptjs";
import { prisma } from "../lib/prisma.js";
import { getEnv } from "../config/env.js";
import { AppError, forbidden } from "../utils/AppError.js";
import { ROLES } from "../config/constants.js";
import {
  hashToken,
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from "./token.service.js";

const invalidRefresh = () =>
  new AppError(
    401,
    "INVALID_REFRESH_TOKEN",
    "La sesión no es válida. Inicia sesión de nuevo.",
  );

const publicUser = (u) => ({
  id: u.id,
  fullName: u.fullName,
  email: u.email,
  role: u.role.code,
});

let dummyHash;
const getDummyHash = () =>
  (dummyHash ??= bcrypt.hashSync("no-such-user", getEnv().BCRYPT_COST));

async function issueTokens(db, user) {
  const access = signAccessToken({ id: user.id, role: user.role.code });
  const refresh = signRefreshToken(user.id);
  await db.refreshToken.create({
    data: {
      id: refresh.jti,
      userId: user.id,
      tokenHash: hashToken(refresh.token),
      expiresAt: refresh.expiresAt,
    },
  });
  return {
    accessToken: access.token,
    accessTokenExpiresIn: access.expiresIn,
    refreshToken: refresh.token,
    refreshTokenExpiresIn: refresh.expiresIn,
  };
}

export async function register({ fullName, email, password }) {
  const role = await prisma.role.findUnique({ where: { code: ROLES.CLIENT } });
  if (!role) {
    throw new AppError(
      500,
      "INTERNAL_ERROR",
      "Falta el rol CLIENT. Ejecuta el seed (npm run db:seed).",
    );
  }
  const emailTaken = () =>
    new AppError(
      409,
      "EMAIL_ALREADY_EXISTS",
      "Ya existe una cuenta con ese email.",
    );
  if (await prisma.user.findUnique({ where: { email } })) throw emailTaken();
  const passwordHash = await bcrypt.hash(password, getEnv().BCRYPT_COST);
  let user;
  try {
    user = await prisma.user.create({
      data: { fullName, email, passwordHash, roleId: role.id },
      include: { role: true },
    });
  } catch (err) {
    if (err?.code === "P2002") throw emailTaken();
    throw err;
  }
  return { user: publicUser(user), ...(await issueTokens(prisma, user)) };
}

export async function login({ email, password }) {
  const user = await prisma.user.findUnique({
    where: { email },
    include: { role: true },
  });
  // Siempre se compara contra un hash para igualar tiempos de respuesta.
  const ok = await bcrypt.compare(
    password,
    user?.passwordHash ?? getDummyHash(),
  );
  if (!user || !ok) {
    throw new AppError(
      401,
      "INVALID_CREDENTIALS",
      "Email o contraseña incorrectos.",
    );
  }
  if (!user.active) throw forbidden("Tu cuenta está desactivada.");
  // Purga de refresh tokens caducados del usuario (ADR-006).
  await prisma.refreshToken.deleteMany({
    where: { userId: user.id, expiresAt: { lt: new Date() } },
  });
  return { user: publicUser(user), ...(await issueTokens(prisma, user)) };
}

async function revokeAll(userId) {
  await prisma.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function refresh({ refreshToken }) {
  try {
    verifyRefreshToken(refreshToken);
  } catch {
    throw invalidRefresh();
  }
  const record = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashToken(refreshToken) },
    include: { user: { include: { role: true } } },
  });
  if (!record) throw invalidRefresh();
  if (record.revokedAt) {
    // Reutilización de un token ya rotado/revocado: se revocan todos los del usuario.
    await revokeAll(record.userId);
    throw invalidRefresh();
  }
  if (record.expiresAt <= new Date()) throw invalidRefresh();
  if (!record.user.active) throw forbidden("Tu cuenta está desactivada.");

  const next = signRefreshToken(record.userId);
  const access = signAccessToken({
    id: record.user.id,
    role: record.user.role.code,
  });
  const reused = await prisma.$transaction(async (tx) => {
    const claimed = await tx.refreshToken.updateMany({
      where: { id: record.id, revokedAt: null },
      data: { revokedAt: new Date(), replacedById: next.jti },
    });
    if (claimed.count === 0) return true;
    await tx.refreshToken.create({
      data: {
        id: next.jti,
        userId: record.userId,
        tokenHash: hashToken(next.token),
        expiresAt: next.expiresAt,
      },
    });
    return false;
  });
  if (reused) {
    await revokeAll(record.userId);
    throw invalidRefresh();
  }
  return {
    accessToken: access.token,
    accessTokenExpiresIn: access.expiresIn,
    refreshToken: next.token,
    refreshTokenExpiresIn: next.expiresIn,
  };
}

/** Idempotente: token desconocido o ya revocado también termina bien. */
export async function logout({ refreshToken }) {
  await prisma.refreshToken.updateMany({
    where: { tokenHash: hashToken(refreshToken), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function me(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { role: true },
  });
  if (!user)
    throw new AppError(401, "UNAUTHENTICATED", "Debes iniciar sesión.");
  if (!user.active) throw forbidden("Tu cuenta está desactivada.");
  return publicUser(user);
}
