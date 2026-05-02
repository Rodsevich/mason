# Cache and trace

## Layout

```
<projectRoot>/.masonex/cache/ai/
  trace.jsonl            # append-only log of invocations
  outputs/<hash>.txt     # cached AI replies (raw, post-validation)
  prompts/<hash>.md      # prompt sent (debug)
  envelopes/<hash>.xml   # full envelope (debug)
  system/<hash>.md       # snapshot of the system prompt
```

## Cache key

```
sha256(
  prompt_normalized || envelope_normalized || system_prompt
  || provider_id || model || temperature
)
```

Normalization: trim trailing whitespace per line and convert CRLF to LF.

## Cache policies

| `cache:` arg | Behaviour |
|--------------|-----------|
| `auto` (default) | Read on hit, write on miss. |
| `always`         | Read-only; missing entry → error. |
| `never`          | No read, no write. |

CLI overrides:

```sh
mason make ...   --refresh-ai          # ignore reads; still write
mason make ...   --no-cache-ai         # disable read AND write
```

## Trace format

`trace.jsonl` is append-only. One JSON entry per line:

```json
{
  "ts":"2026-05-02T13:45:01Z",
  "tag_id":"lib/foo.dart#L42:c8:abc123de",
  "prompt_hash":"...",
  "envelope_hash":"...",
  "system_hash":"...",
  "provider":"claude",
  "model":"claude-opus-4-7",
  "duration_ms":1234,
  "retries":0,
  "from_cache":false,
  "cache_decision":"miss",
  "output_hash":"...",
  "validation":"ok"
}
```

## Inspect

```sh
masonex ai-cache stats
masonex ai-cache clear
masonex ai-trace --last 10
masonex ai-trace --tag lib/foo.dart
```
