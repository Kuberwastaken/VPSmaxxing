#!/usr/bin/env bash
# VPSmaxxing — health-check for an AI-agent VPS.
# Verifies that every tool installed by provision-vps.sh / setup-agent-env.sh
# is present and minimally functional.
# Run ON the VPS:  bash scripts/vps-doctor.sh
# Read-only: modifies nothing; safe to run at any time.
set -uo pipefail

if [ -t 1 ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
else
  BOLD=''; RED=''; YEL=''; GRN=''; RST=''
fi

PASS="${GRN}${BOLD}PASS${RST}"; WARN="${YEL}${BOLD}WARN${RST}"; FAIL="${RED}${BOLD}FAIL${RST}"

_PASSES=0; _WARNS=0; _FAILS=0

pass() { printf "  [%s] %s\n" "$PASS" "$*"; (( _PASSES++ )) || true; }
warn() { printf "  [%s] %s\n" "$WARN" "$*"; (( _WARNS++  )) || true; }
fail() { printf "  [%s] %s\n" "$FAIL" "$*"; (( _FAILS++  )) || true; }

section() { printf "\n%s==> %s%s\n" "${BOLD}" "$*" "${RST}"; }

cmd_version() {
  local cmd="$1"; shift
  command -v "$cmd" >/dev/null 2>&1 || { echo ""; return 1; }
  "$cmd" "$@" 2>/dev/null | head -1 || true
}

require_cmd() {
  local label="$1" cmd="$2"; shift 2
  local ver
  ver="$(cmd_version "$cmd" "$@")" || { fail "$label — not found (command: $cmd)"; return; }
  pass "$label — $ver"
}

require_min_ver() {
  local label="$1" cmd="$2" min="$3"; shift 3
  local raw major
  raw="$(cmd_version "$cmd" "$@")" || { fail "$label — not found (command: $cmd)"; return; }
  major="$(printf '%s' "$raw" | grep -oE '[0-9]+' | head -1)"
  if [ -z "$major" ]; then
    warn "$label — present but could not parse version: $raw"
  elif [ "$major" -ge "$min" ]; then
    pass "$label — $raw"
  else
    warn "$label — $raw  (want major >= $min)"
  fi
}

_check_url() {
  local label="$1" url="$2"
  if curl -fsS --max-time 8 -o /dev/null "$url" 2>/dev/null; then
    pass "$label — reachable"
  else
    fail "$label — unreachable ($url)"
  fi
}

check_git() {
  section "Git"
  require_min_ver "git" git 2 --version
}

check_tmux() {
  section "tmux"
  require_min_ver "tmux" tmux 3 -V
}

check_node() {
  section "Node.js"
  require_min_ver "node" node 22 --version
  require_cmd     "npm"  npm  --version
}

check_pnpm() {
  section "pnpm"
  if command -v pnpm >/dev/null 2>&1; then
    pass "pnpm — $(pnpm --version 2>/dev/null | head -1)"
  else
    fail "pnpm — not found (run: npm install -g pnpm)"
  fi
}

check_docker() {
  section "Docker"
  if ! command -v docker >/dev/null 2>&1; then
    fail "docker — not found"; return
  fi
  local dver dcver
  dver="$(docker --version 2>/dev/null | head -1)"
  if docker info >/dev/null 2>&1; then
    pass "docker daemon — reachable  ($dver)"
  else
    warn "docker daemon — not reachable as current user ($dver); re-login so docker group takes effect, or check daemon status"
  fi
  if dcver="$(docker compose version 2>/dev/null | head -1)"; then
    pass "docker compose — $dcver"
  else
    fail "docker compose — plugin not found (see provision-vps.sh)"
  fi
}

check_claude() {
  section "Claude Code"
  if ! command -v claude >/dev/null 2>&1; then
    fail "claude — not found (run: npm install -g @anthropic-ai/claude-code)"; return
  fi
  local ver
  ver="$(claude --version 2>/dev/null | head -1 || true)"
  pass "claude — ${ver:-<version unavailable>}"
  if [ -x "$HOME/.local/bin/claudemaxxing" ]; then
    pass "$HOME/.local/bin/claudemaxxing — present"
  else
    warn "$HOME/.local/bin/claudemaxxing — not found (run setup-agent-env.sh)"
  fi
}

check_codex() {
  section "Codex"
  if ! command -v codex >/dev/null 2>&1; then
    fail "codex — not found (run: npm install -g @openai/codex)"; return
  fi
  local ver
  ver="$(codex --version 2>/dev/null | head -1 || true)"
  pass "codex — ${ver:-<version unavailable>}"
  if [ -x "$HOME/.local/bin/codexmaxxing" ]; then
    pass "$HOME/.local/bin/codexmaxxing — present"
  else
    warn "$HOME/.local/bin/codexmaxxing — not found (run setup-agent-env.sh)"
  fi
}

check_tailscale() {
  section "Tailscale"
  if ! command -v tailscale >/dev/null 2>&1; then
    warn "tailscale — not installed (optional; needed for laptop SSH tunnel)"; return
  fi
  local tsver
  tsver="$(tailscale version 2>/dev/null | head -1 || true)"
  if tailscale status >/dev/null 2>&1; then
    pass "tailscale $tsver — daemon reachable"
  else
    warn "tailscale $tsver — daemon not running or not accessible"
  fi
}

check_internet() {
  section "Internet connectivity"
  _check_url "registry.npmjs.org" "https://registry.npmjs.org/"
  _check_url "api.anthropic.com"  "https://api.anthropic.com/"
  _check_url "github.com"         "https://github.com/"
}

check_agent_env() {
  section "Agent environment (setup-agent-env.sh artefacts)"
  local f
  for f in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" "$HOME/.tmux.conf"; do
    if [ -f "$f" ]; then
      pass "$f — present"
    else
      warn "$f — missing (run setup-agent-env.sh)"
    fi
  done
  local launcher
  for launcher in agent agents claudemaxxing codexmaxxing; do
    if [ -x "$HOME/.local/bin/$launcher" ]; then
      pass "$HOME/.local/bin/$launcher — present and executable"
    else
      warn "$HOME/.local/bin/$launcher — missing (run setup-agent-env.sh)"
    fi
  done
  if [ -d "$HOME/work" ]; then
    pass "$HOME/work — present"
  else
    warn "$HOME/work — missing (run setup-agent-env.sh)"
  fi
}

summary() {
  local total=$(( _PASSES + _WARNS + _FAILS ))
  printf "\n%s--- Summary ---%s\n" "$BOLD" "$RST"
  printf "  Total checks : %d\n" "$total"
  printf "  %s : %d\n" "$PASS" "$_PASSES"
  printf "  %s : %d\n" "$WARN" "$_WARNS"
  printf "  %s : %d\n" "$FAIL" "$_FAILS"
  if [ "$_FAILS" -gt 0 ]; then
    printf "\n  %sAction required%s — fix the FAIL items above.\n" "$RED$BOLD" "$RST"
    return 1
  elif [ "$_WARNS" -gt 0 ]; then
    printf "\n  %sLooking mostly good%s — review the WARN items above.\n" "$YEL$BOLD" "$RST"
  else
    printf "\n  %sAll checks passed.%s\n" "$GRN$BOLD" "$RST"
  fi
}

main() {
  export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
  # shellcheck source=/etc/os-release
  . /etc/os-release 2>/dev/null || true
  printf "%s==> VPS doctor%s  |  host=%s  OS=%s  arch=%s  cpus=%s\n" \
    "$BOLD" "$RST" "$(hostname)" "${PRETTY_NAME:-${ID:-?}}" "$(uname -m)" "$(nproc)"

  check_git
  check_tmux
  check_node
  check_pnpm
  check_docker
  check_claude
  check_codex
  check_tailscale
  check_internet
  check_agent_env

  summary
}

main "$@"
