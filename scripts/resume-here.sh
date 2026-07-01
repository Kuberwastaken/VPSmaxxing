#!/usr/bin/env bash
# VPSmaxxing — resume-here: pull the latest synced transcript for a project from
# the other machine and resume it locally. The companion to handoff.
#
# Config (env or ~/.config/vpsmaxxing/handoff.env — see setup-handoff.sh):
#   HANDOFF_PROJ_ROOT     shared absolute projects path, identical on both machines
#   HANDOFF_PEER_FROM_MAC ssh alias the laptop uses to reach the VPS   (default ai-vps)
#   HANDOFF_PEER_FROM_VPS ssh alias the VPS uses to reach the laptop   (default mac)
set -uo pipefail

CFG="${HANDOFF_CONFIG:-$HOME/.config/vpsmaxxing/handoff.env}"
[ -f "$CFG" ] && . "$CFG"
PROJ_ROOT="${HANDOFF_PROJ_ROOT:?set HANDOFF_PROJ_ROOT — run setup-handoff.sh}"
PEER_FROM_MAC="${HANDOFF_PEER_FROM_MAC:-ai-vps}"
PEER_FROM_VPS="${HANDOFF_PEER_FROM_VPS:-mac}"
CLAUDE_PROJECTS="$HOME/.claude/projects"

case "${1:-}" in -h|--help)
  echo "usage: resume-here [project|path] [session-id]"
  echo "  Pulls the newest transcript for the project from the other machine, then resumes."
  exit 0;; esac

sel="${1:-.}"; id="${2:-}"
case "$sel" in ""|.) abs="$(pwd -P)";; /*) abs="$sel";; *) abs="$PROJ_ROOT/$sel";; esac
enc="$(printf '%s' "$abs" | sed 's/[^a-zA-Z0-9]/-/g')"
folder="$CLAUDE_PROJECTS/$enc"

if [ "$(uname)" = "Darwin" ]; then OTHER="$PEER_FROM_MAC"; RUN="claude"; else OTHER="$PEER_FROM_VPS"; RUN="claudemaxxing"; fi
command -v "$RUN" >/dev/null 2>&1 || RUN="claude"

mkdir -p "$folder"
rsync -azu -e 'ssh -o ConnectTimeout=10' "$OTHER:.claude/projects/$enc/" "$folder/" 2>/dev/null || true

[ -d "$abs" ] || { echo "x '$abs' doesn't exist here — clone/sync the repo first." >&2; exit 1; }
cd "$abs" || exit 1
if [ -n "$id" ]; then exec "$RUN" --resume "$id"; else exec "$RUN" --continue; fi
