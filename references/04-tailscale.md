# 04 — Tailscale: SSH with zero exposed ports

Tailscale puts the VPS and the laptop on a private WireGuard mesh. Result: SSH (and
tunnels) work over a stable address with **no public ports open**, behind any
NAT/firewall, and it's all revocable from an admin console. Strongly recommended.

## Why it beats opening port 22
- Outbound-only (UDP 41641 / DERP over 443) — **no security-group/firewall surgery**.
- You can keep the cloud firewall closed to the world entirely.
- Stable identity + optional **Tailscale SSH** (auth via your Tailscale identity —
  no SSH keys to manage), plus MagicDNS names.

## On the VPS
```bash
curl -fsSL https://tailscale.com/install.sh | sh     # works on AL2023 / Ubuntu / Debian
sudo systemctl enable --now tailscaled
# Bring it up with Tailscale SSH. This prints an auth URL.
sudo tailscale up --ssh --hostname ai-vps
```
**Headless auth flow:** `tailscale up` prints
`To authenticate, visit: https://login.tailscale.com/a/XXXX`. The user opens that
URL in a browser **on any device, signed into their identity provider** (Google/
GitHub/Microsoft/etc.), and approves the new machine. First-ever login auto-creates
their tailnet (free).

> Capture the URL for the user. If you run `tailscale up` non-interactively, run it
> with `nohup ... </dev/null &` and read the URL from its output so the process
> stays alive to finish the handshake once they approve.

Then let the normal user drive tailscale without sudo, and read the address:
```bash
sudo tailscale set --operator="$USER"
tailscale ip -4                       # -> 100.x.y.z  (stable per device)
tailscale status                      # shows the tailnet
```

## On the laptop
Install the Tailscale client and log in with the **same account**:
- **macOS GUI** (easiest, but the Homebrew cask can lag/404 — see troubleshooting):
  Mac App Store "Tailscale", then sign in.
- **CLI** (`brew install tailscale`): then
  `sudo tailscaled install-system-daemon && sudo tailscale up --operator=$USER`.
- Same-account devices on a personal tailnet auto-authorize — no admin approval.

## SSH alias on the laptop
Add to `~/.ssh/config`:
```sshconfig
Host ai-vps
    HostName 100.x.y.z          # the Tailscale IP (most reliable; see note)
    User <vps-user>
    # IdentityFile not needed if using Tailscale SSH
    ServerAliveInterval 60
```
> **MagicDNS note:** the open-source `tailscaled` on macOS often does **not** serve
> MagicDNS names, so `ssh ai-vps.<tailnet>.ts.net` may fail to resolve. The
> **Tailscale IP (`100.x.y.z`) always works** once both are on the tailnet — use it
> in `HostName`. The GUI app resolves MagicDNS fine.

## Verify
```bash
ssh -o ConnectTimeout=15 ai-vps 'echo CONNECTED $(whoami)@$(hostname)'
```

## Optional hardening
Once Tailscale SSH works, you can close inbound 22 in the cloud firewall entirely
and rely only on the tailnet. Keep your key-based public-IP path as a break-glass
fallback until you're confident.

➡️ Next: `05-maxxing-launchers.md`.
