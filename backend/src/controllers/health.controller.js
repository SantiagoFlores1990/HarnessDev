import { checkHealth } from "../services/health.service.js";

export const health = async (_req, res) => {
  res.json({ data: await checkHealth() });
};
