#!/usr/bin/env bash
# Anvil vault uninstaller.
# By default, removes only package-managed files (bin/ scripts, template) and
# leaves all notes and vault content in place. Pass --purge to delete everything,
# including notes — this is destructive and cannot be undone.
set -euo pipefail

ANVIL_HOME="${ANVIL_HOME:-$HOME/.anvil}"
CLAUDE_SKILLS_DIR="${ANVIL_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
PURGE=false
DELETE_FOLDER=false
DELETE_FOLDER_SET=false

ANVIL_PATH_MARKER_START="# >>> anvil PATH (managed by anvil/install.sh) >>>"
ANVIL_PATH_MARKER_END="# <<< anvil PATH <<<"

usage() {
  cat <<EOF
Usage: uninstall.sh [--path <dir>] [--purge] [--delete-folder|--keep-folder] [--claude-skills-dir <dir>]

Default: removes all package-managed files (bin/*, migrations/*,
SCHEMA_VERSION, TOOLING_VERSION, NOTE_TEMPLATE.md, CLAUDE_BLOCK.md), all
six Skills — recall/note/reflect/anvil/hydrate/fill-vault (from
--claude-skills-dir, default $HOME/.claude/skills), and the anvil PATH
block from ~/.bashrc and/or ~/.zshrc (if install.sh added one — only that
clearly-marked block is removed, nothing else in those files). Notes,
index.md, domains.txt, moc/, and the vault's applied-schema marker are
kept — those are your content and vault state, not package files.

--purge: deletes all vault content — notes, index.md, domains.txt, moc/,
bin/. Irreversible. If neither --delete-folder nor --keep-folder is given,
this asks interactively whether to also remove the anvil/ folder itself
(e.g. the folder Obsidian has open as a vault, or Syncthing is watching) or
just empty it and leave the folder in place.

--delete-folder: skip that question, remove the folder entirely.
--keep-folder: skip that question, empty contents but keep the folder (and
its .stfolder marker, if present) in place.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path) ANVIL_HOME="$2"; shift 2 ;;
    --purge) PURGE=true; shift ;;
    --delete-folder) DELETE_FOLDER=true; DELETE_FOLDER_SET=true; shift ;;
    --keep-folder) DELETE_FOLDER=false; DELETE_FOLDER_SET=true; shift ;;
    --claude-skills-dir) CLAUDE_SKILLS_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

remove_anvil_path_block() {
  RC="$1"
  if [ -f "$RC" ] && grep -qF "$ANVIL_PATH_MARKER_START" "$RC" 2>/dev/null; then
    TMP_RC="$(mktemp)"
    awk -v start="$ANVIL_PATH_MARKER_START" -v end="$ANVIL_PATH_MARKER_END" '
      $0 == start {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "$RC" > "$TMP_RC"
    mv "$TMP_RC" "$RC"
    echo "  removed anvil PATH block from $RC"
  fi
}

if [ ! -d "$ANVIL_HOME" ]; then
  echo "Nothing to do: $ANVIL_HOME does not exist."
  exit 0
fi

if [ "$PURGE" = true ]; then
  read -r -p "This deletes ALL notes in $ANVIL_HOME. Type the vault path to confirm: " CONFIRM
  if [ "$CONFIRM" != "$ANVIL_HOME" ]; then
    echo "Confirmation did not match. Aborted."
    exit 1
  fi

  if [ "$DELETE_FOLDER_SET" = false ]; then
    if [ -t 0 ]; then
      cat <<EOF

Also delete the anvil/ folder itself — e.g. the folder Obsidian has open as
a vault, or that Syncthing is watching — or just empty its contents and
leave the folder in place?

  1) Keep the folder — empty its contents, leave the directory (and any
     .stfolder marker) in place. Safer if Obsidian or Syncthing still
     reference this exact path.
  2) Delete the folder — remove the directory entirely.

EOF
      while true; do
        read -r -p "Choose [1/2]: " CHOICE
        case "$CHOICE" in
          1) DELETE_FOLDER=false; break ;;
          2) DELETE_FOLDER=true; break ;;
          *) echo "Enter 1 or 2." ;;
        esac
      done
    else
      echo "Non-interactive, no --delete-folder/--keep-folder given: keeping the folder itself."
      DELETE_FOLDER=false
    fi
  fi

  if [ "$DELETE_FOLDER" = true ]; then
    rm -rf "$ANVIL_HOME"
    echo "==> Removed $ANVIL_HOME entirely, including the folder itself."
  else
    find "$ANVIL_HOME" -mindepth 1 -maxdepth 1 ! -name '.stfolder' -exec rm -rf {} +
    echo "==> Emptied $ANVIL_HOME. The folder itself (and .stfolder, if it"
    echo "    was present) were kept, so Obsidian/Syncthing don't lose the path."
  fi

  remove_anvil_path_block "$HOME/.bashrc"
  remove_anvil_path_block "$HOME/.zshrc"
else
  rm -f "$ANVIL_HOME/bin/recall" "$ANVIL_HOME/bin/note" "$ANVIL_HOME/bin/status" "$ANVIL_HOME/bin/anvil" \
    "$ANVIL_HOME/bin/sessions" "$ANVIL_HOME/bin/session-read" "$ANVIL_HOME/bin/usage" \
    "$ANVIL_HOME/bin/upgrade-vault" "$ANVIL_HOME/bin/upgrade" "$ANVIL_HOME/bin/audit" \
    "$ANVIL_HOME/bin/NOTE_TEMPLATE.md" "$ANVIL_HOME/CLAUDE_BLOCK.md" \
    "$ANVIL_HOME/SCHEMA_VERSION" "$ANVIL_HOME/TOOLING_VERSION"
  rm -rf "$ANVIL_HOME/migrations"
  echo "==> Removed package-managed scripts. Notes left in place at $ANVIL_HOME."

  remove_anvil_path_block "$HOME/.bashrc"
  remove_anvil_path_block "$HOME/.zshrc"

  REMOVED_SKILLS=false
  for skill in recall note reflect anvil hydrate fill-vault; do
    if [ -d "$CLAUDE_SKILLS_DIR/$skill" ]; then
      rm -rf "$CLAUDE_SKILLS_DIR/$skill"
      REMOVED_SKILLS=true
    fi
  done
  if [ "$REMOVED_SKILLS" = true ]; then
    echo "==> Removed the recall/note/reflect/anvil/hydrate/fill-vault Skills from $CLAUDE_SKILLS_DIR."
  fi

  echo "==> Run with --purge to delete the whole vault instead."
fi
