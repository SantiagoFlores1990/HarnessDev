import { z } from "zod";

// Mensajes de validación en español (el frontend decide por `code`, no por `message`).
z.setErrorMap((issue, ctx) => {
  switch (issue.code) {
    case z.ZodIssueCode.invalid_type:
      return {
        message:
          issue.received === "undefined"
            ? "Campo obligatorio."
            : `Tipo de dato inválido (se esperaba ${issue.expected}).`,
      };
    case z.ZodIssueCode.unrecognized_keys:
      return { message: `Campo(s) no permitido(s): ${issue.keys.join(", ")}.` };
    case z.ZodIssueCode.too_small:
      if (issue.type === "string")
        return { message: `Debe tener al menos ${issue.minimum} caracteres.` };
      if (issue.type === "array")
        return { message: `Debe tener al menos ${issue.minimum} elemento(s).` };
      return { message: `Debe ser mayor o igual a ${issue.minimum}.` };
    case z.ZodIssueCode.too_big:
      if (issue.type === "string")
        return {
          message: `Debe tener como máximo ${issue.maximum} caracteres.`,
        };
      if (issue.type === "array")
        return {
          message: `Debe tener como máximo ${issue.maximum} elemento(s).`,
        };
      return { message: `Debe ser menor o igual a ${issue.maximum}.` };
    case z.ZodIssueCode.invalid_string:
      if (issue.validation === "email") return { message: "Email inválido." };
      if (issue.validation === "uuid")
        return { message: "Identificador inválido." };
      return { message: "Formato inválido." };
    case z.ZodIssueCode.invalid_enum_value:
      return {
        message: `Valor no permitido. Opciones: ${issue.options.join(", ")}.`,
      };
    case z.ZodIssueCode.invalid_union_discriminator:
      return {
        message: `Valor no permitido. Opciones: ${issue.options.join(", ")}.`,
      };
    default:
      return { message: ctx.defaultError };
  }
});
