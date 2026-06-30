# 07 — Localhost testing (reach VPS dev servers from your laptop)

The VPS is headless, so when an agent starts a dev server you view it on your
laptop via an **SSH tunnel** — no public ports, nothing exposed.

## The helper (laptop) — `~/.local/bin/vps-tunnel`
```bash
#!/usr/bin/env bash
# vps-tunnel [PORT ...]  — forward VPS ports to the same localhost port here.
set -euo pipefail
[ $# -eq 0 ] && set -- 3000 5173 8000 8080
args=(); for p in "$@"; do args+=(-L "127.0.0.1:$p:127.0.0.1:$p"); done
echo "Tunneling -> http://localhost:<port> : $*  (Ctrl-C to stop)"
exec ssh -N "${args[@]}" ai-vps
```
`chmod +x`, ensure `~/.local/bin` is on PATH. Usage:
```bash
vps-tunnel 5173            # agent's Vite server -> http://localhost:5173
vps-tunnel 3000 8080       # multiple at once
```

## How it fits the workflow
1. Agent on the VPS binds a server to `127.0.0.1:PORT` (or `0.0.0.0:PORT`) and
   tells you the port (the `CLAUDE.md`/`AGENTS.md` briefing instructs it to).
2. You run `vps-tunnel <port>` and open `http://localhost:<port>`.

Tunneling works the same over Tailscale or the public-IP fallback. It's strictly
better than opening ports because nothing is publicly reachable.

## If you genuinely need a public URL
- **Quick share:** a tunnel service (e.g. `cloudflared tunnel`, `ngrok`) on the VPS
  — gives a temporary public HTTPS URL without touching the firewall.
- **Persistent public port:** open it in the cloud firewall/security group (needs
  console/API access) and bind the server to `0.0.0.0`. Least safe — prefer the
  tunnel approaches.

➡️ Next: `08-reverse-access.md`.
