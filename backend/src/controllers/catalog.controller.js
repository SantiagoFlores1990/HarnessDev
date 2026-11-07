import * as catalogService from "../services/catalog.service.js";

export const sizes = async (_req, res) => {
  res.json({ data: await catalogService.listSizes() });
};

export const categories = async (_req, res) => {
  res.json({ data: await catalogService.listCategories() });
};

export const vatRates = async (_req, res) => {
  res.json({ data: await catalogService.listVatRates() });
};
