#!/usr/bin/env bash
# VPSmaxxing — handoff: move a Claude Code session between the laptop and the VPS.
#
# Works because both machines expose projects at the SAME absolute path
# (see setup-handoff.sh + references/11-session-handoff.md): Claude keys sessions
# by the canonical cwd, so a synced transcript resumes natively on either side.
#
#   Run on the LAPTOP -> pushes the session up and launches it on the VPS in tmux.
#   Run on the VPS    -> pushes the session down and prints the laptop pickup cmd.
#
# Config (env or ~/.config/vpsmaxxing/handoff.env, written by setup-handoff.sh):
#   HANDOFF_PROJ_ROOT     shared absolute projects path, identical on both machines
#   HANDOFF_PEER_FROM_MAC ssh alias the laptop uses to reach the VPS   (default ai-vps)
#   HANDOFF_PEER_FROM_VPS ssh alias the VPS uses to reach the laptop   (default mac)
#   HANDOFF_LAUNCHER      command used to resume on the VPS            (default claudemaxxing)
set -uo pipefail

CFG="${HANDOFF_CONFIG:-$HOME/.config/vpsmaxxing/handoff.env}"
[ -f "$CFG" ] && . "$CFG"
PROJ_ROOT="${HANDOFF_PROJ_ROOT:?set HANDOFF_PROJ_ROOT (shared abs projects path) — run setup-handoff.sh}"
PEER_FROM_MAC="${HANDOFF_PEER_FROM_MAC:-ai-vps}"
PEER_FROM_VPS="${HANDOFF_PEER_FROM_VPS:-mac}"
LAUNCHER="${HANDOFF_LAUNCHER:-claudemaxxing}"
CLAUDE_PROJECTS="$HOME/.claude/projects"
FORCE=0; DRY=0

usage(){ cat <<EOF
handoff — hand a Claude session to the other machine

usage: handoff [project|path] [session-id] [-f] [-n]
  project      name under $PROJ_ROOT (default: current dir)
  session-id   specific session (default: most recent for the project)
  -f, --force  skip the "looks active" safety check
  -n, --dry-run  do everything except actually launch (prints the command)
EOF
}

args=()
for a in "$@"; do case "$a" in
  -f|--force) FORCE=1;; -n|--dry-run) DRY=1;; -h|--help) usage; exit 0;; *) args+=("$a");;
esac; done
set -- "${args[@]:-}"

# --- resolve the project's canonical abs path (identical on both machines) ---
sel="${1:-.}"
case "$sel" in
  ""|.) abs="$(pwd -P)" ;;
  /*)   abs="$sel" ;;
  */*)  abs="$(cd "$sel" 2>/dev/null && pwd -P)" ;;
  *)    abs="$PROJ_ROOT/$sel" ;;
esac
name="$(basename "$abs")"
if [ "${abs#$PROJ_ROOT/}" = "$abs" ]; then
  echo "x '$abs' is not under $PROJ_ROOT — handoff needs the project under the shared root" >&2
  echo "  so paths match on both machines. Move/clone it to $PROJ_ROOT/<name>." >&2
  exit 1
fi

enc="$(printf '%s' "$abs" | sed 's/[^a-zA-Z0-9]/-/g')"     # Claude's project-folder encoding
folder="$CLAUDE_PROJECTS/$enc"
[ -d "$folder" ] || { echo "x no Claude history for '$name' ($folder). Run claude there first." >&2; exit 1; }

# --- pick the session ---
id="${2:-}"
if [ -n "$id" ]; then
  f="$folder/$id.jsonl"; [ -f "$f" ] || { echo "x session $id not found in $folder" >&2; exit 1; }
else
  f="$(ls -t "$folder"/*.jsonl 2>/dev/null | head -1)"
  [ -n "$f" ] || { echo "x no sessions in $folder" >&2; exit 1; }
  id="$(basename "$f" .jsonl)"
fi

# --- safety: still being written? (mid-turn) ---
age="$(python3 -c 'import os,sys,time; print(int(time.time()-os.path.getmtime(sys.argv[1])))' "$f" 2>/dev/null || echo 999)"
if [ "$age" -lt 20 ] && [ "$FORCE" -ne 1 ]; then
  echo "! session $id was modified ${age}s ago — it may still be mid-turn. Stop it, or pass -f." >&2
  exit 1
fi

# --- direction ---
if [ "$(uname)" = "Darwin" ]; then TARGET="$PEER_FROM_MAC"; THERE="VPS"; else TARGET="$PEER_FROM_VPS"; THERE="laptop"; fi
echo "-> handing off '$name' (session ${id%%-*}...) to the $THERE"
echo "   path:   $abs"

# --- push the transcript ---
ssh -o ConnectTimeout=12 "$TARGET" "mkdir -p '.claude/projects/$enc'" 2>/dev/null
rsync -az -e 'ssh -o ConnectTimeout=12' "$folder/" "$TARGET:.claude/projects/$enc/" \
  && echo "   sync:   transcript -> $THERE  ok" || { echo "x transcript sync failed" >&2; exit 1; }

# --- make sure the repo is present on the target ---
if ssh -o ConnectTimeout=12 "$TARGET" "test -d '$abs'"; then
  echo "   repo:   already on the $THERE"
elif [ "$DRY" -eq 1 ]; then
  echo "   repo:   [dry-run] not on the $THERE — would clone from origin or rsync the tree"
else
  url="$(git -C "$abs" remote get-url origin 2>/dev/null || true)"
  if [ -n "$url" ]; then
    echo "   repo:   cloning on the $THERE from origin..."
    ssh "$TARGET" "mkdir -p '$PROJ_ROOT' && git clone --quiet '$url' '$abs'" \
      && echo "   repo:   cloned" || echo "   repo:   ! clone failed — sync the code manually"
  else
    echo "   repo:   no git origin; rsyncing working tree (heavy dirs excluded)..."
    rsync -az --exclude .git --exclude node_modules --exclude .venv --exclude venv \
          --exclude target --exclude __pycache__ --exclude '*.sqlite*' \
          "$abs/" "$TARGET:$abs/" && echo "   repo:   code synced" || echo "   repo:   ! code sync failed"
  fi
fi

# --- land it ---
if [ "$THERE" = "VPS" ]; then
  sess="ho-$(printf '%s' "$name" | tr -c 'a-zA-Z0-9_-' '-')"
  launch="L=$LAUNCHER; command -v \$L >/dev/null || L=claude; tmux new-session -d -s '$sess' -c '$abs' \"\$L --resume $id\""
  if ssh "$TARGET" "tmux has-session -t '$sess' 2>/dev/null"; then
    echo; echo "A hand-off session for '$name' is already live on the VPS (leaving it alone)."
    echo "  attach:  ssh $TARGET -t \"tmux attach -t $sess\""
  elif [ "$DRY" -eq 1 ]; then
    echo; echo "[dry-run] would run on VPS:  $launch"
  else
    ssh "$TARGET" "$launch"
    echo; echo "resumed on the VPS in tmux '$sess'."
    echo "  attach:  ssh $TARGET -t \"tmux attach -t $sess\"   (or a cmux tab running that)"
  fi
  echo "! this session is now LIVE on the VPS — don't resume it on the laptop until you handback."
else
  echo
  [ "$DRY" -eq 1 ] && echo "[dry-run] transcript is on the laptop."
  echo "synced to the laptop. Pick it up there with:"
  echo "     resume-here $name"
  echo "  or cd '$abs' && claude --resume $id"
  echo "! run it on the laptop now — don't keep the VPS copy going in parallel."
fi
