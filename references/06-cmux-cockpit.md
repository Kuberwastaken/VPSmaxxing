# 06 — cmux cockpit (macOS) — drive many agents at once

[cmux](https://github.com/manaflow-ai/cmux) is a native **macOS** terminal built for
running multiple AI coding agents in parallel: vertical tabs showing per-workspace
git branch / PR status / listening ports / last notification, agent-aware
notification rings, a split browser pane, and a CLI + Unix socket API for scripting.

> **It's macOS-only** (Swift/AppKit, requires macOS 13+). It runs on your **laptop**,
> not the VPS. The VPS provides the agents over SSH; cmux is the cockpit.
> On Linux/Windows, skip cmux and drive the VPS with plain **tmux over SSH** (the
> `agent` launcher + `claudevps`/`codexvps` already give you that).

## Install (macOS)
```bash
brew tap manaflow-ai/cmux
brew install --cask cmux      # or download the .dmg from the GitHub releases page
```
Config: `~/.config/cmux/cmux.json` (created on first launch); it also reads
`~/.config/ghostty/config` for terminal behavior (font, theme, scrollback).
A safe minimal `~/.config/ghostty/config`:
```
font-size = 14
scrollback-limit = 10000000
```

## Wire it to the VPS
cmux is "just a terminal," so any agent that runs in a terminal works — including
over SSH. The pattern:
1. Open a cmux tab/workspace.
2. Run `claudevps <project>` (or `codexvps <project>`, or `ssh ai-vps` then `agent
   <name>`). Each tab is one remote agent in its own persistent tmux session.
3. Open more tabs for parallel agents — cmux's sidebar shows each one's status and
   rings the tab when an agent needs you.

Useful cmux CLI bits (run `cmux --help`): `cmux <path>` opens a workspace,
`cmux reload-config` reloads settings, and there's a socket API for scripting
tabs/panes if you want to automate launching a fleet.

> If `brew install --cask cmux` fails to download (the cask URL can 404 on a
> version bump), grab the `.dmg` from the
> [latest release](https://github.com/manaflow-ai/cmux/releases/latest) instead.

➡️ Next: `07-ports-localhost.md`.
