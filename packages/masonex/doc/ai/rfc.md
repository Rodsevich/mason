# RFC: AI-assisted templating en masonex (`| ai` filter)

| Campo            | Valor                                          |
|------------------|------------------------------------------------|
| Estado           | Draft (a aprobar antes de F1)                  |
| Versión RFC      | 0.1.0                                          |
| Autor            | Nico Rodsevich                                 |
| Paquetes tocados | `mustachex`, `masonex`                         |
| Brick referencia | `bricks/ai_codegen_example/`                   |
| Última edición   | 2026-05-02                                     |

> Este RFC es la fuente única de verdad del diseño. Cualquier desviación durante la
> implementación se refleja editando este archivo en el mismo PR que la introduce.

---

## 1. Motivación

masonex hoy genera archivos a partir de plantillas Mustache 100% deterministas: las
variables las provee el usuario (o `brick.yaml`) y la salida es una función pura de
esas variables. Para cierta clase de plantillas eso no alcanza: hay valores que el
autor del brick no puede prever (un docstring que describa la clase generada, una
respuesta a "lista los 5 colores complementarios de X", la traducción de un string,
una sugerencia de nombre semántico, etc.).

Queremos darle al autor del brick una forma de delegar la generación de **el contenido
de un tag** a una IA configurada por el usuario, sin perder ninguna garantía de mason
sobre **dónde se generan los archivos**.

## 2. Goals / Non-goals

### Goals

- Permitir tags Mustache que indiquen "el valor de este tag lo genera una IA" con
  prompt embebido y parámetros de control.
- Mantener determinismo de paths/estructura: la IA solo controla bytes dentro de
  archivos, nunca rutas ni nombres de archivos.
- Que el sistema sea agnóstico al CLI de IA: claude, gemini, codex, cursor-agent,
  aider, ollama, custom — cualquiera configurable.
- Que la corrida sea **atómica**: si la IA falla irremediablemente, el proyecto
  destino no se modifica.
- Que las corridas con cache caliente sean **funcionalmente deterministas**
  (mismo input → mismo output).
- Que el feature sea testeable sin red mediante un mock provider.
- Que la documentación sea ciudadana de primera y se entregue junto con el código.

### Non-goals (v1)

- Que la IA pueda generar archivos extra o decidir paths.
- Que masonex hable con APIs HTTP de proveedores. Solo CLIs.
- Coherencia inter-tag automática (`consider`/`consistent_with`/`examples`)
  → planeado para v2.
- Estimación de costos por modelo con tokenizer real → v2.
- Soporte para que el filtro genere streams o multimedia → fuera de alcance.

## 3. Glosario

| Término            | Definición                                                              |
|--------------------|-------------------------------------------------------------------------|
| Brick              | Carpeta con `brick.yaml` y `__brick__/` con plantillas Mustache.         |
| Tag                | Cualquier expresión `{{ ... }}` dentro de una plantilla.                 |
| Filtro             | Transformador aplicable en pipeline a un valor (`uppercase`, `ai`, …).   |
| Pipeline           | Cadena de filtros aplicados a un head (literal o variable).              |
| Head               | Primer token del pipeline: literal con/sin comillas, o referencia a var. |
| Provider           | Adapter sobre un CLI de IA configurado por el usuario.                   |
| Envelope           | Mensaje XML estructurado que masonex envía como user prompt al provider. |
| System prompt      | Texto fijo versionado en masonex que educa al modelo sobre la operación. |
| Tag id             | Identificador estable de un tag (default: hash del prompt + path:line).  |
| Pasada 1           | Pre-resolución: masonex resuelve todos los `| ai` en memoria.            |
| Pasada 2           | Render Mustache normal con valores ya resueltos.                         |
| Cache              | Almacén content-addressed de outputs previos en `.masonex/cache/ai/`.    |
| Trace              | Log append-only de invocaciones a IA en `cache/ai/trace.jsonl`.          |

## 4. Decisiones confirmadas (anclas del diseño)

1. Sintaxis literal vs var: comillas o espacios → literal; sin → buscar var; si no
   existe, fallback a literal.
2. Notaciones equivalentes: `var.ai(args).x()` ≡ `var | ai(args) | x` ≡
   `"lit" | ai(args) | x`. Mezcla permitida.
3. Sin fallback automático entre providers. Hay un solo provider activo configurado
   en `~/.masonex/providers.yaml`. Cambio = decisión humana.
4. Sin pending files. Si todo falla → abort total, ningún archivo del proyecto modificado.
5. Atomicidad por **pasada de pre-resolución** antes del render normal.
6. Cache default **on**, content-addressed, en `.masonex/cache/ai/`. `trace.jsonl`
   vive adentro.
7. System prompt en **inglés**, versionado en el código de masonex.
8. Concurrencia default **4** simultáneas.
9. Validación con feedback al retry (se le pega el error de validación previo al
   modelo en el siguiente intento).
10. Envelope híbrido: filenames del brick completo + contenido solo del `current_file`,
    con `include` para subir detalle.
11. `consider` / `consistent_with` / `examples` postergados a v2.

## 5. Sintaxis del filtro

### 5.1. Resolución del head

