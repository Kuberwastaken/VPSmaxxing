#!/usr/bin/env bash
# VPSmaxxing — two-way agent-state sync between the VPS and your laptop.
# Runs ON THE VPS (driven by cron). Two-way rsync, additive, newer-wins, no deletes.
#
# Install:
#   cp agent-sync.sh ~/.local/bin/agent-sync && chmod +x ~/.local/bin/agent-sync
#   # then add cron (Amazon Linux needs cronie):
#   sudo dnf install -y cronie && sudo systemctl enable --now crond     # AL2023
#   ( crontab -l 2>/dev/null | grep -v agent-sync; \
#     echo "*/5 * * * * $HOME/.local/bin/agent-sync >> $HOME/.agent-sync.log 2>&1" ) | crontab -
#
# Configure via env (or edit the defaults):
#   LAPTOP_ALIAS    ssh alias to the laptop (must be in ~/.ssh/config)         [mac]
#   LAPTOP_HOME_ENC laptop's encoded home dir for Claude memory, e.g. -Users-you  (REQUIRED)
#   VPS_HOME_ENC    this box's encoded home, auto-derived from $HOME
set -uo pipefail
exec 9>/tmp/agent-sync.lock; flock -n 9 || exit 0          # no overlapping runs
LAPTOP_ALIAS="${LAPTOP_ALIAS:-mac}"
VPS_HOME_ENC="${VPS_HOME_ENC:-$(printf '%s' "$HOME" | sed 's#/#-#g')}"
LAPTOP_HOME_ENC="${LAPTOP_HOME_ENC:-}"
log(){ echo "[$(date '+%F %T')] $*"; }

ssh -n -o ConnectTimeout=8 -o BatchMode=yes "$LAPTOP_ALIAS" true 2>/dev/null \
  || { log "laptop ($LAPTOP_ALIAS) unreachable — skip"; exit 0; }

sd(){ ssh -n "$LAPTOP_ALIAS" "mkdir -p \"$2\"" 2>/dev/null; mkdir -p "$1"
      rsync -azu --timeout=30 "$LAPTOP_ALIAS":"$2/" "$1/" 2>/dev/null
      rsync -azu --timeout=30 "$1/" "$LAPTOP_ALIAS":"$2/" 2>/dev/null; }
sf(){ rsync -azu --timeout=30 "$LAPTOP_ALIAS":"$2" "$1" 2>/dev/null
      rsync -azu --timeout=30 "$1" "$LAPTOP_ALIAS":"$2" 2>/dev/null; }

sd "$HOME/.claude/skills"   ".claude/skills"
sd "$HOME/.claude/projects" ".claude/projects"
sf "$HOME/.claude/history.jsonl" ".claude/history.jsonl"
if [ -n "$LAPTOP_HOME_ENC" ]; then
  sd "$HOME/.claude/projects/$VPS_HOME_ENC/memory" ".claude/projects/$LAPTOP_HOME_ENC/memory"
else
  log "WARN: LAPTOP_HOME_ENC unset — Claude memory path not mapped (set it to e.g. -Users-you)"
fi
sd "$HOME/.codex/skills"   ".codex/skills"
sd "$HOME/.codex/sessions" ".codex/sessions"
sf "$HOME/.codex/memories_1.sqlite"   ".codex/memories_1.sqlite"
sf "$HOME/.codex/session_index.jsonl" ".codex/session_index.jsonl"
log "sync complete"
