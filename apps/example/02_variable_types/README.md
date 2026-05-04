# 02 — Tipos de variables

Un solo brick que ejercita los seis tipos soportados por `BrickYaml`:

| Tipo      | Variable        | Para qué sirve aquí                              |
|-----------|-----------------|--------------------------------------------------|
| `string`  | `projectName`   | Nombre PascalCase del proyecto.                  |
| `number`  | `defaultDueDays`| Días por defecto al crear una tarea.             |
| `boolean` | `withReminders` | Si el modelo lleva un campo `remindAt`.          |
| `enum`    | `storage`       | Backend de persistencia (uno solo).              |
| `array`   | `flavors`       | Sub-set fijo de flavors a generar.               |
| `list`    | `tags`          | Lista libre de etiquetas (separadas por coma).   |

## Cómo correrlo

```sh
masonex make . -o /tmp/taskflow_settings \
  --projectName Taskflow \
  --defaultDueDays 7 \
  --withReminders true \
  --storage sqlite \
  --flavors '["dev","prod"]' \
  --tags 'home,work,urgent'
```

O en modo interactivo (sin `--*`): masonex te preguntará cada variable
respetando los `prompt` y `default(s)` declarados.

## Qué deberías ver

`/tmp/taskflow_settings/lib/taskflow_config.dart` con un `const`
record que combina todas las variables, y `lib/flavors_<flavor>.dart`
generado por flavor (vía la sección `{{#flavors}}...{{/flavors}}`).
