#!/usr/bin/env bash
# Anvil vault installer.
# Creates (or upgrades) the anvil knowledge vault used by Claude Code / Grok Build.
# Safe to re-run: user content (notes, index, MOC files) is created once and never
# overwritten; package-managed files (bin/, NOTE_TEMPLATE.md) are refreshed every run.
#
# Interactive by default, asking up to five questions in order:
#   1. Single machine, or shared across more than one?
#   2. New vault, or point at an existing one?
#   3. What path?
#   4. (only if domains.txt doesn't exist yet) What domains to start with?
#   5. Where is Claude Code's skills directory (for /recall, /note, /reflect, /anvil, /hydrate, /fill-vault)?
# Flags below let you skip any/all of these prompts for scripted or repeat installs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ANVIL_HOME="$HOME/.anvil"
DEFAULT_DOMAINS="software, finance, trading, business, health"
DEFAULT_CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

ANVIL_HOME="${ANVIL_HOME:-}"
MODE="${ANVIL_MODE:-}"                 # single | multi
VAULT_ACTION="${ANVIL_VAULT_ACTION:-}" # new | existing
DOMAINS_INPUT="${ANVIL_DOMAINS:-}"     # comma-separated, only used if domains.txt is missing
CLAUDE_SKILLS_DIR="${ANVIL_CLAUDE_SKILLS_DIR:-}"
SKIP_CLAUDE_SKILLS=false
ADD_TO_PATH="${ANVIL_ADD_TO_PATH:-}"   # true | false, whether to wire the anvil CLI into shell rc files
NONINTERACTIVE=false

