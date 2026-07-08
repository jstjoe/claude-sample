#!/usr/bin/env bash
# Symlink every skill in ./skills into ~/.claude/skills so they go live for the
# local Claude Code install, and expose any executable skill scripts as commands
# on your PATH. Idempotent: re-running refreshes the links.
#
# Usage: ./install.sh            # links skills + commands into ~/.local/bin
#        BIN=/usr/local/bin ./install.sh   # choose a different command dir
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
DEST="$HOME/.claude/skills"
BIN="${BIN:-$HOME/.local/bin}"        # where skill commands (e.g. record-demo) land

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

# Expose executable skill scripts as commands on PATH. A skill can ship a runnable
# tool (e.g. demo-media/record-demo.sh); we symlink it to BIN as its name minus .sh.
# *.example.sh are templates, not commands — skipped.
mkdir -p "$BIN"
cmds=0
for f in "$SKILLS_SRC"/*/*.sh; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  case "$f" in *.example.sh) continue;; esac
  cmd="$(basename "$f" .sh)"
  link="$BIN/$cmd"
  if [ -L "$link" ] || [ ! -e "$link" ]; then
    ln -sf "$f" "$link"
    echo "linked command $cmd -> $f"
    cmds=$((cmds + 1))
  else
    echo "SKIP command $cmd: a real file already exists at $link — remove it first."
  fi
done
echo "Linked $cmds command(s) into $BIN."

# Nudge if BIN isn't on PATH, so the commands are actually runnable.
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "NOTE: $BIN is not on your PATH. Add it, e.g.:"
     echo "        echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.zshrc && exec zsh" ;;
esac
