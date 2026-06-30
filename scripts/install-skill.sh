#!/usr/bin/env bash
# VPSmaxxing — install this repo as a Claude Code skill (~/.claude/skills/vpsmaxxing).
# Default = COPY (sync-friendly: rides agent-sync to your VPS). Pass --link to symlink.
# Run from anywhere:  bash scripts/install-skill.sh   [--link]
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"     # repo root (contains SKILL.md)
DEST="$HOME/.claude/skills/vpsmaxxing"
[ -f "$SRC/SKILL.md" ] || { echo "SKILL.md not found in $SRC"; exit 1; }
mkdir -p "$HOME/.claude/skills"
if [ "${1:-}" = "--link" ]; then
  ln -sfn "$SRC" "$DEST"; echo "✅ Linked $DEST -> $SRC"
else
  mkdir -p "$DEST"
  rsync -a --delete --exclude '.git' --exclude '.gitignore' "$SRC"/ "$DEST"/
  echo "✅ Copied skill to $DEST  (re-run after updating the repo)"
fi
echo
echo "In Claude Code the 'vpsmaxxing' skill is now available."
echo "Try:  /vpsmaxxing   — or just say: \"set up a VPS for my AI agents\""
echo "(Codex users: copy SKILL.md into ~/.codex/skills/, or point Codex at it.)"
