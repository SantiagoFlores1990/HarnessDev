import { forbidden } from "../utils/AppError.js";

/** Autorización por rol. Debe ir después de requireAuth. */
export const requireRole =
  (...roles) =>
  (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.role)) return next(forbidden());
    return next();
  };
