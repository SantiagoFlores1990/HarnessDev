/**
 * validate({ params, query, body }) — parsea con Zod y reemplaza req.params/query/body por los
 * valores ya tipados y normalizados. Los errores los traduce errorHandler a 400 VALIDATION_ERROR.
 */
export const validate = (schemas) => (req, _res, next) => {
  try {
    if (schemas.params) req.params = schemas.params.parse(req.params);
    if (schemas.query) req.query = schemas.query.parse(req.query);
    if (schemas.body) req.body = schemas.body.parse(req.body ?? {});
    next();
  } catch (err) {
    next(err);
  }
};