Dado un tag `{{ HEAD | f1 | f2 ... }}` o `{{ HEAD.f1().f2() }}`, el `HEAD` se resuelve
así:

| Forma del HEAD                | Tratamiento                                          |
|-------------------------------|------------------------------------------------------|
| `"texto"` o `'texto'`         | Literal (texto entre comillas, sin las comillas).     |
| `texto con espacios`          | Literal (warning sugiriendo usar comillas).          |
| `identificador`                | Lookup en contexto. Si existe → su valor. Si no → literal `identificador` con warning. |

Las comillas pueden escaparse con `\"` y `\'`. Newlines literales dentro de
strings con comillas son válidos.

### 5.2. Pre-render Mustache del head literal

Antes de ser usado como prompt, un head literal se renderiza con Mustache contra
el contexto actual. Eso permite:

```
{{ "doc para {{className}}" | ai(expect: line) }}
```

El prompt que llega al envelope ya es `doc para FooRepository`, no el literal con
`{{className}}` adentro.

### 5.3. Equivalencia entre notaciones

Las dos formas se compilan al mismo `FilterPipelineNode`:

```
{{ "campeón mundial" | ai(expect: word) | uppercase }}
{{ "campeón mundial".ai(expect: word).uppercase() }}
```

Mezcla permitida:

```
{{ varName.ai(expect: word) | uppercase }}
{{ varName | ai(expect: word).uppercase() }}
```

### 5.4. Argumentos del filtro

Argumentos posicionales y nombrados, separados por coma. Tipos soportados:

| Tipo          | Sintaxis                       | Ejemplo                          |
|---------------|--------------------------------|----------------------------------|
| `string`      | comillas dobles o simples      | `"json"`, `'es'`                 |
| `int`         | dígitos                        | `2`, `1024`                      |
| `bool`        | `true` / `false`               | `true`                           |
| `duration`    | `<n><unit>` con unit `s|m|h`   | `30s`, `2m`                      |
| `identifier`  | sin comillas, sin espacios     | `word`, `pascal`                 |
| `list`        | `[ a, b, c ]`                  | `[a, b, c]`, `["a", "b"]`        |
| `range`       | `n..m` o `>=n` / `<=n`         | `1..3`, `>=2`                    |
| `regex`       | `/.../[flags]`                 | `/^[A-Z]+$/`                     |

### 5.5. Restricciones

- `| ai` está **prohibido** en cualquier path/nombre de archivo del brick. masonex
  debe fallar en `validate` y al inicio del render si lo detecta.
- `| ai` puede aparecer cualquier número de veces en cuerpos de archivos.
- El resto de filtros (`uppercase`, `snakeCase`, etc.) puede aparecer en paths como
  hoy. Solo `ai` está restringido.

## 6. Catálogo de parámetros

Categorías y default. Parámetros marcados v2 quedan fuera de F1.

### 6.1. Forma de salida

| Param        | Tipo / valores                                                                                                  | Default | Efecto en envelope (`<expected_shape>`)                                       | Post-proceso                                         |
|--------------|------------------------------------------------------------------------------------------------------------------|---------|--------------------------------------------------------------------------------|------------------------------------------------------|
| `expect`     | `word`, `line`, `sentence`, `paragraph`, `json`, `yaml`, `code:<lang>`, `identifier`, `number`, `boolean`, `enum`, `raw` | `raw`   | Inyecta regla específica para cada caso                                        | Validador (regex/parser) + retry                     |
| `lines`      | int o range                                                                                                      | —       | "exactamente N líneas" / "entre N y M líneas"                                  | Cuenta líneas, retry si no                            |
| `max_chars`  | int                                                                                                              | —       | "máximo X caracteres"                                                          | Trim si excede ligeramente, retry si excede mucho     |
| `min_chars`  | int                                                                                                              | —       | "mínimo X caracteres"                                                          | Retry                                                |
| `case`       | `camel`, `pascal`, `snake`, `kebab`, `const`, `dot`                                                              | —       | Solo válido con `expect: identifier`. Inyecta "responder en camelCase"           | Re-case forzado del output (no se retrymeya por casing) |
| `language`   | código ISO (`es`, `en`, `pt`)                                                                                   | —       | "respondé en español"                                                          | —                                                    |

### 6.2. Validación

| Param      | Tipo            | Efecto                                                                          |
|------------|-----------------|---------------------------------------------------------------------------------|
| `match`    | regex           | "la respuesta debe matchear `<regex>`" + valida + retry con feedback             |
| `oneOf`    | list            | "tu respuesta debe ser exactamente una de: …" + valida + retry                   |
| `forbid`   | regex o list    | "NO incluyas: …" + valida + retry                                                |
| `schema`   | string (path o inline JSON Schema) | Solo con `expect: json`. Inyecta schema. Valida output con `json_schema`. |
| `retries`  | int             | Reintentos antes de abortar. Default `2`.                                        |

### 6.3. Estilo

| Param      | Tipo   | Efecto                                                                  |
|------------|--------|-------------------------------------------------------------------------|
| `style`    | string | Inyecta "estilo: <texto>" en `<task>`                                    |
| `tone`     | string | Inyecta "tono: <texto>"                                                  |
| `persona`  | string | Prepend "actuá como <texto>" al prompt                                   |

