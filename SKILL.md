---
name: vpsmaxxing
description: >-
  Set up and manage a personal cloud VPS as a dedicated remote workbench for AI
  coding agents (Claude Code + OpenAI Codex). Covers provisioning
  (git/node/pnpm/docker/tmux), installing & authenticating the agents, a
  self-aware agent environment, Tailscale networking (SSH with no exposed
  ports), a tmux + cmux cockpit, localhost port tunneling, reverse VPS→laptop
  file access (including a no-admin path for managed/work laptops), one-time
  migration of your skills/memory/history/credentials, and automatic two-way
  sync. Use this when the user wants to run AI agents on a server, offload
  heavy or parallel agent work off their laptop, "set up a VPS for Claude Code
  / Codex", spin up a remote agent box, or keep an agent setup synced across
  machines.
---

# VPSmaxxing — turn a cheap cloud VPS into a dedicated AI-agent workbench

This skill sets up a remote Linux box that exists **only to run AI coding agents**
(Claude Code + OpenAI Codex), driven comfortably from the user's laptop. It's the
generalized, battle-tested version of a real multi-hour setup — every step here
was actually run, and the **`references/troubleshooting.md`** file lists the traps
that cost the most time so you can skip them.

> **Why anyone wants this:** run agents 24/7 without melting a laptop, run many in
> parallel, keep heavy `node_modules`/docker builds off the local disk, and reach
> the same agent setup from any machine — for the price of a coffee per week
> instead of a new laptop.

---

## ⚠️ STEP 0 — ALWAYS interview the user first. Do not start installing blind.

