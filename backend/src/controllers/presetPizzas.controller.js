import * as presetService from "../services/presetPizza.service.js";

export const list = async (req, res) => {
  res.json({ data: await presetService.list(req.user, req.query) });
};

export const getById = async (req, res) => {
  res.json({ data: await presetService.getById(req.user, req.params.id) });
};

export const create = async (req, res) => {
  res.status(201).json({ data: await presetService.create(req.body) });
};

export const update = async (req, res) => {
  res.json({ data: await presetService.update(req.params.id, req.body) });
};

export const setStatus = async (req, res) => {
  res.json({
    data: await presetService.setActive(req.params.id, req.body.active),
  });
};