### 6.4. Provider y modelo

| Param         | Tipo            | Efecto                                                                  |
|---------------|-----------------|-------------------------------------------------------------------------|
| `provider`    | string          | Override del provider para este tag (debe existir en config del usuario) |
| `model`       | string          | Override del modelo dentro del provider, si el CLI lo soporta            |
| `temperature` | float `0..1`    | Pasado al CLI si soporta. Default `0`.                                   |
| `seed`        | int             | Pasado al CLI si soporta; usado por mock provider para reproducibilidad. |

### 6.5. Contexto

| Param           | Tipo     | Efecto                                                                     |
|-----------------|----------|----------------------------------------------------------------------------|
| `include`       | globs    | Suma archivos del proyecto consumidor al envelope (`<extra_files>`)         |
| `exclude`       | globs    | Quita archivos del envelope                                                 |
| `extra_context` | string   | Texto inyectado tal cual en `<extra_context>`                               |
| `description`   | string   | Nota del autor del brick para el modelo, va en `<author_note>`              |

### 6.6. Identidad y cache

| Param        | Tipo                              | Default                                |
|--------------|-----------------------------------|----------------------------------------|
| `id`         | string                            | hash de `(prompt + file_path + line)`. |
| `cache`      | `auto` / `always` / `never`       | `auto`.                                |
| `cache_key`  | string                            | Override manual.                        |

### 6.7. Mecánica

| Param          | Tipo      | Default | Efecto                                                  |
|----------------|-----------|---------|---------------------------------------------------------|
| `trim`         | bool      | `true`  | Strip whitespace de los extremos                         |
| `strip_fences` | bool      | `true`  | Quita ```` ```lang ```` del output                      |
| `inline`       | bool/auto | `auto`  | Override de la detección "inline vs block"               |
| `timeout`      | duration  | `60s`   | Timeout de la invocación al CLI                          |

### 6.8. v2 (no implementar en F1-F7)

| Param              | Tipo               | Razón v2                                       |
|--------------------|--------------------|------------------------------------------------|
| `consider`         | list de tag ids    | Coherencia inter-tag                            |
| `consistent_with`  | list de tag ids    | Coherencia inter-tag con regla dura             |
| `examples`         | list `[{in, out}]` | Few-shot                                        |

## 7. System prompt

Vive en `packages/masonex/lib/src/ai/system_prompt.md` y se versiona junto con el
código. Su hash se incluye en la cache key, así un cambio de redacción invalida
los outputs cacheados.

```
You are an AI invoked by masonex during the rendering of a mason brick.

TOOL CONTEXT
- mason is a Dart template generator. A "brick" is a folder with a `brick.yaml`
  manifest and a `__brick__/` directory containing Mustache templates.
- masonex is an extension of mason that, among other things, adds the Mustache
  filter `| ai`. When a tag in a template uses this filter, masonex calls you
  to generate the value that replaces the tag.

WHAT YOU RECEIVE
A single XML message named <masonex_render_request> containing:
  - <meta>: brick info, user variables, provider/model selected
  - <brick_contents>: structure (file list) of __brick__, plus contents of relevant files
  - <current_file>: target file where your output is inserted
  - <surrounding_text>: lines around the tag to give local context
  - <tag>: the literal tag as it appears in the template
  - <previous_ai_resolutions>: outputs you produced earlier in this run (when present)
  - <task>: the prompt and the output contract
  - <extra_files>, <extra_context>: optional extra context provided by the brick author

WHAT YOU RETURN
Only the text that replaces the tag. Nothing else:
  - no fences (``` ... ```)
  - no explanation, no "Here you go:", no preamble or epilogue
  - no extra newlines
  - if the contract says "single line", return a single line
  - if the contract says JSON, return raw valid JSON
  - if you cannot comply, the first line MUST be exactly: MASONEX_ERROR: <reason>

HARD RULES
  - Do not explain your reasoning.
  - Do not ask for clarification; resolve with your best interpretation.
  - Do not call tools (even if available); reply with text only.
  - Do not include the original tag or its delimiters in your reply.
```

## 8. Envelope (user prompt)

XML compacto enviado como user prompt. Toda la información va dentro de
`<masonex_render_request>`.

```xml
<masonex_render_request version="1">
  <meta>
    <brick name="ai_codegen_example" version="0.1.0" description="..."/>
    <provider name="claude" model="claude-opus-4-7"/>
    <user_vars>
      <var name="className">FooRepository</var>
    </user_vars>
  </meta>

  <brick_contents>
    <files>
      <!-- siempre: lista entera de paths del brick -->
      <file path="__brick__/lib/foo.dart" included="true"/>
      <file path="__brick__/test/foo_test.dart" included="false"/>
    </files>
    <!-- contenido del current_file y de los include extra -->
    <file path="__brick__/lib/foo.dart"><![CDATA[ ... ]]></file>
  </brick_contents>

  <current_file path="lib/foo.dart" language="dart"/>

  <surrounding_text>
    <before><![CDATA[líneas anteriores]]></before>
    <after><![CDATA[líneas posteriores]]></after>
  </surrounding_text>

  <tag inline="true" original="{{ &quot;dime ...&quot; | ai(expect: word) | uppercase }}"/>

  <previous_ai_resolutions/>

  <extra_files/>
  <extra_context/>

  <task>
    <prompt><![CDATA[dime en una sola palabra que pais fue el ultimo ganador del mundial de futbol FIFA]]></prompt>
    <expected_shape>single word, no whitespace, no punctuation, no markdown</expected_shape>
    <constraints>
      <retries>2</retries>
      <max_chars>50</max_chars>
      <match>^[A-Za-zÀ-ÿ]+$</match>
    </constraints>
    <post_filters>uppercase</post_filters>
    <author_note/>
  </task>
