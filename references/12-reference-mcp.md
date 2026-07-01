# 12 — Reference MCP (recall any past session, both tools, both machines)

Hand-off (`11`) *moves* one conversation. **Reference** *finds* any of them.
[reference](https://github.com/Kuberwastaken/reference) is a single MCP server that
lets an agent search **every past session transcript and memory file across all your
tools** — Claude Code ↔ Codex — so Claude can see what you did in Codex and vice
versa. It's local-first and read-only (it just reads the JSONL transcripts already on
disk). Combined with auto-sync (`10`), which mirrors those transcripts between
machines, reference on the VPS can recall your **laptop** sessions too, and the
reverse.

## Why it belongs here
- `claude --continue`/`--resume` only reach the *current directory's* sessions of the
  *current tool*. Reference is the cross-cutting recall layer: "did I solve this
  before, in any repo, in either agent, on either box?"
- After a hand-off, it's how the receiving agent pulls in context from sessions you
  *didn't* hand over.

## Install
```bash
# ON THE VPS (also registers on the laptop over the reverse SSH from `08`):
bash setup-reference-mcp.sh
```
It ensures `uv` is present, then registers the server in **Claude Code** (user scope)
and **Codex** (`~/.codex/config.toml`), idempotently. No clone or PyPI install — it
runs straight from GitHub via `uvx`.

Under the hood it registers this command:
```
uvx --from git+https://github.com/Kuberwastaken/reference reference-mcp
```
- **Claude Code:** `claude mcp add reference --scope user -- uvx --from git+https://github.com/Kuberwastaken/reference reference-mcp`
- **Codex** (`~/.codex/config.toml`):
  ```toml
  [mcp_servers.reference]
  command = "uvx"
  args = ["--from", "git+https://github.com/Kuberwastaken/reference", "reference-mcp"]
  startup_timeout_sec = 120
  ```

## What the agent gets (MCP tools)
`recall` (best matching turns + memory for a query), `search_sessions`, `search_memory`,
`list_sessions`, `get_session`, `list_sources`. It reads Claude
`~/.claude/projects/**/*.jsonl`, Codex `~/.codex/sessions/**/*.jsonl`, and memory files
(`CLAUDE.md`/`AGENTS.md`/`memory/*.md`); ranking is offline BM25 + recency/project
boosts.

## Verify
```bash
claude mcp list | grep reference            # -> reference: uvx ... - ✔ Connected
# in a session, ask the agent to run reference.list_sources — it should report
# BOTH a `claude` and a `codex` adapter with session/memory file counts.
```
Restart the agent after registering so it loads the new MCP server. On the VPS the
counts include laptop sessions once auto-sync has run.

## Notes
- **`uvx` / `uv` required** — the setup script installs it (`astral.sh/uv`) if missing.
- Interactively-authenticated MCP servers can be absent in headless/cron contexts;
  reference has no auth and no network dependency, so it works headless.
- Local-first & read-only: it never edits or uploads your transcripts.

➡️ Pairs with `11` (hand-off) and `10` (auto-sync). Traps in `troubleshooting.md`.
