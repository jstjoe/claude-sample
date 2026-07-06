#!/usr/bin/env bash
# Symlink every skill in ./skills into ~/.claude/skills so they go live for
# the local Claude Code install. Idempotent: re-running refreshes the links.
#
# Usage: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
DEST="$HOME/.claude/skills"

mkdir -p "$DEST"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "No skills/ directory in $REPO_DIR — nothing to install."
  exit 0
fi

linked=0
for dir in "$SKILLS_SRC"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link="$DEST/$name"
  target="${dir%/}"

  if [ -L "$link" ]; then
    rm "$link"                       # replace an existing symlink
  elif [ -e "$link" ]; then
    echo "SKIP $name: a real file/dir already exists at $link — remove it first."
    continue
  fi

  ln -s "$target" "$link"
  echo "linked $name -> $target"
  linked=$((linked + 1))
done

echo "Done. $linked skill(s) linked into $DEST."