</masonex_render_request>
```

Reglas de construcción:

- `inline="true"` cuando el tag no ocupa una línea entera. Disparador para que el
  `<expected_shape>` sume "single line, no newlines".
- `post_filters` se incluye **a título informativo**. La aplicación real es
  responsabilidad de masonex, no del modelo.
- `<brick_contents>/<files>` lista todos los paths con `included="true|false"`
  según si están incorporados con contenido.
- `<previous_ai_resolutions>` queda vacío en v1; el placeholder está para no
  romper compat al introducirlo en v2.

## 9. Provider — adapter, persistencia y flujo

### 9.1. Interfaz

```dart
abstract class AiProviderAdapter {
  AiProviderDescriptor get descriptor; // id, displayName, requiredCommand, helpUrl
  Future<bool> isAvailable();          // which + sanity check
  Future<AiInvocationResult> invoke(
    AiInvocation request, {
    required Duration timeout,
  });
}

class AiInvocation {
  final String systemPrompt;
  final String userEnvelope;        // XML serializado
  final String? modelOverride;
  final double? temperature;
  final int? seed;
}

class AiInvocationResult {
  final String stdout;
  final String stderrPreview;
  final String? modelReported;       // si el CLI lo expone
  final Duration duration;
}
```

### 9.2. Adapters built-in (F3-F4)

| Provider          | Detección                | Pass prompt   | Pass system               | Notas                                    |
|-------------------|--------------------------|---------------|---------------------------|------------------------------------------|
| `claude`          | `which claude`           | stdin         | `--append-system-prompt`  | Usa `--print` / `-p` y `--output-format text`. |
| `gemini`          | `which gemini`           | archivo temp  | flag específico           | Por confirmar exactos nombres de flag.   |
| `codex`           | `which codex`            | stdin         | flag específico           | Solo si sigue vigente al implementar.    |
| `cursor-agent`    | `which cursor-agent`     | archivo temp  | n/a (prepend al user)     |                                          |
| `aider`           | `which aider`            | `--message`   | n/a (prepend al user)     | Modo non-interactive.                    |
| `ollama`          | `which ollama`           | stdin         | flag `--system`            | Modelo configurable, local fallback.     |
| `custom`          | configurado por usuario  | configurable  | configurable              | Sin código: 100% YAML.                   |

### 9.3. Configuración persistida

Archivo: `~/.masonex/providers.yaml`

```yaml
default: claude
providers:
  claude:
    cmd: ["claude", "-p"]
    pass_prompt: stdin            # stdin | tmpfile | arg
    pass_system: ["--append-system-prompt"]   # nullable
    timeout: 60s
    notes: "configurado el 2026-04-30"
  my_local:
    cmd: ["ollama", "run", "llama3.1"]
    pass_prompt: stdin
    pass_system: null              # se prependea al user prompt con "<<SYSTEM>>...<<END>>"
    timeout: 120s
```

Schema validado con `checked_yaml`. Errores claros si está mal escrito.

### 9.4. Flujo de selección — primera corrida sin config

1. masonex detecta CLIs disponibles en PATH.
2. Imprime, vía `mason_logger`:

   ```
   masonex: no AI provider configured (~/.masonex/providers.yaml not found).
   Detected on PATH:
     1) claude   (Claude Code CLI)
     2) gemini   (Gemini CLI)
   c) configure manually
   q) abort
   Pick:
   ```

3. Si elige una conocida, masonex aplica la plantilla built-in y persiste.
4. Si elige `c`, wizard paso a paso: cmd, pass_prompt, pass_system, timeout, notas.
5. Si elige `q`, abort sin tocar disco.

### 9.5. Flujo en runtime — provider falla

```
masonex: provider 'claude' failed:
  <stderr preview>

Choose:
  e) edit ~/.masonex/providers.yaml and retry
  a) abort the render
