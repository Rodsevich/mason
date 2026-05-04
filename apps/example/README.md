# Ejemplos de masonex — dominio `taskflow`

Esta carpeta es un recorrido guiado por las funcionalidades de
[`packages/masonex`](../../packages/masonex). Todos los ejemplos giran en
torno a **taskflow**, un mini sistema de gestión de tareas: cada brick
genera un trozo del proyecto (modelo `Task`, comandos CLI, plugins,
documentación), de forma que los ejemplos se leen como una progresión
natural.

> Los `README.md` están en español; el código y los comentarios siguen
> la convención del repo (inglés).

## Índice

| # | Carpeta | Funcionalidad demostrada |
|---|---------|--------------------------|
| 01 | [`01_basic_brick/`](01_basic_brick/) | Brick mínimo: `brick.yaml` + `__brick__/`. |
| 02 | [`02_variable_types/`](02_variable_types/) | Los seis `BrickVariableType`: `string`, `number`, `boolean`, `enum`, `array`, `list`. |
| 03 | [`03_file_prefixes/`](03_file_prefixes/) | Prefijos de filename: `>>>` `>` `>>` `<<` `!` `~` `?var?` `*var*`. |
| 04 | [`04_hooks/`](04_hooks/) | `pre_gen.dart` y `post_gen.dart` con `HookContext`. |
| 05 | [`05_in_file_generation/`](05_in_file_generation/) | Annotations `@GenerateBefore` / `@GenerateAfter` / `@GenerationMerge` + `masonex build`. |
| 06 | [`06_ai_filter/`](06_ai_filter/) | Filtro `\| ai(...)` en templates + mock fixtures (`brick_test/ai_fixtures.yaml`). |
| 07 | [`07_workspace/`](07_workspace/) | `masonex.yaml`: registrar bricks por path/git/version + comandos `init/add/get/list`. |
| 08 | [`08_programmatic_api/`](08_programmatic_api/) | Usar masonex desde Dart: `MasonexGenerator.fromBrick(...)` con `Brick.path` / `Brick.git`. |
| 09 | [`09_bundles/`](09_bundles/) | `masonex bundle` y `unbundle` (formato `universal` y `dart`). |
| 10 | [`10_cli_quickstart/`](10_cli_quickstart/) | Hoja de ruta de los comandos CLI más comunes. |
| 11 | [`11_provider_setup/`](11_provider_setup/) | `~/.masonex/providers.yaml`: registrar proveedores AI y comandos `provider`/`ai-*`/`audit-ai`/`validate`. |

## Cómo se relacionan

`taskflow` es un proyecto Dart imaginario:

- `01` y `02` generan archivos sueltos (un `Task` model, un `priority.dart`).
- `03` muestra cómo el mismo brick puede mergear, sobreescribir o iterar.
- `04` añade hooks para validar / loggear.
- `05` permite que **el código del proyecto** se anote y reciba snippets.
- `06` deja que la AI escriba dartdocs y eslogans para `taskflow`.
- `07` agrupa `task`, `plugin`, etc. en un workspace `masonex.yaml`.
- `08` muestra el mismo flujo desde un `bin/` Dart, sin CLI.
- `09` empaqueta `taskflow_task` para distribuirlo.
- `10` y `11` son referencia operativa.

## Cómo correrlos

Cada ejemplo trae su propio `README.md` con el comando exacto. Patrón
general (desde la raíz del repo):

```sh
# Asumiendo masonex instalado globalmente:
dart pub global activate masonex

# O usando el binario local:
dart run packages/masonex/bin/masonex.dart <comando>
```

Para ejecutar un brick local:

```sh
masonex make taskflow_task -c apps/example/01_basic_brick
```

## No cubierto explícitamente

- `masonex update` / `masonex upgrade`: son self-hosting (actualizan la
  herramienta o los bricks instalados); no aportan ejemplos de
  consumidor distinguibles.
- `masonex login` / `masonex logout`: requieren cuenta en
  `brickhub.dev`. Se mencionan en `10_cli_quickstart/` y en
  `06_ai_filter/`/`09_bundles/` solo como pre-requisito de `publish`.
- `masonex completion`: instalación de autocompletado, ortogonal al
  modelo de bricks.
- API interna (`AiCache`, `EnvelopeBuilder`, `PipelineParser`, etc.):
  son detalles de implementación expuestos solo a comandos `ai-*`. Los
  ejemplos los ejercitan a través de la CLI, no programáticamente.
