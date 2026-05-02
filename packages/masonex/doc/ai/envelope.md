# The envelope

masonex sends each AI invocation as a *system prompt* (fixed, versioned)
plus a *user prompt* serialised as XML. The XML is referred to as the
**envelope** and follows this schema:

```xml
<masonex_render_request version="1">
  <meta>
    <brick name="..." version="..." description="..."/>
    <provider name="claude" model="..."/>
    <user_vars>
      <var name="className">FooRepository</var>
    </user_vars>
  </meta>

  <brick_contents>
    <files>
      <file path="__brick__/lib/foo.dart" included="true"/>
      <file path="__brick__/test/foo_test.dart" included="false"/>
    </files>
    <file path="__brick__/lib/foo.dart"><![CDATA[ ... ]]></file>
  </brick_contents>

  <current_file path="lib/foo.dart" language="dart"/>

  <surrounding_text>
    <before><![CDATA[...]]></before>
    <after><![CDATA[...]]></after>
  </surrounding_text>

  <tag inline="true" original="{{ &quot;...&quot; | ai(...) }}"/>

  <previous_ai_resolutions/>
  <extra_files/>
  <extra_context/>
  <previous_attempt>...</previous_attempt>  <!-- only on retries -->

  <task>
    <prompt><![CDATA[...]]></prompt>
    <expected_shape>...</expected_shape>
    <constraints>...</constraints>
    <post_filters>uppercase</post_filters>
    <author_note/>
  </task>
</masonex_render_request>
```

Notes:

- `inline="true"` adds a "single line, no newlines" rule to
  `<expected_shape>`.
- `<post_filters>` is informational. masonex applies them after the AI
  reply; the model must NOT apply them itself.
- `<previous_attempt>` appears only on retries. It contains the previous
  output and the validation reason it failed for.
- The envelope is content-addressed and feeds directly into the cache key
  (with the system prompt hash).
