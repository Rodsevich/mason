# 06 — Filtro `| ai(...)`

masonex puede resolver fragmentos de un brick contra un proveedor de
IA durante el render. La sintaxis es un pipe Mustache extendido.

## Funcionalidades que muestra

- Llamada literal a `| ai(...)` con `expect: line` y `max_chars`.
- Substitución Mustache **antes** de invocar la IA (la prompt se
  arma con `{{taskName}}`/`{{audience}}` ya resueltos).
- `expect: identifier` con `case: kebab` (post-filtro).
- Llamadas anidadas: el contenido devuelto por una `| ai` puede
  alimentar el `prompt` de otra (ver `tagline`).
- `brick_test/ai_fixtures.yaml`: respuestas mock que masonex usa con
  `--use-mock-ai` para que la suite de tests del brick sea
  reproducible y no dependa de la red.

## Cómo correrlo

### Sin red (mock fixtures)

```sh
masonex make . -o /tmp/taskflow_ai \
  --use-mock-ai \
  --taskName ShipOrder \
  --audience customer
```

### Contra un proveedor real

```sh
# 1. Configura ~/.masonex/providers.yaml (ver 11_provider_setup/).
masonex provider setup
# 2. Render normal — masonex usa el provider default.
masonex make . -o /tmp/taskflow_ai \
  --taskName ShipOrder --audience customer
# 3. Inspecciona caché y trace:
masonex ai-trace --last 10
masonex ai-cache stats
```

### Comandos relacionados (sin invocar al modelo)

```sh
masonex audit-ai --brick .             # lista todos los `| ai` y sus parámetros
masonex validate --brick .             # checa errores de sintaxis del pipe
masonex ai-context-preview --brick .   # imprime el envelope XML que se enviaría
masonex ai-budget --brick . --budget 4000   # estima tokens por tag
```

## Qué deberías ver

`/tmp/taskflow_ai/lib/ship_order.dart` con dartdocs y eslogan
generados — fijos en modo mock, variables con un proveedor real.
