# Security and privacy

By design, masonex sends to the AI provider:

- The brick's name, version and description.
- The user-supplied variable values.
- A **list** of every file under `__brick__/`.
- The **contents** of the file currently being rendered.
- The lines surrounding each `| ai` tag.
- Any files explicitly added with `include:` and any `extra_context:`.

It does **not** send:

- Files outside `__brick__/`.
- Anything matching the default privacy exclude list:
  - `.env`, `.env.*`
  - `*.pem`, `*.key`
  - `secrets/**`, `**/secrets/**`
  - `**/.git/**`, `**/node_modules/**`

Brick authors can extend the exclude list per brick:

```yaml
# brick.yaml
ai:
  context:
    exclude:
      - "lib/legacy/**"
      - "**/credentials.yaml"
```

## What ends up where

| Location                                  | What           | Visibility |
|-------------------------------------------|----------------|------------|
| Provider's CLI (e.g., `claude`)           | system + envelope | provider's own logging policy |
| `.masonex/cache/ai/outputs/<hash>.txt`    | AI reply       | local file, gitignored by default in user projects |
| `.masonex/cache/ai/envelopes/<hash>.xml`  | full envelope  | local file |
| `.masonex/cache/ai/trace.jsonl`           | hashes + meta  | local file |

## Recommendations

1. Add `.masonex/cache/` to your `.gitignore`.
2. Run `masonex audit-ai <brick>` before publishing a brick to verify the
   prompts you ship.
3. For private bricks, prefer `provider: ollama` (or another local LLM)
   to keep prompts on-device.
4. Treat `~/.masonex/providers.yaml` as configuration, not as a place to
   store secrets — the file is plain YAML.
