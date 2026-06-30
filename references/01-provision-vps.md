# 01 — Provision the VPS (base system)

Goal: a fresh Linux box with git, a current Node + pnpm, Docker + compose, and
tmux. Written for **Amazon Linux 2023** (the default on AWS), with **Ubuntu/Debian**
equivalents noted. Everything is idempotent and safe to re-run.

## 0. Connect + detect the OS (do this first, every time)

```bash
ssh <user>@<host> 'whoami; . /etc/os-release; echo "$PRETTY_NAME"; uname -m; nproc; free -h | awk "/Mem/{print \$2}"; df -h / | tail -1'
```
- `ID=amzn` → Amazon Linux → use **`dnf`**.
- `ID=ubuntu` / `ID=debian` → use **`apt`**.
- Default AWS user `ec2-user` ⇒ Amazon Linux (NOT Ubuntu). Ubuntu's user is
  `ubuntu`. **You cannot convert one to the other in place** — if the user insists
  on Ubuntu, they must launch a new Ubuntu instance.

Fix key perms locally if needed: `chmod 600 <key.pem>`.

## 1. Base packages

**Amazon Linux 2023:**
```bash
sudo dnf -y install git tmux htop tar gzip unzip jq gcc gcc-c++ make wget rsync vim-enhanced tree bind-utils
```
> ⚠️ Do **not** `dnf install curl` on AL2023 — it conflicts with the preinstalled
> `curl-minimal`. `curl` is already there.

**Ubuntu/Debian:**
```bash
sudo apt-get update && sudo apt-get -y install git tmux htop tar gzip unzip jq build-essential curl wget rsync vim tree dnsutils ca-certificates
```

## 2. Node + pnpm

Agents need Node ≥ 20 (Codex prefers ≥ 22). Use a **user-level npm global prefix**
so `npm i -g` (and the agents installed that way) need no sudo.

**Amazon Linux 2023** ships parallel `nodejsXX` packages via the `alternatives`
system — and there's a trap:
```bash
sudo dnf -y install nodejs22        # ships node 22, npm, npx
# TRAP: if a plain `nodejs` (v18) is also present, `alternatives` may keep v18 as
# the default. Pin v22 explicitly:
sudo alternatives --set node /usr/bin/node-22   # if `node -v` shows the wrong version
node -v   # must be v22.x
```

**Ubuntu/Debian** — NodeSource (system-wide) or `fnm`/`nvm` (user-space):
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**User npm prefix + pnpm (all OSes), as the VPS user (no sudo):**
```bash
mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global
grep -q npm-global/bin ~/.bashrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g pnpm        # or: corepack enable && corepack prepare pnpm@latest --activate
node -v; npm -v; pnpm -v
```
> Note: `ssh host 'cmd'` sources `~/.bashrc` (bash detects the remote shell), so the
> PATH line above is enough for non-interactive SSH commands too.

## 3. Docker + compose

**Amazon Linux 2023:**
```bash
sudo dnf -y install docker
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"      # take effect on next SSH login
# compose v2 as a user CLI plugin:
mkdir -p ~/.docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```

**Ubuntu/Debian** (official convenience script includes compose):
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
```

Verify (group membership applies on a fresh SSH session):
```bash
ssh <user>@<host> 'docker version --format "{{.Server.Version}}"; docker compose version'
```

## 4. Verify the whole base

```bash
ssh <user>@<host> 'bash -lc "for c in git tmux node npm pnpm docker; do printf \"%-7s \" \$c; command -v \$c >/dev/null && \$c --version 2>/dev/null | head -1 || echo MISSING; done"'
```

➡️ Next: `02-install-agents.md`. Or just run `scripts/provision-vps.sh` which does
all of the above with OS detection.
