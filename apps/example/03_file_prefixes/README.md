# 03 — Prefijos de filename

Los nombres de archivo dentro de `__brick__/` pueden llevar un prefijo
que cambia cómo masonex procesa la salida. Este brick demuestra siete
prefijos en un solo `make`.

| Prefijo  | Archivo de este brick                           | Resultado                                                 |
|----------|-------------------------------------------------|-----------------------------------------------------------|
| `>>>`    | `>>>lib/tasks.dart`                             | Mergea (recursive Dart merge) con `lib/tasks.dart`.       |
| `>`      | `>README.md`                                    | Sobreescribe siempre.                                     |
| `>>`     | `>>CHANGELOG.md`                                | Append al final del archivo existente.                    |
| `<<`     | `<<HEADER.md`                                   | Prepend al inicio.                                        |
| `!`      | `!.gitignore`                                   | Solo se crea si NO existe (safe).                         |
| `~`      | `~build_marker.txt`                             | Se genera y luego masonex lo elimina (temporary).         |
| `?var?`  | `?withReminders?lib/reminders.dart`             | Solo si `withReminders` es true.                          |
| `*var*`  | `*plugins*lib/plugins/{{item.snakeCase()}}.dart`| Itera la lista `plugins` generando un archivo por item.   |

> El prefijo `%id%` (snippets de in-file generation) se ejemplifica en
> [`05_in_file_generation/`](../05_in_file_generation/).

## Cómo correrlo

Genera dos veces sobre el mismo `-o` para ver merge/append/prepend:

```sh
# 1ª pasada: crea el árbol.
masonex make . -o /tmp/taskflow_pkg \
  --withReminders true \
  --plugins '["github","slack","jira"]'

# 2ª pasada: ahora >>> < << >> hacen su trabajo.
masonex make . -o /tmp/taskflow_pkg \
  --withReminders false \
  --plugins '["webhook"]'
```

## Qué deberías ver

- `lib/tasks.dart` con la lista `plugins` mergeada (sin duplicados).
- `README.md` reescrito completo (overwrite).
- `CHANGELOG.md` con dos bloques apilados (append).
- `HEADER.md` con la cabecera más nueva al principio (prepend).
- `.gitignore` creado solo la primera vez (safe).
- `build_marker.txt` no aparece (temporary).
- `lib/reminders.dart` solo en la 1ª pasada (`?withReminders?`).
- `lib/plugins/github.dart`, `slack.dart`, `jira.dart`, `webhook.dart`
  (uno por iteración de `plugins`).
