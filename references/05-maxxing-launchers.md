# 05 — "Maxxing" launchers (top model + reasoning, persistent, one command)

Two layers:
1. **On the VPS:** `claudemaxxing` / `codexmaxxing` — launch each agent with the
   most capable model + highest reasoning + low-friction flags.
2. **On the laptop:** `claudevps` / `codexvps` — one command that SSHes in and drops
   you into a **persistent tmux session** running the maxxing launcher.

> ⚠️ **Model IDs change.** The examples below are what was current when this skill
> was written. Before deploying, confirm the latest, most capable model IDs and
> the valid reasoning-effort values for each tool (for Claude, the bundled
> `claude-api` skill / Anthropic docs; for Codex, `~/.codex/` model cache or
> OpenAI docs). Substitute accordingly — don't hardcode stale IDs.
>
> ⚠️ These use **YOLO flags** (skip permissions / bypass approvals). That's
> appropriate *because the VPS is a disposable, isolated box* — but if you've
> enabled reverse access to your laptop (`08`), a YOLO agent can reach the laptop
> too. Keep that in mind.

## VPS launchers (`~/.local/bin/`)

`claudemaxxing` — newest Opus, max reasoning, skip prompts, pre-trust the dir:
```bash
#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
# pre-accept the folder-trust prompt for the current dir (optional convenience)
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
exec claude --dangerously-skip-permissions --model 'claude-opus-4-8[1m]' --effort xhigh "$@"
```

`codexmaxxing` — newest model, max reasoning, fastest service tier, bypass approvals:
```bash
#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
exec codex --model gpt-5.5 \
  -c model_reasoning_effort="xhigh" \
  -c model_service_tier="priority" \
  --dangerously-bypass-approvals-and-sandbox "$@"
```
`chmod +x` both. (Tip: `model_service_tier="priority"` = the faster "1.5×" tier;
it's often already the model's default, so it's belt-and-suspenders.)

## Laptop launchers (shell rc — zsh/bash)

Each opens a **persistent** tmux session on the VPS (survives disconnects;
re-running reattaches). Replace `ai-vps` with your SSH alias.
```bash
claudevps() {  # usage: claudevps [project]   (default: scratch)
  local n="${1:-scratch}"
  ssh -t ai-vps "mkdir -p \"\$HOME/work/$n\" && tmux new-session -A -s \"c-$n\" -c \"\$HOME/work/$n\" \"\$HOME/.local/bin/claudemaxxing\""
}
codexvps() {   # usage: codexvps [project]    (default: scratch)
  local n="${1:-scratch}"
  ssh -t ai-vps "mkdir -p \"\$HOME/work/$n\" && tmux new-session -A -s \"x-$n\" -c \"\$HOME/work/$n\" \"\$HOME/.local/bin/codexmaxxing\""
}
```
`\$HOME` is escaped so it expands on the VPS; `$n` expands locally. `tmux
new-session -A` = attach-or-create, so `claudevps blog` resumes the same session
each time.

## Resuming
Prefer `claude --continue` (resumes the latest session **in the current dir**) — no
cross-machine path-matching needed. Laptop sessions continue on the laptop, VPS
sessions on the VPS.

➡️ Next: `06-cmux-cockpit.md`.
