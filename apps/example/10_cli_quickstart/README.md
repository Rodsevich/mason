# 10 — CLI quickstart

Hoja de ruta de los comandos de `masonex` agrupados por intención.
Cada comando enlaza al ejemplo más detallado.

## Crear y operar bricks

| Comando                 | Para qué                                                  | Ejemplo                                |
|-------------------------|-----------------------------------------------------------|----------------------------------------|
| `masonex new <name>`    | Scaffolding de un brick nuevo (con `--hooks` opcional).   | `masonex new taskflow_task --hooks`    |
| `masonex make <brick>`  | Genera código a partir de un brick instalado.             | ver [`07_workspace`](../07_workspace/) |
| `masonex make . -o ...` | Render de un brick local sin pasar por `masonex.yaml`.    | ver [`01_basic_brick`](../01_basic_brick/) |

## Workspace (`masonex.yaml`)

| Comando                          | Para qué                                                  |
|----------------------------------|-----------------------------------------------------------|
| `masonex init`                   | Crea `masonex.yaml` vacío en el cwd.                      |
| `masonex add <name> [version]`   | Añade un brick (path/git/hosted).                         |
| `masonex remove <name>`          | Lo quita.                                                 |
| `masonex get`                    | Resuelve y cachea todos los listados.                     |
| `masonex list` / `masonex ls`    | Árbol de los bricks instalados.                           |
| `masonex upgrade [-g]`           | Actualiza bricks a las últimas versiones permitidas.      |
| `masonex cache clear`            | Borra todo el cache local.                                |

Detalle: ver [`07_workspace`](../07_workspace/).

## Distribución

| Comando                    | Para qué                                              |
|----------------------------|-------------------------------------------------------|
| `masonex bundle <src>`     | Empaqueta a `.bundle` o `_bundle.dart`.               |
| `masonex unbundle <file>`  | Restaura el árbol desde un bundle.                    |
| `masonex login`            | Autentica contra brickhub.dev (necesario para publish).|
| `masonex publish`          | Publica el brick del cwd a la registry configurada.   |
| `masonex search <query>`   | Busca bricks publicados.                              |
| `masonex logout`           | Cierra sesión.                                        |

Detalle: ver [`09_bundles`](../09_bundles/).

## Build / in-file generation

| Comando                          | Para qué                                                  |
|----------------------------------|-----------------------------------------------------------|
| `masonex build`                  | Atajo de `dart pub run build_runner build`.               |

Detalle: ver [`05_in_file_generation`](../05_in_file_generation/).

## AI

| Comando                          | Para qué                                                  |
|----------------------------------|-----------------------------------------------------------|
| `masonex provider <sub>`         | `setup` / `show` / `edit` / `test` / `reset`.             |
| `masonex audit-ai --brick .`     | Lista todos los `\| ai` y sus parámetros.                  |
| `masonex validate --brick .`     | Checa la sintaxis del pipe sin invocar nada.              |
| `masonex ai-context-preview`     | Imprime el envelope XML que enviaría.                     |
| `masonex ai-budget --budget N`   | Estima tokens por tag.                                    |
| `masonex ai-trace [--last N]`    | Lee `.masonex/cache/ai/trace.jsonl`.                      |
| `masonex ai-cache stats\|clear`  | Tamaño / borrado del cache de IA.                         |

Detalles: [`06_ai_filter`](../06_ai_filter/) y [`11_provider_setup`](../11_provider_setup/).

## Misceláneo

| Comando                | Para qué                                              |
|------------------------|-------------------------------------------------------|
| `masonex --version`    | Versión instalada de masonex.                         |
| `masonex update`       | Actualiza la herramienta vía `pub`.                   |
| `masonex completion`   | Instala autocompletado en tu shell.                   |

## Flags transversales útiles en `masonex make`

```sh
--config-path config.json          # vars desde JSON
--on-conflict overwrite|skip|append|prompt
--no-hooks                         # salta pre/post_gen
--watch                            # regenera al cambiar __brick__/
--set-exit-if-changed              # exit 70 si hubo cambios (CI)
--no-ai                            # ignora todo `| ai(...)` en el render
--use-mock-ai                      # usa brick_test/ai_fixtures.yaml
--ai-provider <id>                 # override del provider default
--ai-token-budget 4000             # corta antes de invocar al modelo
--dry-run-ai                       # ejecuta IA sin escribir archivos
```