usage() {
  cat <<EOF
Usage: install.sh [--single-machine|--multi-machine] [--new-vault|--existing-vault] [--path <dir>] [--domains "a,b,c"] [--claude-skills-dir <dir>|--skip-claude-skills] [--add-to-path|--skip-add-to-path] [--non-interactive]

With no flags, this asks up to six questions, in order:
  1. Single machine, or shared across more than one machine?
  2. Create a new vault, or point at one that already exists?
  3. What path should it live at (or already lives at)?
     (default: $DEFAULT_ANVIL_HOME)
  4. Only if domains.txt doesn't already exist at that path: what domains
     should this vault start with? (default: $DEFAULT_DOMAINS)
  5. Only if ~/.claude doesn't exist (i.e. Claude Code isn't at the usual
     location): where is Claude Code's skills directory, so /recall, /note,
     and /reflect can be installed there as real Skills? Leave blank to
     skip. If ~/.claude does exist, this is skipped automatically and
     ~/.claude/skills is used with no prompt.
  6. Add the \`anvil\` command to your PATH, via ~/.bashrc and/or ~/.zshrc?
     This lets you run \`anvil recall\`, \`anvil note\`, \`anvil status\`, and
     \`anvil init\` from anywhere, instead of the full bin/ path.

Flags skip the matching question, for scripted or repeat installs:
  --single-machine     skip question 1, no Syncthing
  --multi-machine       skip question 1, install + configure Syncthing
  --new-vault            skip question 2, scaffold a fresh vault
  --existing-vault        skip question 2, point at one that's already there
  --path <dir>              skip question 3 (same as exporting ANVIL_HOME)
  --domains "a,b,c"           skip question 4 (same as exporting ANVIL_DOMAINS);
                               ignored if domains.txt already exists
  --claude-skills-dir <dir>     skip question 5, install skills to <dir>
  --skip-claude-skills            skip question 5, install no skills at all
  --add-to-path                     skip question 6, add anvil to PATH
  --skip-add-to-path                  skip question 6, don't touch shell rc files
  --non-interactive                     never prompt; unanswered questions fall
                                         back to single-machine, new-vault, the
                                         default path, the default domain list,
                                         installing skills only if
                                         $DEFAULT_CLAUDE_SKILLS_DIR already
                                         exists, and not touching shell rc files

Re-running this script upgrades all package-managed files (bin/*,
migrations/*, SCHEMA_VERSION, TOOLING_VERSION, NOTE_TEMPLATE.md,
CLAUDE_BLOCK.md) and the six Claude Code skills (if installed). It never
touches existing notes, index.md, domains.txt, moc/*.md content, or the
vault's own applied-schema marker — bumping that to match a
newly-installed SCHEMA_VERSION is bin/upgrade-vault's job, run separately,
never automatic. (For refreshing an existing vault's tooling later without
a full re-run of this script, see bin/upgrade instead — it reads this
script's location back out of .anvil-tooling-source.) It will not re-ask
questions you already answered via flags or environment variables (ANVIL_HOME,
ANVIL_MODE, ANVIL_VAULT_ACTION, ANVIL_DOMAINS, ANVIL_CLAUDE_SKILLS_DIR,
ANVIL_ADD_TO_PATH).

To add a domain later: edit domains.txt directly, then re-run this
installer — it generates any missing moc/<Domain>.md files from whatever is
actually in domains.txt, not from a fixed list.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path) ANVIL_HOME="$2"; shift 2 ;;
    --single-machine) MODE=single; shift ;;
    --multi-machine) MODE=multi; shift ;;
    --new-vault) VAULT_ACTION=new; shift ;;
    --existing-vault) VAULT_ACTION=existing; shift ;;
    --domains) DOMAINS_INPUT="$2"; shift 2 ;;
    --claude-skills-dir) CLAUDE_SKILLS_DIR="$2"; shift 2 ;;
    --skip-claude-skills) SKIP_CLAUDE_SKILLS=true; shift ;;
    --add-to-path) ADD_TO_PATH=true; shift ;;
    --skip-add-to-path) ADD_TO_PATH=false; shift ;;
    --non-interactive) NONINTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -t 0 ] && [ "$NONINTERACTIVE" = false ]; then
  INTERACTIVE=true
else
  INTERACTIVE=false
fi

# --- Question 1: single machine, or shared across more than one? ---
if [ -z "$MODE" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Is this vault used on more than one machine?

  1) Single machine — the vault lives only here. Nothing else to install.
  2) Multi machine  — shared with other machines on your LAN (e.g. a laptop
     and a Mac Mini). This installs Syncthing here and walks you through
     sharing the vault folder to your other machines.

EOF
    while true; do
      read -r -p "Choose [1/2]: " CHOICE
      case "$CHOICE" in
        1) MODE=single; break ;;
        2) MODE=multi; break ;;
        *) echo "Enter 1 or 2." ;;
      esac
    done
  else
    MODE=single
    echo "Non-interactive: defaulting to single-machine (no Syncthing). Pass --multi-machine to override."
  fi
fi

# --- Question 2: new vault, or point at an existing one? ---
if [ -z "$VAULT_ACTION" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Are you creating a new vault, or pointing this install at one that already exists
(e.g. one restored from a backup, or synced in from another machine before you
ran this installer)?

  1) New vault      — scaffold folders, index.md, and moc/ files from scratch.
  2) Existing vault  — use what's already at the path, only adding what's missing.

EOF
    while true; do
      read -r -p "Choose [1/2]: " CHOICE
      case "$CHOICE" in
        1) VAULT_ACTION=new; break ;;
        2) VAULT_ACTION=existing; break ;;
        *) echo "Enter 1 or 2." ;;
      esac
    done
  else
    VAULT_ACTION=new
    echo "Non-interactive: defaulting to new-vault. Pass --existing-vault to override."
  fi
fi

# --- Question 3: what path? ---
if [ -z "$ANVIL_HOME" ]; then
  if [ "$INTERACTIVE" = true ]; then
    if [ "$VAULT_ACTION" = "existing" ]; then
      read -r -p "Path to the existing vault [$DEFAULT_ANVIL_HOME]: " INPUT_PATH
    else
      read -r -p "Where should the new vault live? [$DEFAULT_ANVIL_HOME]: " INPUT_PATH
    fi
    ANVIL_HOME="${INPUT_PATH:-$DEFAULT_ANVIL_HOME}"
  else
    ANVIL_HOME="$DEFAULT_ANVIL_HOME"
    echo "Non-interactive: using default vault path $ANVIL_HOME"
  fi
fi

# --- Sanity-check the new/existing answer against reality; never fatal, only informational ---
VAULT_LOOKS_POPULATED=false
if [ -d "$ANVIL_HOME/semantic" ] || [ -d "$ANVIL_HOME/procedural" ] || [ -f "$ANVIL_HOME/index.md" ]; then
  VAULT_LOOKS_POPULATED=true
fi

if [ "$VAULT_ACTION" = "existing" ] && [ "$VAULT_LOOKS_POPULATED" = false ]; then
  echo
  echo "==> NOTE: you chose 'existing vault', but nothing recognizable was found"
  echo "    at $ANVIL_HOME. Proceeding to scaffold a fresh vault there instead."
fi

if [ "$VAULT_ACTION" = "new" ] && [ "$VAULT_LOOKS_POPULATED" = true ]; then
  echo
  echo "==> NOTE: you chose 'new vault', but $ANVIL_HOME already has vault content."
  echo "    Nothing will be overwritten — existing notes, index.md, and moc/*.md are left as-is."
fi

# --- Question 4: what domains to start with? Only asked if domains.txt      ---
# --- doesn't exist yet at this path — an existing one is never overwritten. ---
if [ ! -f "$ANVIL_HOME/domains.txt" ]; then
  if [ -z "$DOMAINS_INPUT" ]; then
    if [ "$INTERACTIVE" = true ]; then
      cat <<EOF

What domains should this vault start with? These should stay broad, few,
and stable — a mix of the life or work areas you actually want to
organize notes by. This becomes domains.txt; you can add more later by
editing that file directly (and re-running this installer to generate the
matching moc/ file), so don't worry about getting the list perfect now.

EOF
      read -r -p "Domains, comma-separated [$DEFAULT_DOMAINS]: " DOMAINS_INPUT
      DOMAINS_INPUT="${DOMAINS_INPUT:-$DEFAULT_DOMAINS}"
    else
      DOMAINS_INPUT="$DEFAULT_DOMAINS"
      echo "Non-interactive: seeding domains.txt with the default list ($DEFAULT_DOMAINS)."
    fi
  fi
fi

# --- Question 5: where is Claude Code's skills directory? ---
# The real signal that Claude Code is installed at the default location is
# ~/.claude existing at all — NOT ~/.claude/skills existing, since that
# subdirectory is only ever created once a first skill is installed into
# it. Checking the subdirectory would wrongly treat "no skills installed
# yet" as "Claude Code isn't here."
DEFAULT_CLAUDE_ROOT_DIR="$HOME/.claude"
if [ "$SKIP_CLAUDE_SKILLS" = false ] && [ -z "$CLAUDE_SKILLS_DIR" ]; then
  if [ -d "$DEFAULT_CLAUDE_ROOT_DIR" ]; then
    CLAUDE_SKILLS_DIR="$DEFAULT_CLAUDE_SKILLS_DIR"
  elif [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Install /recall, /note, /reflect, /anvil, /hydrate, and /fill-vault as real Claude Code
Skills? They call anvil's bin/recall and bin/note directly, so they
actually work as commands instead of relying on an agent noticing
CLAUDE.md on its own.

Claude Code's config directory wasn't found at the usual location:
  $DEFAULT_CLAUDE_ROOT_DIR

If Claude Code is installed somewhere else, enter its skills directory now
(example: $DEFAULT_CLAUDE_SKILLS_DIR — it doesn't need to exist yet, this
will create it). Leave blank to skip this step entirely; nothing else
about anvil depends on it.

EOF
    read -r -p "Claude Code skills directory (blank to skip): " CLAUDE_SKILLS_DIR
  else
    echo "Non-interactive: $DEFAULT_CLAUDE_ROOT_DIR not found, skipping Claude Code skill installation."
  fi
fi

# --- Question 6: add the anvil CLI to PATH via shell rc files? ---
if [ -z "$ADD_TO_PATH" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Add the 'anvil' command to your PATH? This adds a line to ~/.bashrc and/or
~/.zshrc (whichever exist) so you can run 'anvil recall', 'anvil note',
'anvil status', and 'anvil init' from any directory, in any new terminal —
instead of typing the full path to bin/ every time.

The change is clearly marked and easy to remove later (see uninstall.sh).

EOF
    while true; do
      read -r -p "Add anvil to PATH? [Y/n]: " CHOICE
      case "$CHOICE" in
        ""|y|Y|yes|Yes) ADD_TO_PATH=true; break ;;
        n|N|no|No) ADD_TO_PATH=false; break ;;
        *) echo "Enter y or n." ;;
      esac
    done
  else
    ADD_TO_PATH=false
    echo "Non-interactive: not modifying shell rc files. Pass --add-to-path to do so."
  fi
fi

echo
echo "==> Installing anvil vault at $ANVIL_HOME ($MODE-machine setup)"

# --- user content: created once, never overwritten ---
mkdir -p "$ANVIL_HOME"/{semantic,procedural,strategic,episodic,raw,_inbox,_review,_archive,moc,bin}

if [ ! -f "$ANVIL_HOME/index.md" ]; then
  cp "$SCRIPT_DIR/templates/index.md" "$ANVIL_HOME/index.md"
  echo "  created index.md"
fi

if [ ! -f "$ANVIL_HOME/domains.txt" ]; then
  IFS=',' read -ra RAW_DOMAINS <<< "$DOMAINS_INPUT"
  {
    echo "# Anvil domains — broad, stable life/work areas. One per line."
    echo "# Meant to stay few. If a note doesn't fit any of these, ask the user"
    echo "# before adding a new line here — use --subdomain for anything more"
    echo "# specific instead (a language, tool, project, or narrower topic)."
    echo "#"
    echo "# To add one: add a line below, then re-run install.sh — it creates"
    echo "# the matching moc/<Domain>.md automatically for anything new here."
    for d in "${RAW_DOMAINS[@]}"; do
      d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
      [ -z "$d" ] && continue
      echo "$d"
    done
  } > "$ANVIL_HOME/domains.txt"
  echo "  created domains.txt"
fi

# moc/ files are generated from whatever is actually in domains.txt right
# now — not from a fixed list — so adding a domain later and re-running this
# installer is enough to get its moc/ file created too.
if [ -f "$ANVIL_HOME/domains.txt" ]; then
  while IFS= read -r d || [ -n "$d" ]; do
    d="${d%%#*}"
    d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$d" ] && continue
    TITLE="$(echo "$d" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    dest="$ANVIL_HOME/moc/$TITLE.md"
    if [ ! -f "$dest" ]; then
      printf '# %s\n' "$TITLE" > "$dest"
      echo "  created moc/$TITLE.md"
    fi
  done < "$ANVIL_HOME/domains.txt"
fi

# --- package-managed files: always refreshed ---
cp "$SCRIPT_DIR/templates/NOTE_TEMPLATE.md" "$ANVIL_HOME/bin/NOTE_TEMPLATE.md"
cp "$SCRIPT_DIR/bin/recall" "$ANVIL_HOME/bin/recall"
cp "$SCRIPT_DIR/bin/note" "$ANVIL_HOME/bin/note"
cp "$SCRIPT_DIR/bin/status" "$ANVIL_HOME/bin/status"
cp "$SCRIPT_DIR/bin/anvil" "$ANVIL_HOME/bin/anvil"
cp "$SCRIPT_DIR/bin/sessions" "$ANVIL_HOME/bin/sessions"
cp "$SCRIPT_DIR/bin/session-read" "$ANVIL_HOME/bin/session-read"
cp "$SCRIPT_DIR/bin/usage" "$ANVIL_HOME/bin/usage"
cp "$SCRIPT_DIR/bin/upgrade-vault" "$ANVIL_HOME/bin/upgrade-vault"
cp "$SCRIPT_DIR/bin/upgrade" "$ANVIL_HOME/bin/upgrade"
cp "$SCRIPT_DIR/bin/audit" "$ANVIL_HOME/bin/audit"
chmod +x "$ANVIL_HOME/bin/recall" "$ANVIL_HOME/bin/note" "$ANVIL_HOME/bin/status" "$ANVIL_HOME/bin/anvil" \
  "$ANVIL_HOME/bin/sessions" "$ANVIL_HOME/bin/session-read" "$ANVIL_HOME/bin/usage" \
  "$ANVIL_HOME/bin/upgrade-vault" "$ANVIL_HOME/bin/upgrade" "$ANVIL_HOME/bin/audit"

# migrations/ is package-managed too — always refreshed, same as bin/.
mkdir -p "$ANVIL_HOME/migrations"
if [ -d "$SCRIPT_DIR/migrations" ]; then
  cp "$SCRIPT_DIR/migrations/"*.sh "$ANVIL_HOME/migrations/" 2>/dev/null || true
  chmod +x "$ANVIL_HOME/migrations/"*.sh 2>/dev/null || true
fi

# Two independent version axes, tracked separately (see bin/status and
# bin/upgrade-vault vs. bin/upgrade for why they're never conflated):
#
# SCHEMA_VERSION — the note frontmatter shape. Package-managed: always
# overwritten with what this install.sh ships. .anvil-applied-version is
# vault DATA, not a package file — only bin/upgrade-vault writes it,
# except once, right here, for a genuinely fresh vault (nothing to
# migrate, so it starts already caught up).
PREV_APPLIED_SCHEMA=""
[ -f "$ANVIL_HOME/.anvil-applied-version" ] && PREV_APPLIED_SCHEMA=$(tr -d '[:space:]' < "$ANVIL_HOME/.anvil-applied-version")
cp "$SCRIPT_DIR/SCHEMA_VERSION" "$ANVIL_HOME/SCHEMA_VERSION"
INSTALLED_SCHEMA=$(tr -d '[:space:]' < "$ANVIL_HOME/SCHEMA_VERSION")
if [ "$VAULT_LOOKS_POPULATED" = false ]; then
  printf '%s' "$INSTALLED_SCHEMA" > "$ANVIL_HOME/.anvil-applied-version"
fi

# TOOLING_VERSION — the anvil scripts/Skills themselves. Also
# package-managed and always overwritten; unlike schema, tooling
# deployment is a full atomic overwrite every run (no incremental
# migrations), so no separate "applied" marker is needed for it.
cp "$SCRIPT_DIR/TOOLING_VERSION" "$ANVIL_HOME/TOOLING_VERSION"
INSTALLED_TOOLING=$(tr -d '[:space:]' < "$ANVIL_HOME/TOOLING_VERSION")

# Records where this source repo lives, so a later `bin/upgrade` (tooling
# refresh) run — invoked straight from the deployed vault, with no cwd
# tying it back to this repo — knows where to pull fresh copies from.
# Machine-local, deliberately kept OUTSIDE $ANVIL_HOME so it never syncs
# via Syncthing — the source repo's clone location is specific to this
# machine, and syncing it would point other machines at a path that
# doesn't exist for them (same reasoning as usage.tsv/hydrated.tsv).
TOOLING_SOURCE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/anvil"
mkdir -p "$TOOLING_SOURCE_STATE_DIR" 2>/dev/null || true
echo "$SCRIPT_DIR" > "$TOOLING_SOURCE_STATE_DIR/tooling-source" 2>/dev/null || true

echo "Installing anvil (schema $INSTALLED_SCHEMA, tooling $INSTALLED_TOOLING)"

# CLAUDE_BLOCK.md is generated, not copied verbatim: the repo's master copy
# holds a __ANVIL_HOME__ placeholder in place of a real path, since the real
# path is only known once this installer asks. Extract just the fenced
# markdown block (not the surrounding "paste this" explanation) and substitute
# the real path in, so what lands in the vault is ready to paste as-is.
awk '/^```markdown$/{flag=1; next} /^```$/{flag=0} flag' "$SCRIPT_DIR/CLAUDE_BLOCK.md" \
  | sed "s|__ANVIL_HOME__|$ANVIL_HOME|g" \
  > "$ANVIL_HOME/CLAUDE_BLOCK.md"

echo "  refreshed bin/recall, bin/note, bin/status, bin/anvil, bin/sessions,"
echo "  bin/session-read, bin/usage, bin/upgrade-vault, bin/upgrade, bin/audit,"
echo "  migrations/, SCHEMA_VERSION, TOOLING_VERSION, bin/NOTE_TEMPLATE.md,"
echo "  CLAUDE_BLOCK.md"

if [ "$VAULT_LOOKS_POPULATED" = true ] && [ -n "$PREV_APPLIED_SCHEMA" ] && [ "$PREV_APPLIED_SCHEMA" != "$INSTALLED_SCHEMA" ]; then
  echo
  echo "==> installed schema is now $INSTALLED_SCHEMA; this vault's data is still"
  echo "    at $PREV_APPLIED_SCHEMA. Run bin/upgrade-vault when ready — it only adds"
  echo "    structure to existing notes, never guesses or rewrites real content."
fi

# Shell rc wiring: add $ANVIL_HOME/bin to PATH via ~/.bashrc and/or ~/.zshrc,
# whichever exist. Marked with distinct start/end comments so uninstall.sh
# can find and remove exactly this block, and so a re-run doesn't duplicate
# it (checked for by the start marker before appending).
ANVIL_PATH_MARKER_START="# >>> anvil PATH (managed by anvil/install.sh) >>>"
ANVIL_PATH_MARKER_END="# <<< anvil PATH <<<"
if [ "$ADD_TO_PATH" = true ]; then
  ANVIL_PATH_TOUCHED=""
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
      if grep -qF "$ANVIL_PATH_MARKER_START" "$RC" 2>/dev/null; then
        echo "  $RC already has the anvil PATH block, leaving it as-is"
      else
        {
          echo ""
          echo "$ANVIL_PATH_MARKER_START"
          echo "export PATH=\"$ANVIL_HOME/bin:\$PATH\""
          echo "$ANVIL_PATH_MARKER_END"
        } >> "$RC"
        ANVIL_PATH_TOUCHED="$ANVIL_PATH_TOUCHED $RC"
        echo "  added anvil to PATH in $RC"
      fi
    fi
  done
  if [ -z "$ANVIL_PATH_TOUCHED" ]; then
    echo "  WARNING: neither ~/.bashrc nor ~/.zshrc exist — nothing to add PATH to."
    echo "    Add this line to your shell's rc file manually:"
    echo "      export PATH=\"$ANVIL_HOME/bin:\$PATH\""
  fi
fi

# Claude Code Skills: generated the same way as CLAUDE_BLOCK.md — substitute
# the real vault path into each template, write into whatever skills
# directory was resolved above, one subdirectory per skill (the Skill's
# invocation name comes from its directory name, e.g. skills/recall/ becomes
# /recall). Skipped entirely if CLAUDE_SKILLS_DIR is empty.
if [ "$SKIP_CLAUDE_SKILLS" = false ] && [ -n "$CLAUDE_SKILLS_DIR" ]; then
  for skill in recall note reflect anvil hydrate fill-vault; do
    mkdir -p "$CLAUDE_SKILLS_DIR/$skill"
    sed "s|__ANVIL_HOME__|$ANVIL_HOME|g" "$SCRIPT_DIR/templates/skills/$skill/SKILL.md" > "$CLAUDE_SKILLS_DIR/$skill/SKILL.md"
  done
  echo "  installed /recall, /note, /reflect, /anvil, /hydrate, /fill-vault as Skills in $CLAUDE_SKILLS_DIR"
fi

if ! command -v rg >/dev/null 2>&1; then
  echo
  echo "==> ripgrep (rg) not found — the only hard dependency anvil has,"
  echo "    needed by bin/recall (bin/note works fine without it)."

  case "$(uname -s)" in
    Darwin) DETECTED_OS="macos" ;;
    Linux) DETECTED_OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) DETECTED_OS="windows" ;;
    *) DETECTED_OS="unknown" ;;
  esac

  RG_INSTALL_CMD=""
  case "$DETECTED_OS" in
    macos)
      command -v brew >/dev/null 2>&1 && RG_INSTALL_CMD="brew install ripgrep"
      ;;
    linux)
      if command -v brew >/dev/null 2>&1; then RG_INSTALL_CMD="brew install ripgrep"
      elif command -v apt-get >/dev/null 2>&1; then RG_INSTALL_CMD="sudo apt-get update && sudo apt-get install -y ripgrep"
      elif command -v dnf >/dev/null 2>&1; then RG_INSTALL_CMD="sudo dnf install -y ripgrep"
      elif command -v pacman >/dev/null 2>&1; then RG_INSTALL_CMD="sudo pacman -S --noconfirm ripgrep"
      elif command -v apk >/dev/null 2>&1; then RG_INSTALL_CMD="sudo apk add ripgrep"
      fi
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then RG_INSTALL_CMD="winget install BurntSushi.ripgrep.MSVC"
      elif command -v choco >/dev/null 2>&1; then RG_INSTALL_CMD="choco install ripgrep -y"
      elif command -v scoop >/dev/null 2>&1; then RG_INSTALL_CMD="scoop install ripgrep"
      fi
      ;;
  esac

  MANUAL_RG_MSG="  See https://github.com/BurntSushi/ripgrep#installation for every option (a plain binary download works everywhere, no package manager needed)."

  if [ -n "$RG_INSTALL_CMD" ]; then
    if [ "$INTERACTIVE" = true ]; then
      read -r -p "Install it now with: $RG_INSTALL_CMD ? [Y/n]: " RG_CONFIRM
      case "$RG_CONFIRM" in
        n|N|no|No)
          echo "  Skipped. recall won't work until ripgrep is installed — everything else will."
          echo "$MANUAL_RG_MSG"
          ;;
        *)
          eval "$RG_INSTALL_CMD"
          ;;
      esac
    else
      echo "  Non-interactive: installing via: $RG_INSTALL_CMD"
      eval "$RG_INSTALL_CMD"
    fi
  else
    echo "  No supported package manager found on PATH for auto-install ($DETECTED_OS)."
    echo "$MANUAL_RG_MSG"
    echo "  This is safe to skip for now — everything except recall will still work."
  fi
fi

if [ "$MODE" = "multi" ]; then
  echo
  echo "==> Multi-machine setup: configuring Syncthing on this machine"
  if command -v syncthing >/dev/null 2>&1; then
    echo "  Syncthing already installed."
  elif command -v brew >/dev/null 2>&1; then
    echo "  Installing Syncthing via Homebrew..."
    brew install syncthing
    brew services start syncthing
  else
    echo "  WARNING: Homebrew not found. Install Syncthing manually: https://syncthing.net/downloads/"
  fi
fi

echo
echo "==> Done. Vault root: $ANVIL_HOME"
echo "==> Add $ANVIL_HOME/bin to PATH, or call scripts by full path."
echo

# --- Final checklist: what's left, here and on any client machine ---
if [ "$MODE" = "single" ]; then
  cat <<EOF
==> Single-machine setup: no sync tool needed. Remaining steps are all local
    (see below). If you later add a second machine, re-run this installer
    there with --multi-machine and --existing-vault (pointing at the copy
    Syncthing lands there), then run this one again with --multi-machine too.
EOF
else
  cat <<EOF
==> The rest of this section is specific to multi-machine mode — syncing
    this vault to other machines with Syncthing. None of it applies to a
    single-machine setup, and none of it runs or configures anything by
    itself; it's steps for you to do by hand.

==> NOTICE, if this machine is headless (no display, e.g. run over SSH):
    http://localhost:8384 means THIS machine's own localhost — unreachable
    from a browser anywhere else, since Syncthing's GUI only listens for
    connections from itself. Reach it from another machine instead, with an
    SSH tunnel:

        ssh -L 8384:localhost:8384 $(whoami)@$(hostname)

    That target ($(whoami)@$(hostname)) is THIS machine — filled in
    automatically because that's what this installer is running on right
    now, not a fixed address to remember. If you're reading this notice
    from a different machine's install run later, it'll show that
    machine's own name instead — always run the command AS PRINTED, from
    whichever OTHER machine you want to view this GUI from, never from here.

    Leave it connected, then open http://localhost:8384 in a browser on
    that other machine — it now shows this machine's Syncthing GUI,
    tunneled over SSH. Use it for every GUI step below.

    IMPORTANT: everything typed after that ssh command runs on THIS machine,
    not the one you typed it from — check the shell prompt changed before
    running anything else in that window.

    If the OTHER machine already runs its own Syncthing, port 8384 there is
    already taken and that exact command will fail to bind. Forward to a
    different local port instead, and browse that port number:

        ssh -L 8385:localhost:8384 $(whoami)@$(hostname)
        # then open http://localhost:8385 on that other machine

    When finished, close that terminal (or press Ctrl+C in it) — the tunnel
    ends immediately. Nothing was installed by it and nothing keeps running.
    If you started it backgrounded (with -f), instead find and stop it:

        pgrep -f '8384:localhost:8384'    # or 8385, whichever port you used
        kill <pid printed above>

==> Remaining step on THIS machine (cannot be scripted — Syncthing pairing
    needs one click on each end):
    1. Open http://localhost:8384 (directly, or via the tunnel above).
    2. Add Folder -> label 'anvil' -> path '$ANVIL_HOME'.
    3. Go to Actions > Show ID, and copy this machine's device ID.

==> Steps on EACH CLIENT machine (e.g. your laptop):
    1. Install Syncthing there too:
         brew install syncthing && brew services start syncthing
       (or run this installer there with --multi-machine, which does the
       same install step for you)
    2. Open that machine's Syncthing UI (http://localhost:8384 — or via an
       SSH tunnel from yet another machine, same trick as above, if that
       client is also headless) and add THIS machine as a remote device,
       using the device ID from step 3 above.
    3. Accept the incoming 'anvil' folder share on the client, and set its
       local path — it does not have to match this machine's path, but
       $DEFAULT_ANVIL_HOME is the convention used in this repo's docs.
    4. Confirm both machines show the 'anvil' folder as "Up to Date", not
       "Out of Sync", before relying on it.
    5. Once Syncthing has landed the folder there, run this installer on
       that client machine too, choosing 'existing vault' and pointing it
       at that same path — this lays down bin/recall, bin/note, and the
       template there, without touching the notes Syncthing just delivered.
EOF
fi

cat <<EOF

==> Wire a project to use this vault (do this on whichever machine runs the
    agent for that project):
    1. Open $ANVIL_HOME/CLAUDE_BLOCK.md — already filled in with this
       vault's actual path, not a placeholder.
    2. Paste that block into the project's CLAUDE.md (or AGENTS.md for Grok
       Build). Do not paste vault content — only the pointer block.

    For convenience, here it is, ready to copy:

$(cat "$ANVIL_HOME/CLAUDE_BLOCK.md")

==> Test it, from the command line:
    1. Write a note:
         $ANVIL_HOME/bin/note --type semantic --domain software --project anvil --title "anvil installed on $(hostname)"
       This prints the file path it created.
    2. Search for it:
         $ANVIL_HOME/bin/recall "installed"
       You should see the note you just wrote printed back.
    3. If this is a multi-machine setup, confirm the same note shows up in
       $ANVIL_HOME on the other machine once Syncthing finishes syncing.
    4. Open $ANVIL_HOME as a vault in Obsidian, if you want to browse it
       visually — this is optional and has no effect on how agents use it.
EOF

if [ "$ADD_TO_PATH" = true ]; then
  cat <<EOF

==> The 'anvil' command was added to PATH — open a NEW terminal (or run
    'source ~/.bashrc' / 'source ~/.zshrc') before trying it, then:
        anvil status
        anvil recall "installed"
        anvil init                 # adds this vault's CLAUDE_BLOCK.md to
                                    # ./CLAUDE.md in whatever directory
                                    # you run it from (use --path <dir>
                                    # to target somewhere else, e.g. a
                                    # specific package in a monorepo)
EOF
fi

if [ "$SKIP_CLAUDE_SKILLS" = false ] && [ -n "$CLAUDE_SKILLS_DIR" ]; then
  cat <<EOF

==> Test the Skills you just installed, inside Claude Code:
    Skills are picked up next session, not the one you're running this
    installer from — open a NEW Claude Code session (any project) first.
    Then, in that new session, try:

        /recall installed

    This should print the note from step 2 above — same result as the CLI
    command, just triggered by the Skill instead of you running it by hand.
    Then try:

        /note quick smoke test of the anvil Skills

    and, at the end of a real work session:

        /reflect

    and, any time you want to see the vault's shape:

        /anvil

    See "Claude Code Skills" in $SCRIPT_DIR/README.md for exactly what
    each of these is supposed to do, with more examples.
EOF
fi
