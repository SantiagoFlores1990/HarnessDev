// Se ejecuta antes de cada archivo de prueba.
// REGLA: las pruebas JAMÁS tocan el esquema `public`. Cualquier PrismaClient del proceso de
// pruebas apunta a DATABASE_URL_TEST (esquema `test`) o, si no existe, a una URL inválida
// (las pruebas con BD real se omiten; las demás usan dobles y nunca consultan la base).
process.env.DATABASE_URL =
  process.env.DATABASE_URL_TEST ||
  "postgresql://invalid:invalid@127.0.0.1:1/invalid?schema=test";