```

- `e`: abre `$EDITOR` (default `vi`/`code`), espera salida, recarga config,
  re-intenta el tag fallido (los demás siguen cacheados). Si vuelve a fallar →
  mismo prompt. Loop hasta éxito o abort.
- `a`: abort total, ningún archivo modificado.

### 9.6. Modo no-interactivo

Detección por `MASONEX_NONINTERACTIVE=1` o `--non-interactive` o stdin no-tty.
En ese modo:

- Falta config → abort con mensaje + comando sugerido para configurar.
- Provider falla → abort directo.

### 9.7. Subcomandos `masonex provider`

| Subcomando            | Acción                                                          |
|-----------------------|-----------------------------------------------------------------|
| `provider show`       | Imprime config (sin secretos si los hubiera).                    |
| `provider edit`       | Abre `$EDITOR` y revalida al cerrar.                             |
| `provider test`       | Corre prompt trivial ("respond with the word: ok") y reporta.    |
| `provider reset`      | Borra config (con confirmación).                                 |
| `provider set-default <name>` | Cambia `default` en YAML.                              |

## 10. Cache + trace

### 10.1. Layout

```
.masonex/cache/ai/
  index.json                   # mapa tag_id -> último cache key
  trace.jsonl                  # append-only: una línea por invocación
  outputs/<hash>.txt           # output crudo cacheado
  prompts/<hash>.md            # prompt enviado (debug)
  envelopes/<hash>.xml         # envelope completo (debug)
  system/<hash>.md             # snapshot del system prompt (versionado)
```

### 10.2. Cache key

```
sha256(
  prompt_normalized || "\0" ||
  envelope_normalized || "\0" ||
  system_prompt || "\0" ||
  provider_id || ":" || (model_override ?? "") || ":" || (temperature ?? "")
)
```

`normalized` = trim + LF newlines + sin trailing whitespace por línea.

### 10.3. Política `cache`

| Valor       | Comportamiento                                                                  |
|-------------|---------------------------------------------------------------------------------|
| `auto`      | Lookup en cache. Hit → usa. Miss → invoca y guarda.                             |
| `always`    | Forza usar cache. Miss → error "cache required but not present".                |
| `never`     | Ignora y no escribe cache.                                                      |

CLI overrides:
- `--no-cache-ai`: trata todos los tags como `cache: never`.
- `--refresh-ai`: ignora hit de cache pero sí escribe el nuevo output.
- `--refresh-ai=<glob>`: solo refresca tags cuyos `id` matcheen.

### 10.4. Trace `trace.jsonl`

Una línea por invocación, JSON:

```json
{
  "ts": "2026-05-02T13:45:01Z",
  "tag_id": "lib/foo.dart#L42:c8",
  "prompt_hash": "...",
  "envelope_hash": "...",
  "system_hash": "...",
  "provider": "claude",
  "model": "claude-opus-4-7",
  "duration_ms": 1234,
  "retries": 0,
  "from_cache": false,
  "cache_decision": "miss",
  "output_hash": "...",
  "validation": "ok"
}
```

## 11. Atomicidad — render en dos pasadas

### 11.1. Pasada 1 — Pre-resolución de IA

1. masonex carga el brick y arma el contexto Mustache normal (vars del usuario).
2. Escanea `__brick__` archivo por archivo. Por cada tag con filtro `ai`:
   - Construye el `FilterPipelineNode`.
   - Resuelve el head (literal vs var, con pre-render Mustache).
   - Construye el envelope.
   - Hashea, consulta cache.
   - Si miss → encola para invocación.
3. Ejecuta invocaciones con concurrencia (semáforo, default 4).
4. Aplica validadores y retries con feedback.
5. Si algún tag termina sin output válido → `AiAbortedRender`. Nada se escribe.

### 11.2. Pasada 2 — Render Mustache normal

Los outputs resueltos se inyectan en el contexto de mustachex como variables
sintéticas (`__masonex_ai_<id>`). El template original es reescrito en memoria
(no en disco) sustituyendo cada tag `| ai` por `{{ __masonex_ai_<id> }}` (más sus
post-filtros pasados como filtros normales). El render es 100% determinista y
mason core no se entera.

### 11.3. Garantías

- **No-write-on-failure**: ningún archivo del proyecto es modificado a menos que
  la pasada 1 termine 100% exitosa.
- **Idempotencia con cache caliente**: dos corridas seguidas producen output
  byte-idéntico (asumiendo el provider o el cache devuelven lo mismo).
- **Aislamiento**: la pasada 1 puede correrse standalone (`--dry-run-ai`) sin
  efectos secundarios sobre el proyecto destino.

## 12. Validación, errores, retries

### 12.1. Errores

| Clase Dart                     | Cuándo                                                  | Recuperable        |
|--------------------------------|---------------------------------------------------------|--------------------|
| `AiSyntaxError`                | Parser del filtro falla (args inválidos, comillas, etc.) | No, abort temprano  |
| `AiValidationError`            | Output viola `match` / `oneOf` / `schema` / `lines` / etc. | Sí, reintenta       |
| `AiOutputContractError`        | El modelo devolvió `MASONEX_ERROR: ...`                  | Sí (con feedback)   |
| `AiProviderUnavailableError`   | `which` no encuentra el comando configurado              | Sí (edit-and-retry) |
| `AiProviderInvocationError`    | Exit code != 0 del CLI                                   | Sí (edit-and-retry) |
| `AiAuthError`                  | El CLI reporta no estar autenticado                      | Sí (edit-and-retry) |
| `AiTimeoutError`               | Timeout configurado superado                             | Sí, una vez         |
| `AiContextOverflowError`       | Envelope excede budget aún truncando                     | No, abort           |
| `AiAbortedByUserError`         | Usuario eligió `a` en el prompt de fallo                 | No, abort           |
| `AiCacheError`                 | Corrupción de cache                                      | Sí, recompute       |

Exit codes del CLI de masonex:

- `0`: éxito.
- `2`: error de sintaxis del brick.
- `10`: provider no disponible / no configurado.
- `11`: render abortado por usuario.
- `12`: render abortado por validación insalvable.
- `13`: cache corrupto y `--strict-cache`.

### 12.2. Retries con feedback

Cuando un tag falla validación, masonex reintenta hasta `retries` veces. El
mensaje al modelo en el siguiente intento incluye:

```xml
<previous_attempt>
  <output><![CDATA[ ... ]]></output>
  <validation_error reason="match" detail="output 'Argentina!' does not match /^[A-Za-zÀ-ÿ]+$/">
