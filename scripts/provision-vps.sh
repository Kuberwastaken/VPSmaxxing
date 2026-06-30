#!/usr/bin/env bash
# VPSmaxxing — provision a fresh Linux VPS for AI agents.
# Installs: git/tmux/build tools, Node 22 + pnpm, Docker + compose, Claude Code, Codex.
# Run ON the VPS:  bash provision-vps.sh    (or:  ssh host 'bash -s' < provision-vps.sh)
# Idempotent; safe to re-run.
set -uo pipefail
. /etc/os-release 2>/dev/null || { echo "no /etc/os-release"; exit 1; }
echo "==> OS: ${PRETTY_NAME:-$ID}  arch=$(uname -m)  cpus=$(nproc)"

install_amzn() {
  sudo dnf -y install git tmux htop tar gzip unzip jq gcc gcc-c++ make wget rsync vim-enhanced tree bind-utils
  sudo dnf -y install nodejs22 || sudo dnf -y install nodejs
  # AL2023 alternatives trap: pin v22 if both 18 and 22 are present
  if command -v alternatives >/dev/null && [ -e /usr/bin/node-22 ]; then sudo alternatives --set node /usr/bin/node-22 || true; hash -r; fi
  sudo dnf -y install docker && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"
  mkdir -p ~/.docker/cli-plugins
  curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
    -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
}
install_apt() {
  sudo apt-get update
  sudo apt-get -y install git tmux htop tar gzip unzip jq build-essential curl wget rsync vim tree dnsutils ca-certificates
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
  curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker "$USER"
}
case "$ID" in
  amzn) install_amzn ;;
  ubuntu|debian|pop|linuxmint) install_apt ;;
  *) echo "!! Unknown distro '$ID' — install git/node22/docker/tmux yourself, then re-run for the npm parts." ;;
esac

# user-level npm prefix (no sudo) + PATH + pnpm + agents
mkdir -p ~/.npm-global ~/.local/bin
npm config set prefix ~/.npm-global
grep -q 'npm-global/bin' ~/.bashrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
grep -q '.local/bin'     ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"'     >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
echo "==> node $(node -v 2>/dev/null) npm $(npm -v 2>/dev/null)"
npm install -g pnpm @anthropic-ai/claude-code @openai/codex

echo "==> versions:"
for c in git tmux node npm pnpm docker claude codex; do
  printf "    %-7s " "$c"; command -v "$c" >/dev/null && "$c" --version 2>/dev/null | head -1 || echo MISSING
done
echo
echo "NEXT:"
echo "  1) Re-connect (new SSH session) so the docker group applies."
echo "  2) Authenticate:  claude   (then /login)   and   codex login"
echo "  3) Run setup-agent-env.sh to make the box self-aware + add launchers."
