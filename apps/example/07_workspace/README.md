# 07 — Workspace con `masonex.yaml`

`masonex.yaml` registra **qué bricks** están disponibles en un proyecto
y **dónde encontrarlos**: por path local, por git, o por versión
publicada en brickhub.dev. Un equipo lo commitea para que cualquiera
clone y haga `masonex get` y tenga listos los mismos bricks.

## Funcionalidades que muestra

- Las tres formas de ubicar un brick: `path`, `git`, y `version`.
- Comandos:
  - `masonex init` — crea un `masonex.yaml` vacío.
  - `masonex add <brick>` — registra un brick (local/git/version).
  - `masonex get` — descarga/cachea todos los bricks listados.
  - `masonex list` (alias `ls`) — los muestra en árbol.
  - `masonex remove <brick>` — desinstala uno.
  - `masonex make <brick>` — corre cualquiera de los registrados.
  - `--global` / `-g` — todas las anteriores aceptan un workspace
    global (`~/.masonex/masonex.yaml`).

## Estructura

- `masonex.yaml` — apunta a `bricks/task` (path local).
- `bricks/task/` — un brick mínimo embebido en este workspace.

## Cómo correrlo

```sh
cd apps/example/07_workspace

# Cachea los bricks declarados.
masonex get

# Listalos.
masonex list           # alias: masonex ls

# Genera con el brick `task`.
masonex make task --name AuditOrders -o /tmp/taskflow_ws

# Añade otro brick (por git) al workspace.
masonex add greeting --git-url https://github.com/felangel/mason \
  --git-path bricks/greeting

# Quita el que añadiste.
masonex remove greeting
```