</previous_attempt>
```

Concatenado al envelope original. Si después de `retries` sigue fallando →
`AiValidationError` → abort.

## 13. CLI surface

### 13.1. Flags nuevos en `mason make`-equivalente de masonex

| Flag                          | Default  | Acción                                                                |
|-------------------------------|----------|-----------------------------------------------------------------------|
| `--no-ai`                     | off      | Saltea pasada 1. Tags `| ai` se renderizan como string visible o placeholder configurable. Útil para CI sin red. |
| `--refresh-ai[=<glob>]`       | off      | Ignora cache hits (opcionalmente solo para los ids que matcheen).     |
| `--no-cache-ai`               | off      | Ni lee ni escribe cache.                                              |
| `--max-ai-concurrency <n>`    | 4        | Override del semáforo.                                                 |
| `--ai-context-preview[=<id>]` | off      | Imprime envelope que se enviaría (uno o todos) sin invocar provider.  |
| `--review-ai`                 | off      | Pausa antes de escribir y permite accept/regenerate/edit por tag.     |
| `--dry-run-ai`                | off      | Corre pasada 1 únicamente. Reporta resoluciones, no escribe nada.     |
| `--non-interactive`           | off      | Falla en lugar de promptear al usuario.                               |
| `--provider <name>`           | —        | Override global del provider para esta corrida.                        |

### 13.2. Subcomandos nuevos

| Subcomando                          | Fase | Acción                                                |
|-------------------------------------|------|-------------------------------------------------------|
| `masonex validate <brick>`          | F1   | Validación estática del brick (incluye chequeos AI).  |
| `masonex audit-ai <brick>`          | F2   | Lista todos los tags `| ai` con prompts y params.     |
| `masonex ai-cache stats|clear|gc`   | F2   | Mantenimiento del cache.                               |
| `masonex ai-trace [opts]`           | F2   | Inspección del trace.                                  |
| `masonex provider <subcmd>`         | F3   | Ver §9.7.                                              |
| `masonex ai-budget <brick>`         | F5   | Estimación de tokens del envelope por tag.             |

## 14. Cambios requeridos en `mustachex`

### 14.1. Scanner

- Agregar tokens de filtro: pipe (`|`), punto (`.`), paréntesis y comas dentro
  de tag content. Hoy `_scanTagContent` toma todo hasta `}}`; hay que tokenizar
  el interior.

### 14.2. Parser

- Agregar `FilterPipelineNode` como nuevo tipo de `Node`, distinto del
  `VariableNode` actual.
- Detectar pipes y `.method()` en tag content y construir el AST.
- Mantener compat: `{{var_cc}}` / `{{name.snakeCase}}` siguen funcionando como hoy
  (se parsean como pipeline de un solo filtro).

### 14.3. Renderer

- Aceptar un `FilterRegistry` inyectado por el caller (masonex). El renderer
  llama al registry para resolver cada filtro.
- Filtros existentes (`uppercase`, `snakeCase`, etc.) hoy viven en
  `mustache_recase` y se aplican via shorthand `_cc`. Se exponen como filtros
  registrados para que `| uppercase` funcione vía el mismo mecanismo.

### 14.4. Resolver

- `VariablesResolver` no requiere cambios funcionales, pero se le agrega un
  `lookup(String name)` que devuelve el valor o `null`. El parser de filtros
  usa esto para distinguir literal vs var.

### 14.5. API pública nueva

```dart
class FilterRegistry {
  void register(String name, FilterFn fn);
  FilterFn? lookup(String name);
}

