Paste this block into the `CLAUDE.md` (or `AGENTS.md`, for Grok Build) of any
project that should use the anvil vault. Do not paste vault content itself —
only this pointer block.

```markdown
## Anvil

A shared markdown vault at `__ANVIL_HOME__`, used by Claude Code and Grok
Build as a common knowledge store. Full documentation lives in this vault's
own `README.md`.

- **Do not preload anvil into context.** Point at it; never paste vault
  content into `CLAUDE.md`.
- **Never read, `grep`, or otherwise inspect vault note files directly.**
  The only sanctioned way into the vault is `/recall` (or `anvil/bin/recall`
  as a fallback) — both filter to `status: canonical` and force a
  keyword-searched, not-fabricated answer. Reading vault files any other
  way skips that filter entirely: a `draft` or `disputed` note could get
  presented as settled fact, with no signal that it isn't.
- **Before researching a question we may already have solved:** run
  `/recall <topic>` (or `anvil/bin/recall <topic>`).
- **Before ending a session that produced a durable lesson or decision:**
  run `/note`. If `/note` isn't available and you must call
  `anvil/bin/note` directly, apply the same discipline by hand: draft the
  frontmatter and body, show it to the user, and wait for approval before
  running the command — never write straight to canonical without that
  step, on any path. **This applies just as much to a plain natural-language
  request** ("dig through this repo and tell me what's true about X") as to
  an explicit `/note` or `/reflect` invocation — the write discipline below
  isn't something only the Skills enforce.
- **This branding rule applies only to messages that are actually part of
  reading or writing the anvil vault** — a `/recall`/`/note`/`/reflect`/
  `/hydrate` invocation, or a plain-language request that results in
  running `anvil/bin/recall` or `anvil/bin/note`. It does **not** apply to
  unrelated work that merely resembles record-keeping (e.g. this project's
  own `.todo`/`.done` bookkeeping, a `git commit`, a README edit) just
  because this pointer block happens to be present in the same
  `CLAUDE.md` — those follow whatever conventions apply to them
  elsewhere, not anvil's.
- **Within that vault-specific scope: every message starts with `Anvil:`,
  and stays silent about mechanics.** Don't narrate internal steps ("now
  checking recall," "this doesn't need a hydrated.tsv entry since it
  wasn't a /hydrate run," "now I'll link the MOC") — report only the
  outcome. If a mechanical detail would only make sense to someone who
  already knows how anvil's internals work, it doesn't belong in what you
  show the user.
- **One claim per file.** Frontmatter is required on every note: `type`,
  `domain`, `subdomain`, `project`, `source`, `status`, `updated`, `tags`.
- **`domain` must match a line in `anvil/domains.txt`** — broad, few,
  stable (e.g. `software`, `finance`, `trading`). If none fit, ask the user
  before adding a new line to that file. Do not pick the closest existing
  one instead.
- **`subdomain` is normally a tool, technology, or language** (e.g.
  `python`, `syncthing`, `ssh`) — not one of your own projects; use
  `project` for that. **For a domain where notes usually aren't about
  software tooling at all** (e.g. `trading`, `finance`), `subdomain` may
  instead be a topical sub-category of that domain (e.g. `backtesting`,
  `portfolio-theory`, `performance-metrics`) — still never one of your own
  projects, and still worth checking `bin/status`'s existing tree first to
  reuse a category instead of inventing a near-synonym.
- **`project` names one of your own projects** (e.g. `anvil`, `citeforge`,
  `swing-stack`) — not a tool or technology; use `subdomain` for that. The
  same value in both fields on one note is a sign it's miscategorized.
- **`tags` are free-form keywords** for search (e.g. `[python, cli,
  docker]`) — add a few when they would help a future `/recall` find this
  note.
- OpenCode (future) writes only to `anvil/_inbox`, with `status: draft`.
- Do not use Claude's or Grok's built-in memory features as a second brain.
- If this repo is the product, keep `cwd` on the repo. Reference anvil by
  its absolute path.
```
