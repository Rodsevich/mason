# 04 — Hooks (`pre_gen.dart`, `post_gen.dart`)

masonex ejecuta dos hooks Dart si existen, antes y después de la
generación. Reciben un `HookContext` que da acceso al `logger` y a las
`vars` (mutables — puedes cambiarlas en `pre_gen` y la generación verá
los nuevos valores).

## Funcionalidades que muestra

- `pre_gen.dart`: derivar/normalizar variables (aquí pasamos
  `name` a `snake_case` y rellenamos `slug` y `createdAt`).
- `post_gen.dart`: ejecutar acciones de cierre (aquí registramos la
  tarea generada en `.taskflow_log`).
- `hooks/pubspec.yaml`: declarar la dependencia a `masonex` (los hooks
  son un mini-paquete Dart aparte).

## Cómo correrlo

```sh
masonex make . -o /tmp/taskflow_hooks --name "Send weekly report"
```

## Qué deberías ver

- En consola, dos líneas del logger: `[pre_gen] normalized name → ...`
  y `[post_gen] task <slug> registered`.
- En `/tmp/taskflow_hooks/lib/<slug>.dart`, una clase con
  `createdAt` rellenado por el hook.
- Un archivo `/tmp/taskflow_hooks/.taskflow_log` con el slug.

> Pasa `--no-hooks` a `masonex make` para saltarse ambos.
