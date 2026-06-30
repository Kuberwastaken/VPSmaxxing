# 00 — Architecture & mental model

```
        YOUR LAPTOP (cockpit)                         CLOUD VPS (workbench)
 ┌─────────────────────────────────┐         ┌──────────────────────────────────┐
 │  cmux / tmux  ── your editor     │         │  tmux sessions (1 per agent)      │
 │  your browser                    │         │   ├─ claudemaxxing (Claude Code)  │
 │                                  │         │   ├─ codexmaxxing  (Codex)        │
 │  ssh ai-vps ───────────────────────────────▶  └─ builds / docker / pnpm        │
 │  localhost:5173  ◀── tunnel ─────────────────  dev server on :5173            │
 │                                  │         │                                   │
 │  files ◀── reverse ssh ──────────────────▶  ssh mac  (clone/copy/rm)          │
 └─────────────────────────────────┘         └──────────────────────────────────┘
            ▲                                            ▲
            └──────────── Tailscale mesh (WireGuard, no public ports) ───────────┘
                          agent state syncs both ways every few minutes
```

## The idea

- **Laptop = cockpit.** You keep your editor, browser, and a terminal multiplexer
  (cmux on macOS, tmux anywhere). You never run the heavy stuff locally.
- **VPS = workbench.** A cheap always-on (or start-when-needed) Linux box that does
  nothing but run agents, builds, and containers. 8 vCPU / 32 GB is luxurious;
  4 vCPU / 16 GB is plenty; 2 vCPU / 8 GB works for solo use.
- **Tailscale = the wire.** A private mesh over WireGuard. SSH flows over it with
  **no public ports open** — outbound-only, NAT/firewall-friendly, revocable.
- **tmux = persistence.** Every agent runs in a named tmux session, so closing the
  laptop or dropping Wi-Fi never kills a run; you reattach and it's still going.
- **Sync = portability.** Skills, memory, and history rsync both ways on a timer,
  so the box and the laptop feel like one environment.

## Why a VPS at all (vs. just running locally)

- **Always-on & parallel:** kick off long jobs / many agents and walk away; the
  laptop can sleep.
- **Isolation:** YOLO agents (`--dangerously-skip-permissions` /
  `--dangerously-bypass-approvals-and-sandbox`) blast a disposable box, not your
  primary machine.
- **Cheap horsepower:** rent 8 cores/32 GB for ~$0.20–0.40/hr (or a fixed
  ~$15–30/mo box) instead of buying a maxed-out laptop.
- **Same setup everywhere:** phone → SSH → same agents.

## The two security realities to keep in mind

1. **Headless:** there's no display. Agents can't open a browser; they expose a
   port and you tunnel to it. Bake that into the box's `CLAUDE.md`/`AGENTS.md`.
2. **Blast radius:** if you enable reverse access (VPS → laptop), a YOLO agent on
   the VPS can also touch your laptop. Scope it (shared folder) or keep a kill
   switch (`revoke-vps-access`). See `08-reverse-access.md`.

## Components installed (by phase)

| On the VPS | On the laptop |
|------------|----------------|
| git, Node + pnpm, Docker + compose, tmux | cmux (macOS) / tmux |
| Claude Code + Codex (+ logins) | SSH aliases (`ai-vps`, fallback) |
| `agent` launcher, `claudemaxxing`/`codexmaxxing` | `claudevps`/`codexvps`, `vps-tunnel` |
| `CLAUDE.md`/`AGENTS.md` self-briefing, MOTD | Tailscale client |
| Tailscale (with Tailscale SSH) | sync driver reaches the laptop |
| `agent-sync` + cron (two-way sync driver) | user-space sshd (if reverse access) |
