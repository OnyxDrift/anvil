---
description: Review this session, draft candidate anvil notes, and get approval before writing any of them.
---
**Every message you send in this flow starts with `Anvil:`** — not just
the final result. `Anvil: reviewing this session...`,
`Anvil: N candidates survived...`, all the way through to the final
result line. This keeps every step of this Skill visibly identifiable as
an anvil action, distinct from ordinary reasoning or unrelated tool use —
start to finish, not just at the end.

**Write everything in short, simple sentences — narration and note
bodies alike.** One fact per sentence. Active voice. Avoid em dashes and
long comma-chained clauses; split them into separate short sentences
instead. This applies to every candidate's frontmatter and body, and to
all narration around them, not just one note in isolation.

Review this session so far. Identify anything durably worth remembering —
decisions made, lessons learned, facts established.

Do not treat these as worth a note:
- Anything that's just a summary of what we did (that belongs in this
  conversation, not the vault).
- Test or throwaway artifacts.

For each candidate claim, run `__ANVIL_HOME__/bin/recall` on its likely
keyword first. Three outcomes per candidate:

- **Nothing relevant found** — draft it as a new note, below.
- **An existing note already says essentially this** — drop the
  candidate entirely, it's not worth listing again.
- **An existing note covers the same topic, but this is a small addition,
  correction, or clarification to it** (not a distinct new claim) —
  propose an **amendment** to that file instead of a new note: the
  specific lines to change or add, plus the new `updated:` date, nothing
  else in its frontmatter touched.

If nothing survives this, say so plainly and stop — don't draft anything
just to have produced output.

**Otherwise, draft — do not write or edit anything yet.** Present every
surviving candidate numbered, and for each one, **use the exact same
"Draft: / Body:" layout `/note` uses — not a prose paragraph summarizing
the same information.** That means, per candidate:

```
N. <one-line title>

Draft:
- type: <semantic|procedural|strategic|episodic>
- domain: <must match a line in domains.txt>
- subdomain: <check bin/status's tree first, reuse over inventing —
  normally a tool/technology, never a project. For a domain where notes
  usually aren't about software tooling (e.g. trading, finance), may
  instead be a topical sub-category of that domain (e.g. backtesting,
  portfolio-theory) — still never a project>
- project: <one of my named projects, never a tool; a claim about anvil
  itself uses anvil, not whatever repo anvil happens to live in>
- tags: [...]
- origin: <what backs the claim, not who wrote the note. bin/note
  auto-detects this for code — a git remote URL, or the repo root, or the
  working directory if not a git repo at all — show what it detected so
  it can be overridden. For a non-code domain, ask or derive it from the
  conversation instead of leaving it blank.>

Body:
<the full body text, as you intend to write it — under ~400 words, one
claim per note, no transcript dump>
```

Dense paragraphs that merge the frontmatter and body into running prose
are not this format — every field gets its own line, same as `/note`.

**If a candidate needs a new domain, and I approve adding it,** also
create that domain's MOC file in the same step —
`__ANVIL_HOME__/moc/<Title>.md` (domain name, first letter capitalized)
containing exactly:
```
# <Title>
```
`install.sh` normally generates this; adding a domain here instead skips
that unless done explicitly — this has actually happened once already
(a domain added with no matching MOC file, silently).

For an amendment, show only what's actually changing in the existing file.

**Then ask me to decide using the `AskUserQuestion` tool — do not just
print the list and wait for a free-text reply.** Set that question's
`header` field to `Anvil Review` in every case below (fits the tool's
12-character header limit exactly; don't try to cram more description in
there — the question text itself has no such limit).

- **If exactly one candidate survived:** `AskUserQuestion` requires at
  least two options per question, so a one-item multi-select is invalid
  and will fail. Ask a plain two-option question instead, same shape as
  `/note`'s: **Approve** / **Reject**. Still use header `Anvil Review`,
  not `Anvil Note` — this is `/reflect`, not `/note`, even with one item.
- **If two or more candidates survived:** ask one multi-select question,
  one option per candidate (the option's label a short title, its
  description the one-line summary) — I'll select which ones to approve;
  anything I don't select is skipped.

Either way, if I want changes to a specific candidate instead of
approving or skipping it, I'll use the tool's own free-text option to say
so — revise just that draft and ask again with `AskUserQuestion` before
writing it.

Only write or amend the ones I approved, after I've actually made a
selection — never touch a candidate before that. An amendment should
never touch `type`/`domain`/`project`/`source` — only the body and
`updated:` date, unless I say otherwise. **Always pass `--source claude`
when calling `bin/note`** — its default is `human`, wrong for anything
this Skill writes; get it right the first time, not with a follow-up edit.
**Also pass `--origin` explicitly**, matching what was shown in the draft
— don't let `bin/note` silently re-detect it at write time.

**When amending, read the file with `Read` before editing it, and never
copy `Read`'s line-number prefix into an edit.** That number is display
only, not real file content — copying it in corrupts the file (a heading
silently becoming `2# Title` instead of `# Title` is exactly this
mistake, and it has actually happened once already).

**MOC linking is automatic and built into `bin/note` itself** — for each
new canonical note, the script links it into its domain's MOC file
(`__ANVIL_HOME__/moc/<Domain-Title>.md`, under a `## <Subdomain-Title>`
heading if the note has one, as an Obsidian wiki-link
`- [[<filename-without-.md>]]`) as part of writing the file. Don't do this
step yourself and don't ask "should this be linked?" — running `bin/note`
already does it. An amendment doesn't need this step; the note is already
linked.

**Report only the outcome, not the mechanics.** After writing, list what
actually happened, each line starting with `Anvil:` — e.g. `Anvil: wrote
new note at anvil/procedural/2026-...-title.md (linked from
moc/Software.md)` or `Anvil: amended anvil/semantic/2026-...-title.md`.
Use paths relative to the vault root (`anvil/<type>/<file>.md`), not the
full absolute path — that's for your own tool calls to use internally,
not what you report back.

**None of the individual mechanical steps get their own announcement —
they're all folded into those final lines.** Don't say "now I'll create
the note, then fill in the body" — none of that, for any candidate.
`bin/note` and the body edit are two tool calls behind one user-facing
action per note; do both silently and report only the combined result
per note.

$ARGUMENTS
