import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { getEnv } from "../config/env.js";

const ALG = { algorithm: "HS256" };

const ttlSeconds = (token) => {
  const { iat, exp } = jwt.decode(token);
  return exp - iat;
};

/** Access JWT: sub, role, type:"access" (ADR-006). */
export function signAccessToken(user) {
  const env = getEnv();
  const token = jwt.sign({ role: user.role, type: "access" }, env.JWT_SECRET, {
    ...ALG,
    subject: user.id,
    expiresIn: env.JWT_ACCESS_EXPIRES_IN,
  });
  return { token, expiresIn: ttlSeconds(token) };
}

export function verifyAccessToken(token) {
  const claims = jwt.verify(token, getEnv().JWT_SECRET, {
    algorithms: ["HS256"],
  });
  if (claims.type !== "access") throw new Error("Tipo de token inválido");
  return claims;
}

/** Refresh JWT con jti = id de la fila en refresh_tokens. */
export function signRefreshToken(userId) {
  const env = getEnv();
  const jti = crypto.randomUUID();
  const token = jwt.sign({ type: "refresh" }, env.JWT_REFRESH_SECRET, {
    ...ALG,
    subject: userId,
    jwtid: jti,
    expiresIn: env.JWT_REFRESH_EXPIRES_IN,
  });
  const { exp } = jwt.decode(token);
  return {
    token,
    jti,
    expiresAt: new Date(exp * 1000),
    expiresIn: ttlSeconds(token),
  };
}

export function verifyRefreshToken(token) {
  const claims = jwt.verify(token, getEnv().JWT_REFRESH_SECRET, {
    algorithms: ["HS256"],
  });
  if (claims.type !== "refresh" || !claims.jti)
    throw new Error("Tipo de token inválido");
  return claims;
}

/** En BD solo se guarda el SHA-256 del refresh token. */
export const hashToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");
