# 08 — API programática

Cualquier cosa que la CLI de masonex hace, también puedes hacerla
desde Dart importando `package:masonex/masonex.dart`. Útil para:

- scripts de codegen propios sin pasar por la CLI;
- tests que verifican que un brick produce lo que debería;
- empotrar masonex en otra herramienta.

## Funcionalidades que muestra

- `Brick.path(...)`, `Brick.git(...)`, `Brick(name, location:
  BrickLocation(version: ...))` — las tres procedencias.
- `MasonexGenerator.fromBrick(brick)` — instancia el generador.
- `DirectoryGeneratorTarget(Directory(...))` — target en disco.
- `generator.generate(target, vars: {...})` — render real.
- `FileConflictResolution.overwrite` — política sin prompts (para
  scripts no interactivos).
- `GeneratorHooks` (`generator.hooks.preGen` / `postGen`) — los hooks
  son llamables desde Dart si el brick los trae.

## Cómo correrlo

```sh
cd apps/example/08_programmatic_api
dart pub get
dart run bin/render.dart /tmp/taskflow_prog
```

## Qué deberías ver

`/tmp/taskflow_prog/lib/audit_orders.dart` generado por el código de
`bin/render.dart` apuntando al brick local de `07_workspace/bricks/task`.
