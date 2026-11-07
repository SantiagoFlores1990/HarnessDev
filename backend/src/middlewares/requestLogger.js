import { logger } from "../lib/logger.js";

/** Registra método, ruta (sin query), estado y duración. Nunca cabeceras ni cuerpo. */
export function requestLogger(req, res, next) {
  const start = process.hrtime.bigint();
  res.on("finish", () => {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    logger.info(
      {
        method: req.method,
        path: req.originalUrl.split("?")[0],
        status: res.statusCode,
        ms: Math.round(ms),
      },
      "request",
    );
  });
  next();
}
