import jwt from "jsonwebtoken";
import { signAccessToken } from "../../src/services/token.service.js";
import { uid } from "./catalog.js";

export const ADMIN_ID = uid(9001);
export const CLIENT_ID = uid(9002);
export const OTHER_CLIENT_ID = uid(9003);

export const adminToken = () =>
  signAccessToken({ id: ADMIN_ID, role: "ADMIN" }).token;
export const clientToken = (id = CLIENT_ID) =>
  signAccessToken({ id, role: "CLIENT" }).token;
export const bearer = (token) => ({ Authorization: `Bearer ${token}` });

export const expiredToken = () =>
  jwt.sign({ role: "CLIENT", type: "access" }, process.env.JWT_SECRET, {
    subject: CLIENT_ID,
    expiresIn: -10,
  });
