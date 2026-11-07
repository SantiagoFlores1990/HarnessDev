import { AppError } from "../utils/AppError.js";
import { verifyAccessToken } from "../services/token.service.js";

/** Valida el access JWT (sin consultar BD) y fija req.user = { id, role }. */
export function requireAuth(req, _res, next) {
  const header = req.headers.authorization ?? "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || !token) {
    return next(new AppError(401, "UNAUTHENTICATED", "Debes iniciar sesión."));
  }
  try {
    const claims = verifyAccessToken(token);
    req.user = { id: claims.sub, role: claims.role };
    return next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return next(
        new AppError(
          401,
          "TOKEN_EXPIRED",
          "La sesión caducó. Renueva el acceso.",
        ),
      );
    }
    return next(
      new AppError(
        401,
        "UNAUTHENTICATED",
        "Token inválido. Inicia sesión de nuevo.",
      ),
    );
  }
}
