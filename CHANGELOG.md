# Changelog

Human-readable history of anvil. Not parsed by any script — schema
changes are driven by `migrations/*.sh` (run by `bin/upgrade-vault`),
tooling changes are just whatever's in this repo's `bin/`/`templates/`
(pulled in by `bin/upgrade`). This file is the "why," those are the
mechanism, the note files are ground truth.

Two independent version axes, each with its own history below — see
"Versioning and upgrades" in `README.md` for why they're kept separate.

## Schema (`SCHEMA_VERSION`, note frontmatter shape)

### 0.0.0_2

Added an `origin` frontmatter field to notes — what backs the claim (a git
repo for code, a book/webpage/PDF for anything else), distinct from
`source` (which tool or human wrote the note). `bin/note` auto-detects it
for code-sourced notes: prefers a git remote URL, falls back to the local
repo root, falls back to the plain working directory if not inside a git
repo at all. Always overridable with `--origin`.

Existing notes get an empty `origin:` field via this version's migration —
deliberately empty, not guessed, since there's no safe way to reconstruct
an old note's real origin after the fact. `bin/status`/`bin/audit` flag
notes still missing a real value; the `/fill-vault` Skill proposes values with
its reasoning shown, approval-gated same as every other anvil write.

### 0.0.0_1

Baseline note schema: `type`, `domain`, `subdomain`, `project`, `source`,
`status`, `updated`, `tags`.

## Tooling (`TOOLING_VERSION`, the anvil scripts and Skills themselves)

### 0.0.0_6

`install.sh` now works piped straight into bash with no local checkout —
`curl -fsSL https://raw.githubusercontent.com/OnyxDrift/anvil/main/install.sh | bash`.
It detects when it isn't running from an on-disk clone, fetches a
throwaway copy of the repo (`git clone`, or `curl`+`tar` if `git` isn't
on PATH) into a temp dir, re-runs itself from there, then deletes it.
Must be piped to `bash`, not generic `sh` — the script uses bash-only
array syntax that breaks under `dash`/POSIX-mode `sh`.

New `--remote-upgrades` flag (implied automatically for a piped install)
records the GitHub repo in `tooling-source` instead of a local clone
path, so the clone used for the initial install can be deleted right
after. `bin/upgrade` now understands that `git:<url>#<ref>` form: it
fetches a fresh temp copy from GitHub on every upgrade instead of
requiring the original clone to still exist on disk.

### 0.0.0_5

Fixed a real over-application bug in `CLAUDE_BLOCK.md`'s branding rule,
caught live in a separate project: "every message in this flow starts
with `Anvil:`" was ambiguous about what "this flow" meant, and an agent
in another repo applied it to an unrelated `.todo`/`.done` bookkeeping
task that never touched the anvil vault, just because the pointer block
happened to be present in that file. Reworded to explicitly scope the
rule to actual vault read/write actions (`/recall`/`/note`/`/reflect`/
`/hydrate`, or a plain-language request that results in calling
`anvil/bin/recall`/`anvil/bin/note`) — unrelated work in the same repo
follows whatever conventions apply to it elsewhere, not anvil's.

Also removed the "janitor maintains this list." filler line from every
generated `moc/*.md` file (pure boilerplate, no informational value) —
fixed at all four generation sites (`install.sh`, `bin/note`, `/note` and
`/reflect` Skill templates) and stripped from the live vault's existing
files.

### 0.0.0_4

Two fixes surfaced by real trading-monorepo usage, both formalizing
patterns validated in an actual session rather than invented in the
abstract:

- **`subdomain` may now be a topical sub-category, not just a literal
  tool/technology**, for a domain where notes usually aren't about
  software tooling at all (e.g. `trading`, `finance`) — `backtesting`,
  `portfolio-theory`, `performance-metrics` are valid subdomain values
  there, the same way `python`/`docker` are for `software`. Validated
  first: ten trading/quant mechanics notes used exactly this shape with
  no invented near-duplicates and no `project` confusion, before this got
  written down as an intentional rule. Updated everywhere the old
  tool-only definition was duplicated: `CLAUDE_BLOCK.md`,
  `NOTE_TEMPLATE.md`, `bin/note`'s own usage comment, `README.md`, and
  the `/note`/`/reflect`/`/hydrate` Skill templates.
