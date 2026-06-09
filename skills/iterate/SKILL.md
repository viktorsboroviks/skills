---
name: iterate
description: Minimal file-based AI session harness — reads i! markers, appends iterations, supports skill decoration and history scan.
user-invocable: true
---

## Usage

```
/iterate [<filepath>] [--history] [/skill [args]]
```

**Parsing rule**: `--history` is a flag; if an arg matches a known skill name
(single-segment, starts with `/`), it is `<skill>`; everything else is `<filepath>`.

## Arguments

- **`<filepath>`** — path to the session file. Required on first invocation; omit to
  reuse the active path from session context. If the file does not exist, it is created.
- **`--history`** — scan conversation history since the previous `/iterate` call and
  prepend a `### Since last iteration` summary to the iteration.
- **`/skill [args]`** — skill to run after processing pending `i!` markers. Args after
  the skill name are forwarded verbatim to the skill.

## Behavior

1. **Resolve active path**: use `<filepath>` if given, else session context. If neither
   exists, respond *"No active iterate session. Run `/iterate <filepath>` to initialize."*
   and stop.
2. **Read**: if `<filepath>` was given or the active path changed, read the full file.
   Otherwise grep for the last `## Iteration` heading, get its line number, and read from
   that line forward.
3. **Init** (new file only): create the file. Skip to step 7.
4. **History** (if `--history`): scan conversation history backward to the previous
   `/iterate` call. Identify substantive events (skill invocations, code changes, answered
   questions; skip `/help`, file reads, trivial navigation). If the boundary is clear,
   build a `### Since last iteration` block with one-line bullets
   (`- [event] → [one-line summary]`). If unclear, omit the block and note it inline.
5. **Collect `i!` markers**: from the read content, find all `i!` markers. Classify as
   plain (`i! text`) or skill (`i! /skillname [args]`).
6. **Respond to plain `i!` markers**: produce a native response addressing each one.
   Omit this step if there are none.
7. **Run skill**: if `/skill` was passed as an argument or a `i! /skill` marker was found,
   run the skill. Append output under `### Command: /skill [args]`.
8. **Append**: write the iteration to the file using bash (`cat >> <filepath>`). Confirm
   with `tail -5 <filepath>`.
9. **First invocation only**: append usage hint — *"Add `i!` inline anywhere in this
   iteration to respond."*

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

**Combined (`i!` markers + skill):**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

[i! response body]

### Command: /skill [args]

[verbatim output]
```

**With `--history` (standalone or combined):**

```markdown
## Iteration #N - YYYY-MM-DD HH:MM

### Since last iteration

- [event] → [one-line summary]

[response body or ### Command block]
```

## Rules

- **`i!` markers**: inline user feedback within the file. A pending marker is a line
  where `i!` appears as a standalone token (followed by a space or end-of-line, not
  inside inline code) after the last `## Iteration #` heading and not inside a fenced
  code block. A marker where the content starts with `/` (`i! /skillname [args]`)
  dispatches that skill instead of producing a native response.
- **`i!` first**: when `/iterate` is invoked with a skill, pending `i!` markers are
  addressed in the same iteration before the skill output.
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
- **Append safety**: always append using bash (`cat >> <filepath>`), not the Edit tool —
  iteration headings repeat across the file and create ambiguous edit anchors.
- **File write failure**: surface the error inline; do not silently skip the append.
