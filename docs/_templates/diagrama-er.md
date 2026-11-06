# Diagrama Entidad-Relación — Fase <N>

```mermaid
erDiagram
    USER ||--o{ ORDER : realiza
    ORDER ||--|{ ORDER_ITEM : contiene
    ORDER_ITEM }o--o{ INGREDIENT : personaliza
    USER {
        uuid id PK
        string email UK
        string passwordHash
        string role
    }
```

## Diccionario de datos
| Entidad | Atributo | Tipo | Nulo | Restricciones | Descripción |
|---|---|---|---|---|---|

## Reglas de integridad
- …

## Cambios respecto a la fase anterior
- …