- **The "stay silent about internal mechanics, `Anvil:`-prefix every
  message" discipline now applies to the natural-language fallback path
  in `CLAUDE_BLOCK.md` itself, not just inside the Skill files.** A real
  session triggered anvil's write flow through a plain natural-language
  request (no explicit `/note`/`/reflect` invocation), and since that
  discipline only lived inside the Skills, it leaked an internal detail
  ("this doesn't need a hydrated.tsv entry since it wasn't a /hydrate
  run") that a user has no reason to see. `CLAUDE_BLOCK.md` now carries
  the same rule directly, so it applies regardless of which path
  triggered the write.

This is also the first real-world use of `anvil init`'s stale-block-
refresh feature (added last version) to actually update a live
`CLAUDE.md` — used here to roll this exact change out to this repo's own
`## Anvil` section.

### 0.0.0_3

Two new `anvil` commands, both optional — nothing else here depends on
them: `anvil install-additional-packages` installs
[emeraldian](https://github.com/iamrohithrnair/emeraldian) (a TUI that
reads an Obsidian-format vault — the same plain markdown anvil already
writes, no conversion — and shows notes plus a force-directed graph, in
the terminal), via Homebrew if available, else prints manual `cargo`/
`curl | sh` instructions. `anvil open-vault [path]` opens a vault in it,
defaulting to this vault's root. Picked emeraldian over two other real
candidates (`clin-rs`, `obsitui`) after verifying all three actually
exist — `clin-rs` is heavier/more opinionated than a plain viewer needs
(encryption, canvas editing), `obsitui` has too little traction (12
stars, manual npm build only) to depend on.

### 0.0.0_2

`bin/sessions` (and `/hydrate`, which reads it) no longer only sees the
exact literal directory you're standing in. Claude Code and Grok Build key
session storage by the exact cwd a session was launched from, so a session
started at a monorepo's root and one started from a package inside it
were previously invisible to each other. `bin/sessions` now scans the
current directory and every subdirectory beneath it (not upward — run it
from whichever root you want to sweep), and the listing groups sessions
under a heading per source directory, current directory first. Matching
can't rely on the encoded folder name alone — `/` and a literal `-` both
encode to `-`, so a sibling directory named `<repo>-old` is
indistinguishable by name from a real subdirectory `old` (this false
positive was caught and fixed during testing); Claude Code sessions are
now confirmed against their own recorded `"cwd"` field, exact, no
guessing. Grok Build sessions still rely on name matching alone pending
real data to verify a similar field against. Renamed `/fill` → `/fill-vault` for
naming symmetry with `upgrade-vault`. Also fixed a real, session-long gap:
`uninstall.sh` had never been updated as new files/Skills were added, so
it was leaving most of anvil behind on uninstall.

`anvil init` no longer treats mere presence of a `## Anvil` section as
"done" — it now refreshes that section in place (bounded to exactly that
region, everything else in the file untouched) if the content is stale,
comparing against the current `CLAUDE_BLOCK.md` rather than just checking
the heading exists. Caught a real, live example: this repo's own
`CLAUDE.md` still pointed at the vault's pre-move path
(`~/Development/tools/anvil` instead of `~/.anvil`) and had been silently
"passing" every prior `anvil init` run. Fixed a `set -e`/`pipefail` bug
during testing — the same class of bug fixed earlier in `bin/status`'s
orphan check — where a `grep` finding no match inside a pipeline killed
the whole script instead of being treated as a normal empty result.

### 0.0.0_1

First version this axis is tracked at all — previously conflated with the
schema version under one `VERSION` file, which made "is the vault's data
current" and "is anvil itself current" impossible to tell apart. Split
into `SCHEMA_VERSION` + `TOOLING_VERSION`, with the old `bin/upgrade`
renamed to `bin/upgrade-vault` (schema migrations only) and a new
`bin/upgrade` added for pulling fresh tooling from the local source repo
(its path recorded at install time in a machine-local state file, kept
outside the vault folder so it never syncs via Syncthing) without a full
interactive re-install. `anvil -h` reorganized into subsections
(Notes / Vault health / Vault schema / Tooling / Project setup / Other)
to make the distinction visible there too.

Represents everything built in anvil's tooling up to this point: vault
structure (semantic/procedural/strategic/episodic), `bin/note`/
`bin/recall`/`bin/status`/`bin/anvil`/`bin/audit`, the `/recall`/`/note`/
`/reflect`/`/anvil`/`/hydrate`/`/fill-vault` Claude Code Skills,
`bin/sessions`/`bin/session-read` for mining past session history, and
the local usage tracker (`bin/usage`).