typedef FilterFn = FutureOr<Object?> Function(
  Object? input,
  Map<String, Object?> namedArgs,
  List<Object?> positionalArgs,
  RenderContext ctx,
);
```

`RenderContext` lleva info que el filtro `ai` necesita (path actual, líneas,
brick, etc.). masonex registra `ai` y los modificadores legacy.

### 14.6. Tests legacy

La suite actual de mustachex debe pasar al 100% sin cambios. Los tests nuevos
viven aparte.

### 14.7. Versión / breaking changes

- Bump menor (no breaking) salvo que el nuevo AST rompa consumidores externos.
- Si hay consumidor además de masonex, se documenta la migración.

## 15. Cambios requeridos en `masonex`

### 15.1. Estructura nueva

```
packages/masonex/lib/src/ai/
  ai.dart                       # barrel
  errors.dart                   # taxonomía de errores
  pipeline/
    pipeline_node.dart          # AST del pipeline (compartido con mustachex)
    parser.dart                 # parser específico de la sintaxis ai (head, args)
  filter_registry/
    builtin_filters.dart        # uppercase, snakeCase, etc.
    ai_filter.dart              # entrypoint del filtro ai
  envelope/
    envelope_builder.dart
    envelope_serializer.dart
    inline_detector.dart
    privacy.dart
    truncator.dart
  system_prompt.md              # asset versionado
  system_prompt.dart            # loader del asset
  provider/
    adapter.dart
    descriptor.dart
    invocation.dart
    registry.dart
    config_yaml.dart
    interactive_setup.dart
    interactive_recovery.dart
    builtin/
      claude.dart
      gemini.dart
      codex.dart
      cursor_agent.dart
      aider.dart
      ollama.dart
      custom.dart
      mock.dart
  cache/
    cache.dart
    trace.dart
    keys.dart
  orchestrator/
    pre_resolver.dart
    semaphore.dart
    resolution.dart
  validation/
    validators.dart             # match, oneOf, schema, lines, ...
    post_processors.dart        # trim, strip_fences, case
    expect.dart                 # tabla expect -> regla
  cli/
    flags.dart
    audit_ai_command.dart
    validate_command.dart
    ai_cache_command.dart
    ai_trace_command.dart
    provider_command.dart
    ai_budget_command.dart
```

### 15.2. Cambios en archivos existentes

- `lib/src/render.dart`: integrar `FilterRegistry` de mustachex con el registry
  de masonex.
- `lib/src/generator.dart`: insertar pasada 1 antes del render.
- `lib/src/hooks.dart`: nada que cambiar, pero documentar que los hooks corren
  después de la pasada 1.
- `bin/masonex.dart`: registrar nuevos subcomandos y flags.
- `pubspec.yaml`: deps nuevas (`xml`, `json_schema`, `synchronized` para semáforo,
  `crypto` ya está, `yaml_edit` para `provider edit`, `glob`).

### 15.3. Compat

Bricks existentes sin tags `| ai` no deben cambiar de comportamiento. El render
de mustachex sin pipes/args sigue siendo idéntico bit a bit.

## 16. Testing

### 16.1. Pirámide

| Nivel        | Foco                                                      | Cobertura objetivo |
|--------------|-----------------------------------------------------------|--------------------|
| Unit         | Parser, validators, post-processors, envelope, cache, registry. | 100%               |
| Integration  | Orquestador con mock provider. Atomicidad. Concurrencia. | 100% líneas críticas |
| E2E          | `bricks/ai_codegen_example` con mock + con CLI faked.    | Smoke + golden     |

### 16.2. Mock provider

`MockAiProvider` lee `brick_test/ai_fixtures.yaml`:

```yaml
fixtures:
  - tag_id: "lib/foo.dart#L42:c8"
    output: "ARGENTINA"
  - match: "dime en una sola palabra que pais"
    output: "Argentina"
