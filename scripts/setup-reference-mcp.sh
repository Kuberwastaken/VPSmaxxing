#!/usr/bin/env bash
# VPSmaxxing — register the `reference` MCP so agents can search EVERY past session
# of BOTH tools (Claude Code + Codex) across BOTH machines.
#   reference: https://github.com/Kuberwastaken/reference  (local-first, read-only)
#
# Run ON THE VPS (registers here, and on the laptop over the reverse SSH from `08`).
# With auto-sync (`10`) mirroring transcripts, reference on either box can then recall
# the other machine's sessions too. Pairs with session hand-off (`11`): hand-off MOVES
# one session, reference FINDS any of them.
#
# Optional env:
#   REF_URL          repo/spec for uvx    (default: git+https://github.com/Kuberwastaken/reference)
#   REF_TOOLS        claude | codex | both (default: both)
#   PEER_FROM_VPS    ssh alias VPS->laptop (default: mac; set REF_LAPTOP=0 to skip)
#   REF_LAPTOP       also register on the laptop (default: 1)
set -uo pipefail
REF_URL="${REF_URL:-git+https://github.com/Kuberwastaken/reference}"
REF_TOOLS="${REF_TOOLS:-both}"
PEER_FROM_VPS="${PEER_FROM_VPS:-mac}"
REF_LAPTOP="${REF_LAPTOP:-1}"

# Self-contained registrar: $1=repo URL, $2=tools. Runs locally AND (piped) on the laptop.
REG='
set -uo pipefail
URL="$1"; TOOLS="${2:-both}"
if ! command -v uvx >/dev/null 2>&1; then
  echo "  installing uv (needed to run the MCP via uvx)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
command -v uvx >/dev/null 2>&1 || { echo "  ! uv/uvx still not found — install uv, then re-run"; }
if [ "$TOOLS" != codex ] && command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -q "^reference:"; then echo "  claude: reference already registered";
  else claude mcp add reference --scope user -- uvx --from "$URL" reference-mcp >/dev/null 2>&1 \
       && echo "  claude: registered reference (user scope)" || echo "  ! claude mcp add failed"; fi
fi
if [ "$TOOLS" != claude ]; then
  cfg="$HOME/.codex/config.toml"; mkdir -p "$HOME/.codex"; touch "$cfg"
  if grep -q "\[mcp_servers.reference\]" "$cfg"; then echo "  codex: reference already in config.toml";
  else printf "\n[mcp_servers.reference]\ncommand = \"uvx\"\nargs = [\"--from\", \"%s\", \"reference-mcp\"]\nstartup_timeout_sec = 120\n" "$URL" >> "$cfg" \
       && echo "  codex: added reference to config.toml"; fi
fi
'

echo "==> registering reference on the VPS"
bash -c "$REG" _ "$REF_URL" "$REF_TOOLS"

if [ "$REF_LAPTOP" = 1 ] && ssh -n -o ConnectTimeout=8 -o BatchMode=yes "$PEER_FROM_VPS" true 2>/dev/null; then
  echo "==> registering reference on the laptop ($PEER_FROM_VPS)"
  echo "$REG" | ssh "$PEER_FROM_VPS" bash -s "$REF_URL" "$REF_TOOLS"
elif [ "$REF_LAPTOP" = 1 ]; then
  echo "==> laptop unreachable over '$PEER_FROM_VPS' — register there manually:"
  echo "      claude mcp add reference --scope user -- uvx --from $REF_URL reference-mcp"
  echo "      # and add the [mcp_servers.reference] block above to ~/.codex/config.toml"
fi

echo
echo "Verify:  claude mcp list | grep reference        # -> ✔ Connected"
echo "         uvx --from $REF_URL reference-mcp --help 2>/dev/null | head -1 || true"
echo "In a Claude/Codex session, the reference_* tools (recall, search_sessions, ...)"
echo "then see every Claude + Codex session on both machines. Restart the agent to load."
