# 01 — Brick mínimo

Un brick es un par `brick.yaml` + carpeta `__brick__/`. Aquí generamos
una sola clase Dart `Task` a partir del nombre que pase el usuario.

## Funcionalidades que muestra

- Estructura mínima de un brick masonex.
- Una sola variable de tipo `string` con `default` y `prompt`.
- Sintaxis Mustache extendida (`{{name.snakeCase()}}` en path,
  `{{name.pascalCase()}}` en contenido).

## Cómo correrlo

```sh
# Desde apps/example/01_basic_brick/
masonex make . -o /tmp/taskflow_out --name shipOrder
```

## Qué deberías ver

```
/tmp/taskflow_out/lib/ship_order.dart
```

con una clase `class ShipOrder { ... }` lista para usar.
