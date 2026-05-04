# mcp_masonex

Servidor **MCP (Model Context Protocol)** que expone la CLI de
[`masonex`](../masonex) como un conjunto de tools con schema explicito,
pensado para que agentes de IA puedan listar, buscar, generar y publicar
bricks de forma confiable y sin tener que armar comandos shell a mano.

- Habla MCP por **stdio** (compatible con Claude Desktop, Claude Code,
  cualquier cliente MCP estandar).
- Cada tool tiene **JSON schema** con `description`, `enum`, `required`
  y defaults razonables.
- Operaciones destructivas (`remove`, `unbundle`, `publish`,
  `ai-cache clear`, `logout`) requieren `confirm: true`; `publish`
  ademas defaultea a `dryRun: true`.
- El server **nunca escribe a STDOUT** salvo frames MCP. Logs van a
  STDERR.

## Instalacion

```sh
cd packages/mcp_masonex
dart pub get
dart run bin/mcp_masonex.dart --help
```

Como ejecutable global:

```sh
dart pub global activate --source path packages/mcp_masonex
mcp_masonex --workspace /ruta/a/tu/proyecto
```

Requiere que `masonex` este en el `PATH` (o pasar `--masonex-bin
/ruta/al/binario`).

## Conectarlo a un cliente

Ver [`example/README.md`](example/README.md) para snippets de
configuracion de Claude Desktop y Claude Code.

## Tools registradas

Todas las tools llevan prefijo `masonex_`. Las que ejecutan procesos
devuelven un texto resumen (command, exitCode, duration, stdout/stderr) y
un segundo bloque JSON con los mismos datos en formato estructurado.

### Meta

| Tool | Que hace |
|------|----------|
| `masonex_version` | `masonex --version`. Chequear que la CLI este disponible. |
| `masonex_help` | `masonex help [subcommand]` para inspeccionar flags. |

### Workspace y bricks

| Tool | Que hace |
|------|----------|
| `masonex_init` | Inicializa un `masonex.yaml` vacio. |
| `masonex_list_bricks` | Lista bricks (workspace o `--global`). |
| `masonex_search_bricks` | Busca en BrickHub. **Red.** |
| `masonex_add_brick` | Agrega un brick (`path` / `git*` / `version`). |
| `masonex_remove_brick` | Quita un brick. **Destructivo, requiere `confirm: true`**. |
| `masonex_get` | `masonex get` (resuelve y descarga deps). |
| `masonex_describe_brick` | Lee `brick.yaml` localmente y devuelve metadata + variables tipadas. |

### Generacion

| Tool | Que hace |
|------|----------|
| `masonex_make` | Genera codigo desde un brick. `vars` se pasa como JSON. Defaults: `quiet: true`, `onConflict: "skip"`. |
| `masonex_new_brick` | Scaffold de un brick nuevo (`masonex new`). |

### Empaquetado y publicacion

| Tool | Que hace |
|------|----------|
| `masonex_bundle` | Genera un bundle `universal` o `dart`. |
| `masonex_unbundle` | Expande un bundle. **Requiere `confirm: true`**. |
| `masonex_publish` | Publica a BrickHub. **`dryRun: true` por default**; subir requiere `dryRun: false` AND `confirm: true`. |

### In-file generation

| Tool | Que hace |
|------|----------|
| `masonex_build` | Corre `build_runner` para los annotations `@GenerateBefore` / `@GenerateAfter` / `@GenerationMerge`. |

### AI

| Tool | Que hace |
|------|----------|
| `masonex_audit_ai` | Lista todos los `\| ai` tags de un brick. Sin red. |
| `masonex_validate` | Valida sintaxis de pipelines AI (offline). |
| `masonex_ai_budget` | Estima tokens por tag y flagea los que pasan `budget`. |
| `masonex_ai_context_preview` | Imprime el envelope XML que iria al modelo. Sin red. |
| `masonex_ai_trace` | Lee `.masonex/cache/ai/trace.jsonl`. |
| `masonex_ai_cache` | `stats` o `clear` (este ultimo requiere `confirm: true`). |
| `masonex_provider_show` | Imprime la config de providers (sin secretos). |
| `masonex_provider_test` | Manda un prompt trivial al provider default. **Red, consume tokens.** |

### Auth

| Tool | Que hace |
|------|----------|
| `masonex_logout` | Logout de brickhub.dev. **Requiere `confirm: true`**. |

`masonex login` **no** se expone como tool (requiere prompts
interactivos para credenciales; el agente debe pedirle al usuario que
corra `masonex login` en su terminal).

## Convenciones de salida

Cada tool que ejecuta `masonex` devuelve dos `TextContent`:

1. Resumen humano (command, exitCode, duration, stdout, stderr).
2. JSON estructurado con los mismos campos para que el agente parsee
   programaticamente.

`isError` se setea en `true` cuando el `exitCode` es no-cero o el
proceso supero `timeoutSeconds`.

## Troubleshooting

- **"Failed to spawn masonex"** - el binario no esta en el PATH del
  proceso del MCP. Pasar `--masonex-bin /ruta/absoluta/al/masonex` al
  iniciar el server, o asegurar que el cliente MCP herede el PATH
  correcto.
- **Outputs largos / cortados** - subir `timeoutSeconds`.
- **El cliente MCP no ve las tools** - verificar que el comando del
  config arranque sin errores manualmente: `mcp_masonex --verbose 2>logs`
  y ver `logs`.
- **`masonex provider setup` requiere prompts** - no esta expuesto como
  tool por la misma razon que `login`. El usuario debe correrlo a mano.

## Diseño

El servidor agrupa las tools por intent (no es un mapeo 1:1 de la CLI):

- `masonex_describe_brick` lee `brick.yaml` en proceso (con paquete
  `yaml`) en lugar de forkear, asi le da al agente la metadata cruda y
  estructurada antes de invocar `make`.
- `masonex_make` siempre serializa `vars` a un JSON temporal y lo pasa
  via `-c`, asi nunca tenemos que shell-escapar valores complejos.
- Tools destructivas usan el patron `confirm: true` o `dryRun: true`
  como puerta explicita.
- `masonex_publish` ademas defaultea a `dryRun: true`: publicar es
  irreversible.
