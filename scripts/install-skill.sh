#!/usr/bin/env bash
# VPSmaxxing — install this repo as a Claude Code skill (symlink into ~/.claude/skills).
# Run from anywhere:  bash scripts/install-skill.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"     # repo root (contains SKILL.md)
DEST="$HOME/.claude/skills/vpsmaxxing"
[ -f "$SRC/SKILL.md" ] || { echo "SKILL.md not found in $SRC"; exit 1; }
mkdir -p "$HOME/.claude/skills"
if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "$DEST exists and is not a symlink — move/remove it first."; exit 1
fi
ln -sfn "$SRC" "$DEST"
echo "✅ Linked $DEST -> $SRC"
echo
echo "In Claude Code the 'vpsmaxxing' skill is now available."
echo "Try:  /vpsmaxxing   — or just say: \"set up a VPS for my AI agents\""
echo "(Codex users: point Codex at $SRC/SKILL.md, or copy it into ~/.codex/skills/.)"
