import * as orderService from "../services/order.service.js";
import * as quoteService from "../services/quote.service.js";

export const quote = async (req, res) => {
  res.json({ data: await quoteService.quote(req.body.items) });
};

export const create = async (req, res) => {
  const order = await orderService.create(req.user.id, req.body);
  res.status(201).location(`/api/v1/orders/${order.id}`).json({ data: order });
};

export const list = async (req, res) => {
  res.json(await orderService.list(req.user, req.query));
};

export const getById = async (req, res) => {
  res.json({ data: await orderService.getById(req.user, req.params.id) });
};

export const updateStatus = async (req, res) => {
  res.json({
    data: await orderService.updateStatus(
      req.user.id,
      req.params.id,
      req.body.status,
    ),
  });
};
