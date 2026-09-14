---
description: Mine anvil notes from past Claude Code and Grok Build sessions, with approval before writing any.
---
**Every message you send in this flow starts with `Anvil:`** — not just
the final result. This keeps every step of this Skill visibly identifiable
as an anvil action, distinct from ordinary reasoning or unrelated tool use
— start to finish, not just at the end.

**Write everything in short, simple sentences — narration and note bodies
alike.** One fact per sentence. Active voice. Avoid em dashes and long
comma-chained clauses; split them into separate short sentences instead.
This applies everywhere in this flow, not just the note bodies.

## What this does

This project has session history from before anvil existed, or from
sessions that never ran `/note` or `/reflect`. `/hydrate` walks that
history — both Claude Code's and Grok Build's — and proposes candidate
notes from it, the same way `/reflect` does for the live conversation.
Nothing gets written without approval, same as every other anvil write path.

## Step 1: list what's available

Run `__ANVIL_HOME__/bin/sessions --exclude <this session's ID>`. Identify
"this session" as whichever entry has the newest timestamp and is clearly
still growing — there's no clean way to ask the shell for that ID directly,
so use judgment, not a fixed rule.

If the command prints nothing, say so plainly and stop: no past sessions
found for this project, on either engine.

Otherwise, show the full list, numbered. `bin/sessions` scans the current
directory **and every subdirectory beneath it** — a session launched from
a monorepo's root and one launched from a package inside it are otherwise
invisible to each other, since Claude Code keys them by exact literal
directory. Run this from whichever directory you want to sweep (a
monorepo root, to catch every package in one pass) — it does not look
upward at parent directories, only cwd and down. Because of that, **group
the list by the `source_dir` column, one heading per directory, cwd
itself first, then its subdirectories** (matching `bin/sessions`'s own
sort order — not interleaved by timestamp across directories):

```
### <source_dir 1, e.g. cwd itself>
N. 🟡 new — claude, 2026-09-11 17:17 — "<gist>"
N. 🟢 hydrated — claude, 2026-09-10 14:02 — "<gist>"

### <source_dir 2, a subdirectory>
N. 🟡 new — claude, 2026-09-09 09:15 — "<gist>"
```

Numbering continues across the whole list, not restarting per directory —
so picking "session 4" in Step 2 stays unambiguous regardless of which
heading it's under. If every session shares the same `source_dir` (the
common case: no subdirectories have their own sessions), skip the heading
entirely and just show a flat list — don't print a heading for a single
group, that's noise.

This chat view renders markdown, not raw terminal color, so use an emoji
per status instead of ANSI color (running `bin/sessions --pretty`
directly in a real terminal gets real ANSI color, but that's a separate
path from this Skill):
- 🟡 `new` — not yet hydrated
- 🟢 `hydrated` — fully processed, every candidate got a decision
- 🟣 `partial` — processed, but stopped before every candidate got a decision
- 🔴 `failed` — couldn't be read or parsed at all

Use the gist `bin/sessions` already extracted — don't re-derive or
re-summarize it. Don't read any session's full content yet. This step is
just the menu.

## Step 2: pick one session

**Ask, don't just default silently.** Use `AskUserQuestion` with two
options — `AskUserQuestion` caps at 4 options, so it can't list all
sessions individually:
- **Process the newest not-yet-hydrated session** (recommended) — session
  N from the list, named explicitly in the option's description.
- **Pick a different one** — if I choose this, or use the tool's free-text
  option to name a number/date/description directly, use whichever
  session I named instead. The list from Step 1 exists specifically so
  this doesn't have to be strictly newest-to-oldest.

Run `__ANVIL_HOME__/bin/session-read --engine <claude|grok> <path>` on the
chosen session. Say plainly which session this is (engine, rough date)
before digging into it, so I always know what's being mined right now.

If `session-read` reports it couldn't parse a Grok session's messages (a
schema mismatch), say so plainly, record that session as `failed` in
`hydrated.tsv` right away (see Step 6's format — status `failed`, 0 notes,
detail explaining what didn't parse) so the next listing shows it
accurately instead of silently re-offering it as `new` forever, then go
back to Step 1's list.

## Step 3: extract candidates

Same bar as `/reflect`: decisions made, lessons learned, facts established.
Not:
- Anything that's just a summary of work done (belongs in conversation,
  not the vault).
- Test or throwaway artifacts.

## Step 4: check against what's already known — this is the important part

Sessions get processed newest-first, on purpose: whatever's already
canonical (or already approved earlier in *this* hydrate run, from a
more-recent session) reflects more-developed understanding than an older
session does. Older material has to clear that bar, not just show up as a
fact somewhere.

