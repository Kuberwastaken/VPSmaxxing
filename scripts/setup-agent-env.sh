#!/usr/bin/env bash
# VPSmaxxing — configure the self-aware agent environment on the VPS.
# Writes: hostname, MOTD, ~/.tmux.conf, the `agent`/`agents` launchers,
# `claudemaxxing`/`codexmaxxing`, and ~/.claude/CLAUDE.md + ~/.codex/AGENTS.md.
# Run ON the VPS:  bash setup-agent-env.sh
# Model IDs in the maxxing launchers default to the examples below; override via
# env (CLAUDE_MODEL / CODEX_MODEL / *_EFFORT / CODEX_TIER) or edit the files after.
set -uo pipefail
HOSTN="${VPS_HOSTNAME:-ai-vps}"
. /etc/os-release 2>/dev/null
OSP="${PRETTY_NAME:-Linux}"; CPUS=$(nproc); MEM=$(free -h 2>/dev/null | awk '/Mem/{print $2}'); ARCH=$(uname -m)
mkdir -p ~/work ~/.local/bin ~/.claude ~/.codex

sudo hostnamectl set-hostname "$HOSTN" 2>/dev/null || true
grep -q "$HOSTN" /etc/hosts 2>/dev/null || echo "127.0.0.1 $HOSTN" | sudo tee -a /etc/hosts >/dev/null
grep -q '.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
grep -q 'npm-global/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc

# ---- MOTD (specs substituted) ----
sudo tee /etc/motd >/dev/null <<EOF

======================================================================
  $HOSTN  ::  DEDICATED AI SESSION HOST
======================================================================
  This machine exists ONLY to run AI coding agents (Claude Code / Codex).
  $OSP | $CPUS vCPU | $MEM | $ARCH

  agent <name> [claude|codex]   spawn/attach a tmux agent session
  agents                        list active agent sessions
  ~/work/<name>                 per-project workspace
  Dev servers: bind a port (3000/5173/8000/8080); on your laptop:
     vps-tunnel <port>  ->  open http://localhost:<port>
======================================================================
EOF

# ---- ~/.tmux.conf ----
cat > ~/.tmux.conf <<'EOF'
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"
setw -g mode-keys vi
set -sg escape-time 10
setw -g allow-rename off
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "reloaded"
EOF

# ---- agent launcher ----
cat > ~/.local/bin/agent <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
name="${1:-}"; tool="${2:-claude}"
if [ -z "$name" ] || [ "$name" = "-h" ] || [ "$name" = "--help" ]; then
  echo "usage: agent <session-name> [claude|codex|shell] [workdir]"
  echo "active sessions:"; tmux ls 2>/dev/null | sed 's/^/  /' || echo "  (none)"; exit 0
fi
dir="${3:-$HOME/work/$name}"; mkdir -p "$dir"
tmux has-session -t "$name" 2>/dev/null && exec tmux attach -t "$name"
case "$tool" in claude) c=claude;; codex) c=codex;; shell|sh) c="${SHELL:-bash}";; *) c="$tool";; esac
tmux new-session -d -s "$name" -c "$dir"; tmux send-keys -t "$name" "$c" C-m
exec tmux attach -t "$name"
EOF
chmod +x ~/.local/bin/agent
printf '#!/usr/bin/env bash\ntmux ls 2>/dev/null || echo "no active agent sessions"\n' > ~/.local/bin/agents
chmod +x ~/.local/bin/agents

# ---- maxxing launchers (self-defaulting model IDs; override via env) ----
cat > ~/.local/bin/claudemaxxing <<'EOF'
#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
MODEL="${CLAUDE_MODEL:-claude-opus-4-8[1m]}"   # <-- verify latest model ID
EFFORT="${CLAUDE_EFFORT:-xhigh}"
python3 - "$PWD" <<'PY'
import json, os, sys
p = os.path.expanduser('~/.claude.json'); cwd = sys.argv[1]
try: d = json.load(open(p))
except Exception: d = {}
e = d.setdefault('projects', {}).setdefault(cwd, {})
if e.get('hasTrustDialogAccepted') is not True:
    e['hasTrustDialogAccepted'] = True
    fd = os.open(p+'.tmp', os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600)
    json.dump(d, os.fdopen(fd,'w'), indent=2); os.replace(p+'.tmp', p)
PY
exec claude --dangerously-skip-permissions --model "$MODEL" --effort "$EFFORT" "$@"
EOF
chmod +x ~/.local/bin/claudemaxxing

cat > ~/.local/bin/codexmaxxing <<'EOF'
#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
MODEL="${CODEX_MODEL:-gpt-5.5}"                 # <-- verify latest model ID
EFFORT="${CODEX_EFFORT:-xhigh}"
TIER="${CODEX_TIER:-priority}"
exec codex --model "$MODEL" -c model_reasoning_effort="$EFFORT" -c model_service_tier="$TIER" \
  --dangerously-bypass-approvals-and-sandbox "$@"
EOF
chmod +x ~/.local/bin/codexmaxxing

# ---- self-briefing (CLAUDE.md == AGENTS.md), specs substituted ----
cat > ~/.claude/CLAUDE.md <<EOF
# This machine: dedicated AI-session VPS ($HOSTN)

You are running on a remote VPS that exists **solely to run AI coding agents**
(Claude Code and Codex). Not a production server. A disposable, powerful workbench.

## Environment
- OS: $OSP (use the right package manager: dnf on Amazon Linux, apt on Ubuntu/Debian).
- Hardware: $CPUS vCPU, $MEM RAM, $ARCH. Hostname: $HOSTN.
- **Headless**: no GUI, no local browser. Never open a browser; test with curl/wget.

## Toolchain (installed — don't reinstall)
- Node + npm; **pnpm** (prefer it for JS/TS). Docker + \`docker compose\` (no sudo).
- git, gcc/make, jq, tmux. Global npm installs land in ~/.npm-global (no sudo).

## Where to work
- One project per dir under \`~/work/<project>\`. Sessions run in tmux; a human
  drives them from their laptop over SSH/Tailscale.
- Other agent sessions may run in parallel — avoid global destructive actions
  (no \`pkill node\`, no \`docker system prune -a\`) without checking.

## Exposing dev servers ("localhost testing")
- Bind dev servers to 127.0.0.1:PORT (or 0.0.0.0:PORT) and TELL the human the port.
  Prefer 3000, 5173, 8000, 8080. They reach it via an SSH tunnel at the same
  localhost:PORT (\`vps-tunnel <PORT>\`). Ports are NOT public by default.

## Companion laptop, session hand-off & recall
- You have a **companion laptop**. Skills, memory, and Claude+Codex transcripts
  auto-sync between it and this box every few minutes. If reverse access is set up,
  reach it with \`ssh mac\` (rsync/git work over it).
- **Move a session between machines** (when hand-off is configured — projects live at
  the same absolute path on both): \`handoff <project>\` sends THIS session to the
  other machine and resumes it there; \`resume-here <project>\` picks one up. Only hand
  off at a turn boundary, and never run the same session live on both at once.
- **Recall past work across both tools and machines**: if the \`reference\` MCP is
  registered, use its tools (recall / search_sessions) — Claude can see Codex history
  and vice versa. To browse this machine's own sessions: \`claude --resume\`, then
  Ctrl+A to widen the picker to all projects.
EOF
cp ~/.claude/CLAUDE.md ~/.codex/AGENTS.md

echo "==> environment configured. Verify:"
echo "    hostname=$(hostname); agent --help; ls ~/.local/bin"
echo "    edit model IDs in ~/.local/bin/claudemaxxing & codexmaxxing if needed."
