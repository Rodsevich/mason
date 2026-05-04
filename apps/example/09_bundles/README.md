# 09 — Bundles (`masonex bundle` / `unbundle`)

Un bundle es un **brick empaquetado en un solo archivo**. Sirve para
distribuirlo embebido (binario `.bundle` o `.dart`) sin depender de
git/hosted al runtime.

## Funcionalidades que muestra

- `masonex bundle` con los dos formatos:
  - `--type universal` — `.bundle` (bytes), portable a cualquier
    runtime que entienda masonex.
  - `--type dart` — `<name>_bundle.dart`, una `MasonexBundle`
    constante embebible directamente en una app Dart.
- `masonex unbundle` — el inverso: regenera la carpeta del brick.
- Las tres fuentes (`--source path|git|hosted`) y `set-exit-if-changed`
  para CI.

## Cómo correrlo

```sh
cd apps/example/09_bundles
mkdir -p out

# 1. Empaquetar el brick local de 01_basic_brick en .bundle
masonex bundle ../01_basic_brick \
  --source path \
  --type universal \
  --output-dir out

# 2. ...y como Dart embebible
masonex bundle ../01_basic_brick \
  --source path \
  --type dart \
  --output-dir out

# 3. Inverso: del .bundle vuelve al árbol del brick
masonex unbundle out/taskflow_task.bundle --output-dir out/restored

# 4. Bonus: bundle directo desde git
# masonex bundle https://github.com/felangel/mason \
#   --source git --git-path bricks/widget \
#   --type universal --output-dir out
```

## Qué deberías ver

```
out/
  taskflow_task.bundle           # universal
  taskflow_task_bundle.dart      # dart embebible
  restored/taskflow_task/        # brick reconstituido
```