Before touching anything, **tell the user what this skill can do and ask what they
actually want.** People arrive here with very different starting points (no VM yet
vs. one already running; personal Mac vs. locked-down work laptop; want everything
vs. just sync). Use the `AskUserQuestion` tool to capture the decisions that change
the plan. Suggested questions (adapt; ask only what's unknown):

1. **Starting point** — "Do you already have a VM/VPS, or do you need a
   recommendation on where to get one?" → if they need one, point them at
   `README.md`'s provider table and help them pick by budget; if they have one,
   collect host/IP, SSH user, and key path.
2. **Which agents** — Claude Code, Codex, or both?
3. **Auth method** — subscription login (Claude/ChatGPT plans, interactive) vs.
   API keys vs. copy existing credentials from their current machine.
4. **Networking** — set up **Tailscale** (recommended: SSH with zero exposed
   ports + stable name)? Yes/No.
5. **Cockpit** — install **cmux** on their Mac to drive parallel sessions? (macOS
   only — fall back to plain `tmux` over SSH on Linux/Windows.)
6. **Reverse access** — should the VPS be able to read/write the laptop's files
   (clone/copy/rm over SSH)? **Flag the risk** (agents often run in YOLO mode, so
   this re-couples the blast radius to their laptop) and offer scopes:
   full-home / a single shared folder / none.
7. **Migration** — copy their existing skills, memory, history, and logins
   (GitHub, etc.) from their current machine?
8. **Auto-sync** — keep skills/memory/history synced between laptop and VPS
   automatically going forward?

Then **summarize the plan you'll run and proceed phase by phase.** Re-confirm
before anything destructive or outward-facing (new instances, key changes,
deletions, opening firewall ports).

---

## What this skill can do (capability menu)

| # | Phase | What it does | Reference |
|---|-------|--------------|-----------|
| 1 | **Provision** | Base packages, Node + pnpm, Docker + compose, tmux — OS-aware (Amazon Linux 2023 / Ubuntu / Debian) | `references/01-provision-vps.md` |
| 2 | **Agents** | Install + authenticate Claude Code and Codex | `references/02-install-agents.md` |
| 3 | **Environment** | Hostname, MOTD, tmux config, an `agent` launcher, and `CLAUDE.md`/`AGENTS.md` that make the box *self-aware* it's a dedicated headless AI host | `references/03-agent-environment.md` |
| 4 | **Tailscale** | Private mesh networking: SSH with **no public ports**, stable address, works behind NAT/firewalls | `references/04-tailscale.md` |
| 5 | **Maxxing launchers** | `claudemaxxing`/`codexmaxxing` on the box + `claudevps`/`codexvps` on the laptop (top model + reasoning, persistent tmux) | `references/05-maxxing-launchers.md` |
| 6 | **cmux cockpit** | Install + wire cmux (macOS) to drive parallel remote sessions | `references/06-cmux-cockpit.md` |
| 7 | **Ports** | Test VPS dev servers at `localhost:PORT` via SSH tunnel (no exposed ports) | `references/07-ports-localhost.md` |
| 8 | **Reverse access** | Let the VPS reach the laptop's files; includes a **no-admin** path for managed/work laptops + a kill switch | `references/08-reverse-access.md` |
| 9 | **Migration** | One-time copy of skills, memory, history/transcripts, and logins (GitHub `gh`, git, MCP) | `references/09-migration.md` |
| 10 | **Auto-sync** | Cron-driven two-way rsync of skills/memory/history between laptop and VPS | `references/10-autosync.md` |

There are runnable, parameterized scripts in `scripts/` for the heavy phases.
Prefer reading the matching `references/NN-*.md` first — it explains the *why* and
the OS branches; the scripts are the *how*.

---

## Architecture in one breath

**Laptop = cockpit** (cmux/tmux, your editor, your browser) → over **Tailscale** →
**VPS = workbench** (agents in tmux sessions, docker, builds). Dev servers on the
VPS are reached at `localhost:PORT` on the laptop via SSH tunnels. Agent state
(skills/memory/history) syncs both ways automatically. Full diagram and rationale:
`references/00-architecture.md`.

---

## How to execute (for the agent running this skill)

1. **Interview** (Step 0) and confirm the plan.
2. **Detect the environment** before each remote step:
   `ssh <host> 'cat /etc/os-release; uname -m; nproc; free -h'` — branch on
   `ID=` (`amzn` → `dnf`; `ubuntu`/`debian` → `apt`). Never assume Ubuntu just
   because someone said "Linux"; the default AWS AMI user `ec2-user` means
   Amazon Linux, not Ubuntu (you cannot convert it in place).
3. **Go phase by phase**, reading the reference for each. Run remote commands over
   SSH; keep steps **idempotent** and verify after each (print versions, test a
   connection, make a real round-trip).
4. **Handle secrets carefully**: never print private keys, tokens, or
   `auth.json`/`.credentials.json` to the conversation. Pipe them directly
   (`cmd | ssh host 'cat > file'`) and `chmod 600`. Don't paste secrets into
   chat; if the user does, recommend rotation.
5. **Confirm before** creating/destroying instances, changing keys, opening
   firewall ports, or deleting anything you didn't create.
6. When you hit anything weird, check `references/troubleshooting.md` **before**
   improvising — most surprises are already documented there.

---

## Good-to-haves / extensions (offer these; don't force them)

- **`pullmac`/`pushmac` helpers** so agents shuttle files to/from the laptop in one word.
- **Stop-when-idle** automation for hourly clouds (AWS/GCP) to slash cost — a cron
  that stops the instance after N minutes of no SSH sessions.
- **A second cheap "always-on" box** for long jobs + a beefier "burst" box you
  start only when needed.
- **dotfiles sync** (shell rc, git config, editor config) alongside the agent sync.
- **`gh` + git pre-wired** so agents can clone/push without prompts.
- **Per-project tmux layouts** (editor pane + agent pane + logs pane).
- **A status line / MOTD** that shows specs, running agents, and listening ports.
- **Cloud-backed history sync** (e.g. claude-sync) if the user wants resume to
  follow them across machines rather than per-directory `claude --continue`.

---

## Hard-won principles (read `troubleshooting.md` for specifics)

- The box is **headless** — no GUI, no local browser. Agents must test with
  `curl` and expose ports for the human via tunnels.
- **Tailscale > opening port 22.** Outbound-only, no security-group surgery,
  revocable.
- On **managed/work laptops** you usually have **no admin** — system SSH server,
  LaunchAgents, cron, and `systemsetup` are often blocked (or gated behind Full
  Disk Access). There are user-space workarounds (see reverse-access + autosync).
- Treat the VPS as a **disposable workbench**, not precious infra; keep real work
  in git and synced, so you can rebuild it from this skill in minutes.
