---
description: Draft one atomic note for the anvil vault (or an update to an existing one) and get approval before writing it.
---
**Every message you send in this flow starts with `Anvil:`** — not just
the final result. `Anvil: searching for an existing note on this...`,
`Anvil: drafting a new note...`, `Anvil: writing it now...`, all the way
through to the final result line. This keeps every step of this Skill
visibly identifiable as an anvil action, distinct from ordinary reasoning
or unrelated tool use — start to finish, not just at the end.

**Write everything in short, simple sentences — narration and note
bodies alike.** One fact per sentence. Active voice. Avoid em dashes and
long comma-chained clauses; split them into separate short sentences
instead. This applies everywhere in this flow, not just the final note
body — including the frontmatter proposal and the approval question.

What I gave you: $ARGUMENTS

This may be a fully-dictated claim ("we decided X because Y") or just a
subject/pointer ("the syncthing port-forward fix", "today's ripgrep
detection change"). If it reads like a topic rather than a complete
claim, don't ask me to restate it — pull the actual substance yourself
from this conversation and write the real claim, the same way you would
for `/reflect`.

**First, check for an existing note on the same claim:** run
`__ANVIL_HOME__/bin/recall` on the likely keyword. If nothing relevant
comes up, skip straight to drafting a new note, below. If something does
come up, read it and decide which of these actually fits — don't default
to "new note" out of convenience:

- **This is a small addition, correction, or clarification to the exact
  same claim** (e.g. a detail that changed, a wrong number, a follow-up
  that doesn't change what the note is fundamentally about) — propose
  **amending the existing file in place**: show me the specific lines
  you'd change or add, and the new `updated:` date. Everything else in
  its frontmatter stays as-is.
- **This is a related but genuinely distinct claim** (a different fact,
  decision, or lesson that happens to touch the same topic) — propose a
  **new note**, and mention the existing one so I can judge whether they
  should stay separate.
- **This isn't actually the same thing** (recall just matched on a shared
  keyword) — proceed as a new note, no need to mention the old one.

**Then draft — do not write or edit anything yet.** For a new note, show
me the full proposed frontmatter and body:

- `--type` (`semantic`|`procedural`|`strategic`|`episodic`)
- `--domain` (must match a line in `__ANVIL_HOME__/domains.txt` — if none
  genuinely fit, ask me before adding a new line there, don't pick the
  closest one). **If I approve a new domain, also create its MOC file in
  the same step** — `__ANVIL_HOME__/moc/<Title>.md` (domain name with the
  first letter capitalized) containing exactly:
  ```
  # <Title>
  ```
  `install.sh` normally generates this file; adding the domain through
  this Skill instead means that generation step needs to happen here too,
  or the domain silently has no MOC entry (this has actually happened —
  `craft` was added to `domains.txt` without its MOC file, undetected
  until the user noticed).
- `--subdomain` — **before inventing one, run `__ANVIL_HOME__/bin/status`
  and check the tree under this note's domain for a subdomain that
  already fits.** Reuse an existing one over creating a near-synonym
  (`claude-skills` vs. a new note calling it `skills`, `claude-code`,
  etc.) — subdomains are supposed to consolidate related notes, not
  fragment them. Only propose a new subdomain value if nothing existing
  genuinely fits, and say so explicitly in the draft so I can weigh in.
  Normally a tool/technology/language — never one of my projects. For a
  domain where notes usually aren't about software tooling at all (e.g.
  `trading`, `finance`), it may instead be a topical sub-category of that
  domain (e.g. `backtesting`, `portfolio-theory`, `performance-metrics`)
  — still never a project.
- `--project` (one of my named projects — never a tool or technology; the
  same value in both fields is a sign this is miscategorized). **If the
  claim is about anvil itself** (its scripts, Skills, install flow, or
  design) — use `anvil`, not the name of whatever repo anvil happens to
  live in. Don't default to the current repo's name out of convenience.
- `--tags`
- `--origin` — what backs the claim, not who wrote the note (that's
  `--source`). `bin/note` auto-detects this for code-sourced claims (a git
  remote URL, or the repo root if no remote, or the plain working
  directory if not a git repo at all) — show me what it detected so I can
  override it, don't just silently accept it. For a non-code domain (a
  book, a webpage, a PDF), don't leave it to auto-detection — ask me, or
  pull it from what I actually referenced in this conversation.
- the full body text, as you intend to write it (under ~400 words, the
  claim and why, no transcript dump)

For an amendment, show me exactly what's changing in the existing file —
not the whole file again if most of it is unchanged.

If what I described is really two or more distinct claims, draft separate
notes (or a mix of amendments and new notes) and show me all of them —
don't merge them into one.

**Then ask me to decide using the `AskUserQuestion` tool — do not just
print the draft and wait for a free-text reply.** Set that question's
`header` field to `Anvil Note`, whether this is a new note or an
amendment (fits the tool's 12-character header limit; do not try to fit
a longer description in there — say whether it's new or an amendment in
the question text itself instead). Ask one question with exactly two options:
- **Approve** — write/amend it exactly as shown
- **Reject** — don't write anything

Don't add a separate "request changes" option — the tool already offers
a free-text option on every question. If I use that to describe a
change instead of picking Approve or Reject, treat it as a revision
request: redraft and ask again with `AskUserQuestion`, still without
writing anything.

Only run `__ANVIL_HOME__/bin/note` (for a new note) or edit the existing
file directly (for an amendment) after I've picked Approve. An amendment
should never touch the note's `type`, `domain`, `project`, or `source`
fields — only its body and `updated:` date, unless I explicitly say
otherwise. **Always pass `--source claude` when calling `bin/note`** — its
default is `human`, which is wrong for anything this Skill writes; get it
right the first time instead of fixing it with a follow-up edit. **Also
pass `--origin` explicitly**, matching whatever was shown in the draft
(including any override I gave) — don't just let `bin/note` re-detect it
silently at write time, since that could differ from what was actually
shown and approved.

**When amending, read the file with `Read` before editing it, and never
copy `Read`'s line-number prefix into an edit.** `Read`'s output numbers
each line for display only — that number is not part of the file's real
content. Copying it into `old_string`/`new_string` corrupts the file (a
heading silently becoming `2# Title` instead of `# Title` is exactly this
mistake, and it has actually happened — check the line you're editing
doesn't start with a stray digit before finishing an amendment).

**MOC linking is automatic and built into `bin/note` itself** — for a new
canonical note, the script links it into its domain's MOC file
(`__ANVIL_HOME__/moc/<Domain-Title>.md`, under a `## <Subdomain-Title>`
heading if the note has one, as an Obsidian wiki-link
`- [[<filename-without-.md>]]`) as part of writing the file. Don't do this
step yourself and don't ask "should this be linked?" — running `bin/note`
already does it, whether called from this Skill or from the command line
directly. An amendment doesn't need this step; the note is already linked.

**Report only the outcome, not the mechanics.** Once written, report it
as one `Anvil:` line — e.g. `Anvil: wrote new note at
anvil/semantic/2026-...-title.md (linked from moc/Software.md)` or
`Anvil: amended anvil/semantic/2026-...-title.md`. Use the path relative
to the vault root (`anvil/<type>/<file>.md`), not the full absolute path
— that's for your own tool calls to use internally, not for what you
report back.

**None of the individual mechanical steps get their own announcement —
they're all folded into that one final line.** Don't say "this creates
frontmatter only, the body needs a separate edit," or "now I'll create
the note, then fill in the body" — none of that. `bin/note` and the body
edit are two tool calls behind one user-facing action; do both silently
and report only the single combined result.
