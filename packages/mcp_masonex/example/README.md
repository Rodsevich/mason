# Conectar `mcp_masonex` a un agente

Este servidor habla MCP por **stdio**. Funciona con cualquier cliente MCP
estándar (Claude Desktop, Claude Code, etc.).

## 1. Asegurate de tener `masonex` en el PATH

```sh
dart pub global activate masonex
masonex --version
```

Si lo preferis, podes apuntar el server a un binario alternativo con
`--masonex-bin`.

## 2. Ejecuta `mcp_masonex` localmente

Desde la raiz del repo:

```sh
cd packages/mcp_masonex
dart pub get
dart run bin/mcp_masonex.dart --workspace /ruta/a/tu/proyecto --verbose
```

`--verbose` solo imprime a STDERR; STDOUT esta reservado al protocolo MCP.

Para distribuirlo como ejecutable global:

```sh
dart pub global activate --source path packages/mcp_masonex
which mcp_masonex
```

## 3. Claude Desktop

Editar `~/Library/Application Support/Claude/claude_desktop_config.json`
(macOS) o el equivalente en Windows / Linux y agregar:

```json
{
  "mcpServers": {
    "masonex": {
      "command": "mcp_masonex",
      "args": ["--workspace", "/ruta/a/tu/proyecto"]
    }
  }
}
```

Reiniciar Claude Desktop. En la barra de herramientas aparecera el
servidor `masonex` con sus tools.

Si no usaste `dart pub global activate`, mira
`example/claude_desktop_config.json` para el formato `dart run`.

## 4. Claude Code

```sh
claude mcp add masonex -- mcp_masonex --workspace /ruta/a/tu/proyecto
```

(o `dart run /ruta/al/repo/packages/mcp_masonex/bin/mcp_masonex.dart` si
no tenes el binario activado).

## 5. Prompt de ejemplo

> Quiero scaffolding de un nuevo modelo `Task` en mi proyecto. Usa
> `masonex_describe_brick` para revisar las variables del brick
> `apps/example/01_basic_brick`, despues llama a `masonex_make` con
> `name: "ProjectAlpha"` y `dryRunAi: true` para previsualizar la salida.

El agente deberia, en orden:

1. `masonex_version` - chequear que masonex este disponible.
2. `masonex_describe_brick` - leer `brick.yaml`.
3. `masonex_make` con `dryRunAi: true` - previsualizar.
4. Pedir confirmacion al usuario.
5. `masonex_make` real cuando el usuario lo apruebe.
