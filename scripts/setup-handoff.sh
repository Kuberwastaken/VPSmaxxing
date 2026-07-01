#!/usr/bin/env bash
# VPSmaxxing — set up cross-machine session hand-off (symmetric paths + helpers).
# Run ON THE VPS, from the scripts/ dir (needs handoff.sh + resume-here.sh alongside).
#
# The trick: make the VPS expose your projects at the SAME absolute path your laptop
# uses (e.g. /Users/alice/Projects). Claude keys sessions by the canonical cwd, so a
# synced transcript then resumes natively on either machine — no path rewriting.
# Full rationale: references/11-session-handoff.md.
#
# Required:
#   MAC_HOME           your laptop's home path, e.g. /Users/alice   (the VPS will
#                      recreate this path as a REAL dir so encodings match)
# Optional:
#   PROJECTS_SUBDIR    projects folder under home        (default: Projects)
#   VPS_WORK           existing VPS project dir to fold in (default: ~/work)
#   PEER_FROM_MAC      ssh alias laptop->VPS             (default: ai-vps)
#   PEER_FROM_VPS      ssh alias VPS->laptop             (default: mac; needs reference 08)
#   HANDOFF_LAUNCHER   resume command on the VPS         (default: claudemaxxing)
set -uo pipefail
MAC_HOME="${MAC_HOME:?set MAC_HOME to your laptop home path, e.g. MAC_HOME=/Users/alice}"
PROJECTS_SUBDIR="${PROJECTS_SUBDIR:-Projects}"
PROJ_ROOT="$MAC_HOME/$PROJECTS_SUBDIR"
VPS_WORK="${VPS_WORK:-$HOME/work}"
PEER_FROM_MAC="${PEER_FROM_MAC:-ai-vps}"
PEER_FROM_VPS="${PEER_FROM_VPS:-mac}"
LAUNCHER="${HANDOFF_LAUNCHER:-claudemaxxing}"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> shared project root: $PROJ_ROOT"

# 1) symmetric project root: REAL dir at $PROJ_ROOT, ~/work -> symlink to it.
#    A same-filesystem `mv` is an inode-preserving rename — running agents keep
#    their open transcripts and inode-tracked cwd, so this doesn't disturb them.
if [ -L "$VPS_WORK" ]; then
  echo "    ~/work already a symlink -> $(readlink "$VPS_WORK"); leaving as-is"
elif [ -e "$PROJ_ROOT" ]; then
  echo "    ! $PROJ_ROOT already exists; not moving $VPS_WORK. Merge manually, then:"
  echo "        ln -s '$PROJ_ROOT' '$VPS_WORK'"
else
  sudo mkdir -p "$MAC_HOME"
  sudo chown "$(id -un):$(id -gn)" "$MAC_HOME"
  if [ -d "$VPS_WORK" ] && [ ! -L "$VPS_WORK" ]; then mv "$VPS_WORK" "$PROJ_ROOT"; else mkdir -p "$PROJ_ROOT"; fi
  ln -s "$PROJ_ROOT" "$VPS_WORK"
  echo "    moved $VPS_WORK -> $PROJ_ROOT and symlinked back"
fi
echo "    check: ( cd '$VPS_WORK' && pwd -P ) == $(cd "$VPS_WORK" 2>/dev/null && pwd -P || echo '?')"

# 2) claudemaxxing must pre-trust the CANONICAL cwd (pwd -P), not logical $PWD,
#    or the trust entry won't match Claude's project key after the symlink.
if [ -f ~/.local/bin/claudemaxxing ] && grep -q 'python3 - "\$PWD"' ~/.local/bin/claudemaxxing; then
  sed -i 's|python3 - "\$PWD"|python3 - "\$(pwd -P)"|' ~/.local/bin/claudemaxxing
  echo "==> patched claudemaxxing to pre-trust pwd -P"
fi

# 3) write config + install the helpers on the VPS
write_cfg(){ cat <<EOF
HANDOFF_PROJ_ROOT="$PROJ_ROOT"
HANDOFF_PEER_FROM_MAC="$PEER_FROM_MAC"
HANDOFF_PEER_FROM_VPS="$PEER_FROM_VPS"
HANDOFF_LAUNCHER="$LAUNCHER"
EOF
}
mkdir -p ~/.config/vpsmaxxing; write_cfg > ~/.config/vpsmaxxing/handoff.env
install -m 0755 "$DIR/handoff.sh" ~/.local/bin/handoff
install -m 0755 "$DIR/resume-here.sh" ~/.local/bin/resume-here
echo "==> installed handoff + resume-here + config on the VPS"

# 4) install on the laptop too, over the reverse ssh (reference 08). Falls back to
#    printing manual steps if the VPS can't reach the laptop.
if ssh -n -o ConnectTimeout=8 -o BatchMode=yes "$PEER_FROM_VPS" true 2>/dev/null; then
  ssh "$PEER_FROM_VPS" "mkdir -p ~/.local/bin ~/.config/vpsmaxxing"
  cat "$DIR/handoff.sh"     | ssh "$PEER_FROM_VPS" 'cat > ~/.local/bin/handoff && chmod +x ~/.local/bin/handoff'
  cat "$DIR/resume-here.sh" | ssh "$PEER_FROM_VPS" 'cat > ~/.local/bin/resume-here && chmod +x ~/.local/bin/resume-here'
  write_cfg                 | ssh "$PEER_FROM_VPS" 'cat > ~/.config/vpsmaxxing/handoff.env'
  echo "==> installed handoff + resume-here + config on the laptop ($PEER_FROM_VPS)"
else
  echo "==> laptop not reachable over '$PEER_FROM_VPS'. On the laptop, install manually:"
  echo "      mkdir -p ~/.local/bin ~/.config/vpsmaxxing"
  echo "      # copy scripts/handoff.sh -> ~/.local/bin/handoff and resume-here.sh -> ~/.local/bin/resume-here (chmod +x)"
  echo "      cat > ~/.config/vpsmaxxing/handoff.env <<CFG"; write_cfg | sed 's/^/      /'; echo "      CFG"
fi

echo
echo "Done. On the laptop:  handoff <project>   ->  resumes on the VPS in tmux ho-<project>"
echo "      On the VPS:     handoff <project>   ->  syncs down + prints the laptop pickup cmd"
echo "      Either side:    resume-here <project>"
echo "Remember: keep your repos under $PROJ_ROOT on BOTH machines, matching folder names."