```

Modos:

- `strict` (CI default, env `MASONEX_AI_STRICT_MOCK=1`): error si no hay fixture.
- `lenient`: devuelve `MOCK_OUTPUT` con warning.

### 16.3. CLI faked

`test/ai/fakes/fake_cli.sh` — script bash que simula `claude`, `gemini`, etc. con
respuestas configurables por env vars. Permite testear adapters sin instalar
los CLIs reales.

### 16.4. Goldens

Tests de envelope serializado son snapshot tests con archivos en
`test/ai/goldens/`. Cambios al formato requieren actualizar los goldens
explícitamente y aumentar la versión del envelope.

### 16.5. Atomicidad

Test específico:

1. Brick con 5 tags, mock provider configurado para fallar el quinto.
2. Correr render.
3. Assert: ningún archivo del proyecto destino fue creado/modificado.
4. Assert: cache contiene los 4 primeros (no se descartan).

## 17. Documentación — entregables y owners

| Archivo | Fase | Cuándo |
|---|---|---|
| `doc/ai/rfc.md` (este) | F0 | Antes de F1 |
| `doc/ai/architecture.md` | F0 | Junto al spike |
| `doc/ai/syntax.md` | F1 | Junto al parser |
| `doc/ai/equivalences.md` | F1 | Junto al parser |
| `doc/ai/parameters.md` | F2 | Junto a cada parámetro |
| `doc/ai/envelope.md` | F2 | Junto a `EnvelopeBuilder` |
| `doc/ai/system-prompt.md` | F2 | Junto al asset |
| `doc/ai/cache-and-trace.md` | F2 | Junto a `cache/` |
| `doc/ai/atomicity.md` | F2 | Junto al orchestrator |
| `doc/ai/security.md` | F2 | Junto a `privacy.dart` |
| `doc/ai/testing.md` | F2 | Junto al mock provider |
| `doc/ai/providers.md` | F3 | Junto al adapter |
| `doc/ai/providers/claude.md` | F3 | Junto al adapter |
| `doc/ai/providers/<gemini\|codex\|cursor-agent\|aider\|ollama>.md` | F4 | Uno por adapter |
| `doc/ai/providers/custom.md` | F4 | Junto al `CustomProviderAdapter` |
| `doc/ai/troubleshooting.md` | F3+F4 | Iterativo |
| `doc/ai/cli.md` | F2/F3/F5 | Iterativo |
| `doc/ai/recipes.md` | F5+F6 | Junto al brick referencia |
| `doc/ai/budget.md` | F5 | Junto a truncado |
| `doc/ai/tutorial.md` | F6 | Junto al brick referencia |
| `doc/ai/migration.md` | F6 | Para usuarios de `ai_agent_configs` |
| `doc/ai/faq.md` | F7 | Antes de release |
| `doc/ai/README.md` (landing) | F7 | Antes de release |
| `bricks/ai_codegen_example/README.md` | F6 | Junto al brick |
| `packages/masonex/README.md` (sección AI) | F7 | Antes de release |
| `packages/masonex/CHANGELOG.md` | F7 | Antes de release |
| `packages/mustachex/CHANGELOG.md` | F1 | Junto al cambio de AST |
| Dartdoc inline en todo `lib/src/ai/` | Todas | Junto a cada PR |

Regla dura: ningún PR sin sus docs en el mismo PR. Los reviewers rechazan PRs
con código sin doc correspondiente.

## 18. Phasing

| Fase | Alcance                                                                     | Estimado |
|------|-----------------------------------------------------------------------------|----------|
| F0   | Spike, RFC, esqueleto, errores, dirs.                                       | 2-3 d    |
| F1   | Parser de filtros, AST, registry refactor (mustachex+masonex). Sin IA.       | 4-5 d    |
| F2   | Filtro `ai` con mock provider, envelope, system prompt, cache, atomicidad. | 8-10 d   |
| F3   | Adapter Claude, providers.yaml, flujos interactivos.                         | 4-5 d    |
| F4   | Adapters gemini, codex, cursor-agent, aider, ollama, custom.                 | 3-4 d    |
| F5   | UX polish (review, dry-run, preview, truncado, ai-budget).                   | 3-4 d    |
| F6   | Brick referencia, tutorial, recetas, migración.                              | 3-4 d    |
| F7   | Hardening, release, doc audit, CHANGELOG.                                    | 2-3 d    |

Total: ~30-40 días-persona sin contar review.

## 19. Riesgos y mitigaciones

| Riesgo                                                               | Mitigación                                                       |
|----------------------------------------------------------------------|------------------------------------------------------------------|
| Cambios de AST en mustachex rompen consumidores externos              | Compat tests legacy + bump versión + nota en CHANGELOG.          |
| CLIs evolucionan y rompen adapters                                   | `provider test` + adapters versionados + CLI fakes en tests.     |
| Outputs sucios (fences, prefijos)                                    | `strip_fences` + `trim` + system prompt con reglas duras.        |
| Tokens explotan con bricks grandes                                   | Envelope híbrido + truncado + `ai-budget`.                       |
| Privacidad / leak de secretos                                        | Exclusiones default + `ai.context.exclude` + redacción en trace. |
| Tests no-deterministas                                               | Mock obligatorio + `MASONEX_AI_STRICT_MOCK=1` en CI.             |
| `| ai` accidentalmente en path                                       | Validación estática + chequeo en runtime con error claro.        |
| Cache corruption                                                     | Validación de hashes + recompute + flag `--strict-cache`.        |
| Concurrencia rompe trace.jsonl                                       | Append-only con lock por archivo (synchronized).                 |

## 20. Decisiones rechazadas

- **Fallback automático entre providers**: hace impredecible qué modelo respondió;
  reemplazado por edit-and-retry sobre un único provider.
- **Pending files cuando todo falla**: complica modelo mental; reemplazado por
  abort total con cero side-effects.
- **Hook in-process llamando API HTTP**: rompe la promesa determinista de mason
  y mete API keys en el flujo. CLIs son la frontera correcta.
- **Inline AI markers en el archivo final** (`// >>>AI_PROMPT ...`): ensucia
  archivos y depende de comentarios por lenguaje.
- **Manifest central de prompts**: duplica resolución de paths de mason; sidecar
  fue la opción intermedia, descartada en favor de filtros nativos por ser más
  composable.

## 21. Open questions (no bloquean F0)

- ¿`xml` es la mejor codificación para el envelope o conviene JSON con campos
  CDATA? XML es mejor visualmente y más robusto a content con `{}`. Default: XML.
- ¿Versión del envelope se sube cada cambio breaking del schema, o cada minor?
  Default: cada breaking. Las v1.x son aditivas.
- ¿Qué hacer si el modelo devuelve `MASONEX_ERROR: ...` y `retries=0`? Default:
  abort inmediato (no reintentar).
- ¿Permitir filtros custom registrados por el brick? Útil pero complejidad alta.
  Default: v2.

## 22. Referencias

- mason: https://docs.brickhub.dev/
- mustachex: `packages/mustachex/`
- mason_logger: `packages/masonex_logger/`
- Plan original (sesión de planning): se consolida en este RFC.
