import * as authService from "../services/auth.service.js";

export const register = async (req, res) => {
  res.status(201).json({ data: await authService.register(req.body) });
};

export const login = async (req, res) => {
  res.json({ data: await authService.login(req.body) });
};

export const refresh = async (req, res) => {
  res.json({ data: await authService.refresh(req.body) });
};

export const logout = async (req, res) => {
  await authService.logout(req.body);
  res.status(204).end();
};

export const me = async (req, res) => {
  res.json({ data: await authService.me(req.user.id) });
};
