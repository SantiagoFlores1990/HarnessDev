import * as ingredientService from "../services/ingredient.service.js";

export const list = async (req, res) => {
  res.json(await ingredientService.list(req.user, req.query));
};

export const getById = async (req, res) => {
  res.json({ data: await ingredientService.getById(req.user, req.params.id) });
};

export const create = async (req, res) => {
  res
    .status(201)
    .json({ data: await ingredientService.create(req.user, req.body) });
};

export const update = async (req, res) => {
  res.json({
    data: await ingredientService.update(req.user, req.params.id, req.body),
  });
};

export const updateStock = async (req, res) => {
  res.json({
    data: await ingredientService.updateStock(
      req.user,
      req.params.id,
      req.body,
    ),
  });
};

export const setStatus = async (req, res) => {
  res.json({
    data: await ingredientService.setActive(
      req.user,
      req.params.id,
      req.body.active,
    ),
  });
};