For every surviving candidate, run `__ANVIL_HOME__/bin/recall` on its
likely keyword before drafting anything. Four possible outcomes:

- **Nothing relevant found** — draft it as a new note.
- **An existing canonical note already says essentially this** — drop it,
  not worth re-adding.
- **An existing note covers the same topic, and this is a small addition
  or clarification, not a distinct claim** — propose an amendment instead
  of a new note.
- **An existing canonical note (or a candidate already approved earlier
  in this same hydrate run) actively disagrees with what this older
  session says** — do not draft it as current fact, and do not silently
  drop it either. Surface the conflict plainly: what this session says,
  what the newer note says, and that they disagree. Let me decide — the
  old material might turn out to be the thing that was right, but that is
  my call, not an automatic write in either direction.

If nothing survives this session, say so plainly, record it as `hydrated`
anyway (see Step 6 — a session that yielded nothing still counts as fully
processed, not `partial`), and move to Step 7's checkpoint.

## Step 5: draft, same format as `/note` and `/reflect`

Present every surviving candidate numbered:

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
- tags: [..., hydrated]
- origin: <bin/note auto-detects this from the current directory when
  writing — since hydrate is scoped to this project, that's normally
  correct. If the old session was actually about a different repo than
  the one you're sitting in right now, override it explicitly instead of
  trusting the auto-detected value.>

Body:
<the full body text — under ~400 words, one claim per note, no transcript
dump>
```

Always include `hydrated` in tags, so a note's provenance (written live vs.
recovered from old session history) stays visible later. For a flagged
conflict (Step 4's fourth outcome), show the conflict clearly instead of a
draft, and let me tell you what to do with it.

Then ask me to decide using the `AskUserQuestion` tool — do not just print
the list and wait for a free-text reply. Set `header` to `Anvil Review`.
- **Exactly one candidate survived:** ask a plain two-option question,
  **Approve** / **Reject** — `AskUserQuestion` needs at least two options,
  so a one-item multi-select is invalid.
- **Two or more survived:** one multi-select question, one option per
  candidate — I select which to approve; anything unselected is skipped.

If I use the tool's free-text option to request a change instead of
approving or rejecting, revise just that draft and ask again before
writing anything.

## Step 6: write and record

Only write or amend what I approved, after I've actually chosen.
`__ANVIL_HOME__/bin/note` handles MOC linking automatically — don't do
that step yourself. Always pass `--source claude` or `--source grok`,
matching whichever engine produced the session this candidate came from —
never default to `human`. Also pass `--origin` explicitly, matching what
was shown in the draft.

When amending, read the file with `Read` first, and never copy `Read`'s
line-number prefix into the edit — that number is display only, not real
file content.

After writing (or after a session that yielded nothing), append one line
to `${XDG_STATE_HOME:-$HOME/.local/state}/anvil/hydrated.tsv`:
```
<session_id>	<engine>	<current UTC timestamp>	<status>	<notes_written>	<detail>
```
Use a real tab between fields. `status` is one of:
- `hydrated` — every candidate this session produced got a decision
  (approved-and-written, or explicitly rejected). Also use this when the
  session produced zero candidates — that's still fully processed.
- `partial` — I stopped the review before every candidate got a decision
  (e.g. I said stop mid-approval), or a `bin/note` call failed for one
  candidate while others succeeded. `detail` should say what was left
  unresolved.
- `failed` — covered in Step 2; used when the session couldn't be parsed
  at all, before any candidates existed.

`detail` is a short free-text reason, useful for `partial`/`failed` rows —
`hydrated` rows can leave it as `-` or a one-line summary.

If a session gets processed more than once (I explicitly re-pick an
already-hydrated one), append a new row rather than editing the old one —
`bin/sessions` already uses the last matching row, so history isn't lost.

**Report only the outcome, not the mechanics.** One `Anvil:` line per note
written or amended, same format `/note` and `/reflect` use. Don't narrate
the individual tool calls behind it.

## Step 7: checkpoint

Ask via `AskUserQuestion` how to continue:
- **Go to next 🟡 new session** — repeat from Step 2 with the newest
  remaining `new` session.
- **Pick a different one from the list** — repeat from Step 2 with
  whichever session I name, any status; re-processing an already-hydrated
  one is fine, it still goes through Step 4's recall/supersession check,
  so it can't produce duplicates.
- **Stop here** — give one final summary line: sessions processed this
  run (and their resulting status), notes written or amended, conflicts
  flagged and left for me to resolve.

$ARGUMENTS
