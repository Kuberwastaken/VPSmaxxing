# 09 — Migrate your existing setup (skills, memory, history, logins)

One-time copy of the user's current machine → VPS. **Never print secrets** — pipe
them straight to the box and `chmod 600`. Run rsync from the laptop pushing to the
VPS alias (`ai-vps`), or from the VPS pulling from the `mac` alias if reverse
access is set up.

## Claude Code (`~/.claude`)
```bash
rsync -az ~/.claude/skills/        ai-vps:.claude/skills/         # skills
rsync -az ~/.claude/history.jsonl  ai-vps:.claude/history.jsonl   # prompt history
rsync -az ~/.claude/settings.json  ai-vps:.claude/settings.json
rsync -az ~/.claude/projects/      ai-vps:.claude/projects/       # transcripts (big)
```
**Memory** lives under `~/.claude/projects/<ENCODED-HOME>/memory/`, where the home
path is encoded with `/`→`-`. The encoding differs per machine, so map it
explicitly:
```bash
# laptop  ~/.claude/projects/-Users-<you>/memory   ->   VPS ~/.claude/projects/-home-<vpsuser>/memory
ssh ai-vps 'mkdir -p ~/.claude/projects/-home-<vpsuser>/memory'
rsync -az ~/.claude/projects/-Users-<you>/memory/ ai-vps:.claude/projects/-home-<vpsuser>/memory/
```
**Credentials:** Linux uses `~/.claude/.credentials.json`; macOS uses the Keychain
(`security find-generic-password -w -s "Claude Code-credentials" -a "$USER" | ssh
ai-vps 'umask 077; cat > ~/.claude/.credentials.json'`). See `02`.

**`CLAUDE.md` (global):** don't clobber the VPS's self-briefing — **merge**:
```bash
rsync -az ~/.claude/CLAUDE.md ai-vps:.claude/CLAUDE.md.mac
ssh ai-vps 'grep -q "USER GLOBAL RULES" ~/.claude/CLAUDE.md || { printf "\n\n---\n# USER GLOBAL RULES\n" >> ~/.claude/CLAUDE.md; cat ~/.claude/CLAUDE.md.mac >> ~/.claude/CLAUDE.md; }; rm ~/.claude/CLAUDE.md.mac'
```

## Codex (`~/.codex`)
```bash
rsync -az ~/.codex/skills/            ai-vps:.codex/skills/
rsync -az ~/.codex/sessions/          ai-vps:.codex/sessions/          # history
rsync -az ~/.codex/memories_1.sqlite  ai-vps:.codex/memories_1.sqlite  # memories
rsync -az ~/.codex/session_index.jsonl ai-vps:.codex/session_index.jsonl
# auth.json -> see 02.  AGENTS.md -> merge like CLAUDE.md above.
```
**Don't** copy the laptop's `~/.codex/config.toml` wholesale — a desktop-app config
points at local apps/paths that don't exist on the VPS. Port only the bits you want
(e.g. an `[mcp_servers.*]` block).

## GitHub + git
```bash
# install gh on the VPS (binary install avoids dnf repo/GPG headaches):
V=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -nE 's/.*"tag_name": "v([0-9.]+)".*/\1/p' | head -1)
ssh ai-vps "curl -fsSL https://github.com/cli/cli/releases/download/v${V}/gh_${V}_linux_amd64.tar.gz -o /tmp/gh.tgz && tar -xzf /tmp/gh.tgz -C /tmp && mkdir -p ~/.local/bin && cp /tmp/gh_${V}_linux_amd64/bin/gh ~/.local/bin/gh && chmod +x ~/.local/bin/gh"
# transfer the token (from your keyring, never printed) + wire git:
gh auth token | ssh ai-vps 'export PATH=$HOME/.local/bin:$PATH; gh auth login --with-token && gh auth setup-git'
# replicate identity:
ssh ai-vps "git config --global user.name \"$(git config --global user.name)\"; git config --global user.email \"$(git config --global user.email)\""
```
> If the user uses SSH (`git@github.com`) instead of https, either copy their
> GitHub SSH key to the VPS or add the VPS's own key to their GitHub account.

## MCP servers
- **Claude:** `claude mcp add <name> -s user -- <command> [args]` (user scope =
  available everywhere). For `uvx`-based servers, install `uv` first
  (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
- **Codex:** add a block to `~/.codex/config.toml`:
  ```toml
  [mcp_servers.<name>]
  command = "uvx"
  args = ["--from", "git+https://github.com/owner/repo", "entrypoint"]
  startup_timeout_sec = 120
  ```
- Make sure `~/.local/bin` (where `uvx` lives) is on the agents' PATH (the maxxing
  launchers already add it).

## Verify
```bash
ssh ai-vps 'bash -lc "ls ~/.claude/skills ~/.codex/skills; ls ~/.claude/projects/-home-<vpsuser>/memory | wc -l; gh auth status 2>&1 | grep Logged; git config --global user.email"'
```

➡️ Next: `10-autosync.md`.
