---
name: iterate
description: Minimal file-based AI session harness — reads i! markers, appends iterations, supports skill decoration and history scan.
user-invocable: true
---

## Usage

```
/iterate [<filepath>] [--history] [--marker <prefix>] [/skill [args]]
```

**Parsing rule**: `--history` and `--marker` are flags; if an arg matches a known skill
name (single-segment, starts with `/`), it is `<skill>`; everything else is `<filepath>`.

## Arguments

- **`<filepath>`** — path to the session file. Required on first invocation; omit to
  reuse the active path from session context. If the file does not exist, it is created.
- **`--history`** — scan conversation history since the previous `/iterate` call and
  prepend a `### Since last iteration` summary to the iteration.
- **`--marker <prefix>`** — inline feedback marker prefix to scan for. Defaults to `i!`.
  Pass `--marker r!` to use `r!` markers (e.g., when invoked from `/rubberduck`).
- **`/skill [args]`** — skill to run after processing pending markers. Args after
  the skill name are forwarded verbatim to the skill.

## Behavior

1. **Resolve active path**: use `<filepath>` if given, else session context. If neither
   exists, respond *"No active iterate session. Run `/iterate <filepath>` to initialize."*
   and stop.
2. **Read**: if `<filepath>` was given or the active path changed, read the full file.
   Otherwise grep for the last `## Iteration` heading, get its line number, and read from
   that line forward.
3. **Init** (new file only): create the file. Skip to step 5.
4. **History** (if `--history`): scan conversation history backward to the previous
   `/iterate` call. Identify substantive events (skill invocations, code changes, answered
   questions; skip `/help`, file reads, trivial navigation). If the boundary is clear,
   build a `### Since last iteration` block with one-line bullets
   (`- [event] → [one-line summary]`). If unclear, omit the block and note it inline.
5. **Run CLI skill**: if `/skill` was passed as an argument, run it now. Append output
   under `### Command: /skill [args]`. Omit this step if no CLI skill was given.
6. **Collect markers**: from the read content, find all markers matching the active prefix
   (default `i!`; overridden by `--marker`). Classify as plain (`<prefix> text`) or skill
   (`<prefix> /skillname [args]`).
7. **Run marker-invoked skills**: dispatch each `<prefix> /skill` marker in file order.
   Append each output under `### Command: /skill [args]`. Omit this step if there are none.
8. **Respond to plain markers**: produce a native response addressing each one, with
   context from steps 5 and 7. Omit this step if there are none.
9. **Append**: write the iteration to the file using bash (`cat >> <filepath>`). Confirm
   with `tail -5 <filepath>`.
10. **After iteration #1 is appended (only once)**: append usage hint — *"Add `<active-marker>` inline anywhere in this
    iteration to respond."* (substitute the active marker prefix, e.g. `i!` or `r!`).

## Iteration formats

**Native:**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

[response body]
```

**Wrapped command:**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

### Command: /skill [args]

[verbatim output]
```

**Combined (CLI skill + plain markers):**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

### Command: /skill [args]

[verbatim output]

---

[plain marker response body]
```

**Combined (CLI skill + marker skills + plain markers):**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

### Command: /cli-skill [args]

[cli verbatim output]

### Command: /marker-skill [args]

[marker verbatim output]

---

[plain marker response body]
```

The `---` separator in Combined formats appears only when plain marker responses follow
the skill blocks. Omit it when there are no plain responses.

**With `--history` (standalone or combined):**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

### Since last iteration

- [event] → [one-line summary]

[response body or ### Command block]
```

## Rules

- **Markers**: inline user feedback within the file. A pending marker is a line
  where the active prefix (default `i!`; overridden by `--marker`) appears as a
  standalone token (followed by a space or end-of-line, not inside inline code) after
  the last `## Iteration #` heading and not inside a fenced code block. A marker where
  the content starts with `/` (`<prefix> /skillname [args]`) dispatches that skill
  instead of producing a native response.
- **CLI skill first**: when `/skill` is passed as an argument, it runs before all
  markers. Marker-invoked skills (`<prefix> /skill`) run after the CLI skill, in file
  order. Plain markers are addressed last, with context from all preceding skill output.
- **Incremental reads**: on re-invocation, grep for the last `## Iteration #[0-9]`
  heading and read from that line forward; full-file read only on init or active-path
  change. The pattern `^## Iteration #[0-9]` matches any iteration number (the digit
  anchors the prefix; multi-digit numbers match on their first digit).
- **External file changes**: any change to a file other than the active session file
  requires an explicit go from the user. When `i!` markers imply external changes,
  list the proposed changes (filename + one-line purpose) and end with "Awaiting
  `i! go`." — do not execute until the user responds with `i! go` (case-insensitive,
  standalone). "approved", "sounds good", and imperative instructions (`apply`,
  `do it`) do not qualify. A go covers only the changes listed in the preceding
  proposal; new requests require their own go.
- **Append-only**: never modify previous iterations or remove user comments.
- **Session-scoped**: the active filepath lives in conversation context only — no
  file-based state, no sentinel file. If the active path is missing from context
  (e.g., after compaction), scan the conversation history backward for the most
  recent `/iterate <filepath>` invocation and restore from it.
- **Timestamp**: extract from system context using local time; format `YYYY-MM-DD HH:MM`
  (no seconds, no timezone offset).
- **Heading normalization**: when appending skill output under a `### Command:`
  heading, shift all heading lines (lines starting with one or more `#`) one
  level deeper by prepending one `#`. Skip lines inside fenced code blocks
  (between ` ``` ` fences). This keeps each skill's own heading hierarchy intact
  while nesting it correctly under the command block.
- **Append safety**: always append using bash (`cat >> <filepath>`), not the Edit tool —
  iteration headings repeat across the file and create ambiguous edit anchors.
- **File write failure**: surface the error inline; do not silently skip the append.
