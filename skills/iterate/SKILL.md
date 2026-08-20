---
name: iterate
description: Minimal file-based AI session harness — single-emission (the iteration body is written once, to the file; the CLI reply is a bare status line). Reads i! markers, appends iterations, supports skill decoration and history scan.
user-invocable: true
---

## Usage

```text
Usage: /iterate [<filepath>] [--history] [--marker <prefix>] [</skill [args]>]

Arguments:
  <filepath>         Path to session file (required on first call).
  --history          Prepend "Since last iteration" summary.
  --marker <str>     Feedback marker prefix [default: i!].
  </skill [args]>    Skill to run after processing markers.
  --help, -h         Show this help.
```

**Parsing rule**: `--history`, `--marker`, `--help`, and `-h` are flags; if an arg
matches a known skill name (single-segment, starts with `/`), it is `<skill>`; everything
else is `<filepath>`. `--help` / `-h`: output the `## Usage` block and stop.

## Arguments

- **`<filepath>`** — path to the session file. Required on first invocation; omit to
  reuse the active path from session context. The file must exist; if not found, an error
  is returned.
- **`--history`** — scan conversation history since the previous `/iterate` call and
  prepend a `### Since last iteration` summary to the iteration.
- **`--marker <prefix>`** — inline feedback marker prefix to scan for. Defaults to `i!`.
  Pass `--marker r!` to use `r!` markers (e.g., when invoked from `/rubberduck`).
- **`/skill [args]`** — skill to run after processing pending markers. Args after
  the skill name are forwarded verbatim to the skill.
- **`--help`, `-h`** — output the `## Usage` block and stop. No file is read or written.

## Behavior

0. **Help**: if `--help` or `-h` is in the argument list, output the `## Usage` block and
   stop — no file is read or written.
1. **Resolve active path**: use `<filepath>` if given, else session context. If neither
   exists, respond *"No active iterate session. Run `/iterate <filepath>` to initialize."*
   and stop.
2. **Read**: read the full file only when there is no active path yet, or the given
   `<filepath>` differs from the active path (a genuinely new session). When the given
   path equals the active path already in context — or no path was given — use the
   incremental read: grep for the last `## Iteration` heading, get its line number, and
   read from that line forward. Passing the same path again does not force a full re-read;
   markers are only actionable after the last heading and the file is append-only, so the
   incremental read is always sufficient on a same-path re-invocation.
3. **File check**: if the file does not exist, respond *"File not found: `<filepath>`.
   Create it first, then run `/iterate <filepath>`."* and stop.
4. **History** (if `--history`): scan conversation history backward to the previous
   `/iterate` call. Identify substantive events (skill invocations, code changes, answered
   questions; skip `/help`, file reads, trivial navigation). If the boundary is clear,
   build a `### Since last iteration` block with one-line bullets
   (`- [event] → [one-line summary]`). If unclear, omit the block and note it inline.
5. **Run CLI skill**: if `/skill` was passed as an argument, run it now. Compose its
   output under `### Command: /skill [args]` **into the iteration body** — do not print it
   as a conversational response; it is emitted once, in step 9. Omit this step if no CLI
   skill was given.
6. **Collect markers**: from the read content, find all markers matching the active prefix
   (default `i!`; overridden by `--marker`). Classify as plain (`<prefix> text`) or skill
   (`<prefix> /skillname [args]`).
7. **Run marker-invoked skills**: dispatch each `<prefix> /skill` marker in file order.
   Compose each output under `### Command: /skill [args]` **into the iteration body** — do
   not print it as a conversational response; it is emitted once, in step 9. Omit this
   step if there are none.
8. **Respond to plain markers**: compose a response addressing each one (with context from
   steps 5 and 7) **into the iteration body** — do not print it as a conversational
   response; it is emitted once, in step 9. Omit this step if there are none.
9. **Append to file — the sole emission (mandatory completion gate)**: the iteration body
   composed in steps 4–8 is emitted exactly once, here, via a single bash
   `cat >> <filepath>` heredoc, then `tail -3 <filepath>` confirms. The body must NOT also
   be printed as a conversational response: that duplicate doubles output tokens for no
   benefit, since the file is the deliverable and the heredoc is already visible in the
   tool-call panel. The iteration is not done until the append has executed; reaching
   end-of-turn without it leaves the session inconsistent. Non-skippable — it fires even
   when steps 5–8 are all omitted. **Use a quoted heredoc delimiter** (`<<'EOF'`) whose
   token appears nowhere in the body, so backticks, `$`, and `$(...)` in the body are
   written literally rather than expanded by the shell.
10. **After iteration #1 is appended (only once)**: append usage hint — *"Add `<active-marker>` inline anywhere in this
    iteration to respond."* (substitute the active marker prefix, e.g. `i!` or `r!`).
11. **Conversational reply — bare status only**: after the append, the entire visible
    reply is one line: *"Iteration #N appended to `<filepath>`."* Add at most one further
    line, and only to surface a blocking error. Never restate, summarize, or preview the
    body — it lives in the file.

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
- **Single emission (token discipline)**: the iteration body — including any CLI-skill,
  marker-skill, and plain-marker output — is generated exactly once, as the `cat >>`
  heredoc argument in step 9, and never also emitted as a conversational response; the
  visible channel carries only the one-line status. Sub-skills invoked under `/iterate`
  (e.g. `/rubberduck-method`) compose their output *into* the appended body rather than
  printing it separately. This roughly halves output tokens (measured ~835 saved on a
  2.4 KB body) with no loss to the file, which is the deliverable.
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
  iteration headings repeat across the file and create ambiguous edit anchors. Quote the
  heredoc delimiter (`<<'EOF'`) and pick one absent from the body so shell metacharacters
  in the body are not expanded.
- **File write failure**: surface the error inline; do not silently skip the append.
