import express from "express";
import helmet from "helmet";
import cors from "cors";
import { getEnv } from "./config/env.js";
import { buildRouter } from "./routes/index.js";
import { createGlobalLimiter } from "./middlewares/rateLimiters.js";
import { notFoundRoute } from "./middlewares/notFound.js";
import { errorHandler } from "./middlewares/errorHandler.js";
import { requestLogger } from "./middlewares/requestLogger.js";

/** Construye la app Express (exportada para Supertest; no abre el puerto). */
export function createApp(env = getEnv()) {
  const app = express();
  app.disable("x-powered-by");

  app.use(helmet());
  app.use(
    cors({
      // La app Windows (dart:io) no envía Origin: se acepta. Los navegadores solo desde la lista blanca.
      origin: (origin, cb) =>
        cb(null, !origin || env.corsOrigins.includes(origin)),
    }),
  );
  app.use(requestLogger);
  app.use(createGlobalLimiter(env));
  app.use(express.json({ limit: "100kb" }));

  app.use("/api/v1", buildRouter(env));

  app.use(notFoundRoute);
  app.use(errorHandler);
  return app;
}
