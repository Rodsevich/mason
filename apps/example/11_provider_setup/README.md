# 11 — Configurar proveedores de IA

masonex no se acopla a ningún SDK propietario: invoca un **proceso
externo** (cualquier CLI que sepa hablar con el modelo). La
configuración vive en `~/.masonex/providers.yaml` y la maneja el grupo
de comandos `masonex provider`.

## Funcionalidades que muestra

- Estructura completa de `providers.yaml` con varios providers.
- Las tres formas de pasar la prompt (`pass_prompt`):
  - `stdin` — masonex escribe la prompt en stdin del proceso.
  - `tmpfile` — escribe la prompt en un fichero y le pasa la ruta.
  - `arg` — pasa la prompt como último argumento del comando.
- `pass_system: null` — masonex prepende el system prompt al user
  prompt (útil cuando la CLI no tiene flag específico para system).
- `default:` — cuál de los providers se usa cuando `masonex make` no
  trae `--ai-provider`.

## Comandos del grupo

```sh
masonex provider setup     # wizard interactivo (genera el archivo)
masonex provider show      # imprime la config (sin secretos)
masonex provider edit      # abre $EDITOR sobre el archivo
masonex provider test      # ping mínimo al provider default
masonex provider reset     # borra el archivo (con confirmación)
```

## El archivo (ejemplo)

Mira [`providers.example.yaml`](providers.example.yaml). Cópialo a
`~/.masonex/providers.yaml`, ajusta los `cmd:` a binarios reales que
tengas instalados, y prueba con `masonex provider test`.

## Cómo se conecta con un brick

Cuando un template contiene `{{ "..." | ai(...) }}` y corres
`masonex make <brick>`:

1. masonex resuelve la prompt (Mustache se evalúa primero).
2. Lee `~/.masonex/providers.yaml`, elige `default` (o
   `--ai-provider <id>`).
3. Lanza el proceso `cmd` con la prompt según `pass_prompt`.
4. Captura stdout, valida `expect:` / `case:` / `max_chars`, y mete el
   resultado de vuelta en el render.
5. Cachea en `.masonex/cache/ai/` y registra en `trace.jsonl`.

Para auditar todo esto sin gastar llamadas reales:

```sh
masonex audit-ai --brick path/al/brick
masonex ai-context-preview --brick path/al/brick
masonex validate --brick path/al/brick
masonex ai-budget --brick path/al/brick --budget 4000
masonex ai-trace --last 20
masonex ai-cache stats
masonex ai-cache clear
```
