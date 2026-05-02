# Testing bricks that use `| ai`

masonex ships a `MockAiProvider` that replays canned responses from
`brick_test/ai_fixtures.yaml`. Use it for:

- Brick CI without network access.
- Reproducible e2e tests.
- Local debugging without burning provider tokens.

## Fixtures format

```yaml
fixtures:
  - tag_id: "lib/foo.dart#L42:c8:abc123de"
    output: "Argentina"
  - match: "the FIFA winner"   # substring match against the prompt
    output: "Argentina"
```

Matching order: `tag_id` first, then `match`. First hit wins.

## Strict vs lenient

| Mode    | Behaviour on missing fixture |
|---------|------------------------------|
| strict  | Throws, aborts the render. CI default. |
| lenient | Returns `MOCK_OUTPUT` and warns. Useful while iterating. |

Set via `MockAiProvider(brickRoot: ..., mode: MockMode.lenient)` or
`MockMode.strict`.

## Wiring in a Dart test

```dart
final result = await source.render(
  vars,
  aiOptions: AiRenderOptions(
    brickRoot: '/path/to/brick',
    relativePath: 'lib/foo.dart',
    useMockProvider: true,
    mockMode: MockMode.strict,
    cacheRootOverride: tmpCachePath,
  ),
);
```

See `packages/masonex/test/ai/integration_test.dart` for the canonical
end-to-end smoke covering: rewriter, two-pass render, cache hit,
atomicity, lenient mode.
