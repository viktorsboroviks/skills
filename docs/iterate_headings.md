# iterate — technical reference for managing headings

Supplement to `skills/iterate/SKILL.md`. Covers conventions relevant to skill
authors and session-file readers.

## Heading normalization

When iterate appends skill output under a `### Command: /skillname` block, it
shifts all heading lines in the output one level deeper (one `#` prepended).
Lines inside fenced code blocks are not shifted.

**Why**: session files use `##` for iteration headings and `###` for command
blocks. Skill output nested under `### Command:` should start at `####` to
keep the heading hierarchy valid. Requiring every skill to hard-code `####`
couples it to the embedding context; iterate owns the shift instead.

**For skill authors**: use your skill's own natural heading hierarchy. Top-level
headings at `##` or `###` are typical. Do not adjust for embedding — iterate
normalizes on output.

**Example** — skill produces:

```markdown
## My section

Content.

### Subsection
```

Session file receives (after normalization):

```markdown
#### My section

Content.

##### Subsection
```

**Code blocks are excluded**: headings inside ` ``` ` fences are copied
verbatim, not shifted. This preserves template blocks and code examples that
contain heading syntax.
