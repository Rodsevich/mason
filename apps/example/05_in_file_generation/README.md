# 05 — In-file generation (annotations + `masonex build`)

masonex puede inyectar fragmentos de un brick dentro de archivos Dart
ya existentes, en puntos marcados con annotations.

## Funcionalidades que muestra

- Las tres annotations que expone `package:masonex`:
  - `@GenerateBefore('id')`
  - `@GenerateAfter('id')`
  - `@GenerationMerge('id')`
- El builder de `build_runner`
  (`inFileGenerationBuilder` en `package:masonex/builders.dart`)
  que escanea el código y produce `inFileGenerations.json`.
- El prefijo de filename `%id%` que une el snippet del brick con el
  punto anotado.

## Estructura

- `lib/task_registry.dart` — código de **producción** anotado.
- `taskflow_plugin/` — un brick con un fragmento `%plugin_register%`.
- `build.yaml` — habilita explícitamente `inFileGenerationBuilder`.
- `pubspec.yaml` — depende de `masonex` y `build_runner`.

## Cómo correrlo

```sh
# Desde apps/example/05_in_file_generation/
dart pub get
masonex build              # alias de: dart pub run build_runner build
```

Tras `masonex build` aparece `lib/inFileGenerations.json` con el mapa
`{ archivo → { id → snippet } }`. Cuando alguien haga
`masonex make taskflow_plugin -o ...`, los archivos `%plugin_register%`
se inyectarán justo donde el `@GenerateAfter('plugin_register')` lo
indique.

## Qué deberías ver

`lib/inFileGenerations.json` con una entrada por cada annotation
encontrada en `lib/task_registry.dart`.
