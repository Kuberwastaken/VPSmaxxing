# 03 — Make the box a self-aware AI-agent environment

This is what makes the VPS feel purpose-built: a hostname, a banner, a good tmux
config, a one-command agent launcher, and — most importantly — `CLAUDE.md` /
`AGENTS.md` files that tell **every agent** it's running on a dedicated, headless
AI box and how to behave (use the right package manager, expose ports via tunnels,
don't do global-destructive things).

## 1. Hostname + banner

```bash
sudo hostnamectl set-hostname ai-vps
grep -q ai-vps /etc/hosts || echo "127.0.0.1 ai-vps" | sudo tee -a /etc/hosts

# /etc/motd — shown on every login (humans AND agents see it)
sudo tee /etc/motd >/dev/null <<'EOF'

======================================================================
  ai-vps  ::  DEDICATED AI SESSION HOST
======================================================================
  This machine exists ONLY to run AI coding agents (Claude Code / Codex).
  <OS> | <vCPU> vCPU | <RAM> | <arch> | <region>

  agent <name> [claude|codex]   spawn/attach a tmux agent session
  agents                        list active agent sessions
  ~/work/<name>                 per-project workspace

  Dev servers: bind a port (3000/5173/8000/8080); on your laptop run
     vps-tunnel <port>   ->   open http://localhost:<port>
======================================================================
EOF
```
Fill `<OS>`, `<vCPU>`, `<RAM>`, `<arch>`, `<region>` from the detection step.

## 2. tmux config (`~/.tmux.conf`)

```tmux
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
set -g status-left "#[bg=colour33,fg=colour231,bold] ai-vps #[bg=colour236,fg=colour39] #S "
set -g status-right "#[fg=colour245]%H:%M %d-%b "
set -g window-status-current-style "bg=colour39,fg=colour231,bold"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "reloaded"
```

## 3. The `agent` launcher (`~/.local/bin/agent`)

Spawns/attaches a named tmux session running an agent in `~/work/<name>`.
```bash
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
```
Plus a tiny `~/.local/bin/agents` = `tmux ls`. `chmod +x` both. Ensure
`~/.local/bin` is on PATH in `~/.bashrc` (so `ssh host 'agent ...'` finds it):
```bash
grep -q '.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## 4. The self-briefing — `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`

Write the **same** content to both (`cp` one to the other). Fill the bracketed
facts from detection. This is the highest-value file in the whole setup.

```markdown
# This machine: dedicated AI-session VPS (ai-vps)

You are running on a remote VPS that exists **solely to run AI coding agents**
(Claude Code and Codex). It is not a production server. Treat it as a powerful,
disposable workbench.

## Environment
- OS: <PRETTY_NAME> (use the right pkg manager: dnf on Amazon Linux, apt on
  Ubuntu/Debian — NOT the wrong one).
- Hardware: <vCPU> vCPU, <RAM>, <arch>, region <region>. Tailscale name: ai-vps.
- **Headless**: no GUI, no local browser. Never try to open a browser; test
  local services with `curl`/`wget`.

## Toolchain (already installed — don't reinstall)
- Node <ver> + npm; **pnpm** (prefer pnpm for JS/TS).
- Docker + `docker compose` (works without sudo).
- git, gcc/make, jq, tmux. Global npm installs land in ~/.npm-global (no sudo).

## Where to work
- One project per dir under `~/work/<project>`. Sessions run in **tmux**; a human
  drives them from their laptop over SSH/Tailscale.
- Other agent sessions may run in parallel — avoid global destructive actions
  (no `pkill node`, no `docker system prune -a`) without checking.

## Exposing dev servers ("localhost testing")
- The human reaches your services through an SSH tunnel mapping their
  `localhost:PORT` → this box's `localhost:PORT`.
- Bind dev servers to `127.0.0.1:PORT` (or `0.0.0.0:PORT`) and **tell the human
  the port**. Prefer 3000, 5173 (Vite), 8000, 8080. After starting, print:
  `-> running on port <PORT>; on your laptop run: vps-tunnel <PORT>, open http://localhost:<PORT>`
- Only SSH/Tailscale is exposed; ports are NOT public by default.
```

## Verify
```bash
ssh <user>@<host> 'bash -lc "hostname; agent --help; tmux new -d -s _t -c ~ && tmux ls && tmux kill-session -t _t; head -5 /etc/motd; ls ~/.claude/CLAUDE.md ~/.codex/AGENTS.md"'
```

➡️ Next: `04-tailscale.md`.
