---
description: Propose real values for anvil notes with empty metadata fields, with approval before writing any of them.
---
**Every message you send in this flow starts with `Anvil:`** — not just
the final result. This keeps every step of this Skill visibly identifiable
as an anvil action, distinct from ordinary reasoning or unrelated tool use
— start to finish, not just at the end.

**Write everything in short, simple sentences.** One fact per sentence.
Active voice. Avoid em dashes and long comma-chained clauses.

## What this does

`bin/upgrade` migrations only ever add a missing field empty — they never
guess a real value, because a plain script has no way to judge whether a
guess is actually true. This Skill is the other half: it has real context
(this conversation, past sessions, the note's own content) to propose
values from, but every proposal still goes through the same approval gate
every other anvil write uses. Nothing gets written without your explicit
approval. The vault's accuracy depends on that gate, not on this Skill
being cautious — be willing to propose, but never write unapproved.

## Step 1: find the gaps

Run `__ANVIL_HOME__/bin/audit --field origin` (the one field this covers
today; if asked to check a different field, pass that instead). If it
prints nothing, say so plainly and stop — nothing to fill.

## Step 2: propose only what's actually defensible

For each flagged note, read it. Look for a real, statable signal — not a
vibe:

- **This session wrote or amended it** — you know directly, from this
  conversation, what repo or source it came from.
- **Its `project`/`domain` ties it unambiguously to something known** —
  e.g. `project: anvil` in anvil's own vault means the anvil source repo,
  if you know that repo's path.
- **Checking `bin/recall` or `bin/sessions`/`bin/session-read` turns up
  the session that actually produced it**, and that session makes the
  origin clear.

If one of these gives a real answer, propose the value and state the
reasoning in one short sentence. **If none of them do, say so plainly and
propose nothing for that note** — do not fill a gap just to have filled
it. A note left empty is honest. A note filled with a plausible-sounding
guess is exactly the failure mode this whole mechanism exists to prevent.

If nothing survives this check, say so plainly and stop.

## Step 3: present and approve

List every surviving proposal, numbered:

```
N. <note title>
   propose origin: <value>
   reasoning: <one short sentence>
```

Then ask using the `AskUserQuestion` tool — do not just print the list and
wait for a free-text reply. Set `header` to `Anvil Review`.
- **Exactly one proposal:** plain two-option question, **Approve** /
  **Reject** — `AskUserQuestion` needs at least two options.
- **Two or more:** one multi-select question, one option per proposal —
  select which to approve; anything unselected is skipped.

If the free-text option is used to correct a proposed value instead of
approving or rejecting, use the corrected value, don't just accept or
discard the original guess.

## Step 4: write only what was approved

For each approved note: `Read` it first, then edit **only** the flagged
field's line — never touch anything else in the file, never copy `Read`'s
line-number prefix into the edit (that number is display only; copying it
corrupts the file).

**Report only the outcome.** One `Anvil:` line per note actually amended,
e.g. `Anvil: set origin on anvil/semantic/2026-...-title.md`. Then one
summary line: how many notes were checked, how many got a proposal, how
many were approved and written, how many had no defensible signal and
were left as-is.

$ARGUMENTS
