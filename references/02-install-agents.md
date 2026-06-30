# 02 — Install & authenticate the agents

Installs Claude Code and OpenAI Codex on the VPS and gets them logged in. Both are
Node CLIs and install into the user npm prefix from `01` (no sudo).

## Install

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g @anthropic-ai/claude-code      # command: `claude`
npm install -g @openai/codex                  # command: `codex`  (scoped name!)
claude --version
codex  --version
```
> ⚠️ The unscoped `codex` npm package is an unrelated 2012 project. Always install
> `@openai/codex`.
>
> Alternative installers if you prefer not to use npm:
> Claude Code → `curl -fsSL https://claude.ai/install.sh | bash`;
> Codex → `curl -fsSL https://chatgpt.com/codex/install.sh | sh`.

## Authenticate — pick one per tool (ask the user in Step 0)

The box is **headless**, so plan for the no-browser flow.

### A. Subscription login (Claude Pro/Max, ChatGPT Plus/Pro) — recommended for most
Run the tool interactively over SSH and follow the device/URL flow: it prints a URL,
you open it in any browser on your laptop, sign in, and paste the code back.
```bash
ssh -t <user>@<host>          # need a TTY
claude          # → choose login → open printed URL on laptop → paste code
codex login     # → same idea (ChatGPT login)
```

### B. API keys (good for automation / billing isolation)
Add to `~/.bashrc` on the VPS (never paste keys into chat — have the user place
them, or pipe from a local secret store):
```bash
export ANTHROPIC_API_KEY=...      # Claude Code
export OPENAI_API_KEY=...         # Codex
```

### C. Copy existing credentials from the user's current machine
Fastest if they're already logged in locally. **Never print the secrets** — pipe
straight to the box and `chmod 600`. See `09-migration.md` for the full version.
- **Codex** stores a single file: `~/.codex/auth.json`
  ```bash
  cat ~/.codex/auth.json | ssh <host> 'umask 077; mkdir -p ~/.codex && cat > ~/.codex/auth.json'
  ```
- **Claude Code**: on Linux it's `~/.claude/.credentials.json`; on **macOS it's in
  the Keychain** (service `Claude Code-credentials`):
  ```bash
  # from the Mac — pipes the secret directly, never displayed:
  security find-generic-password -w -s "Claude Code-credentials" -a "$USER" \
    | ssh <host> 'umask 077; mkdir -p ~/.claude && cat > ~/.claude/.credentials.json'
  ```
  (The Keychain may pop a dialog the first time — the user clicks *Always Allow*.)

## Verify the logins actually work (don't trust "files exist")

```bash
ssh <user>@<host> 'bash -lc "
  claude --dangerously-skip-permissions -p \"Reply with one word: READY\";
  codex exec --dangerously-bypass-approvals-and-sandbox \"Reply with one word: READY\" 2>&1 | tail -3
"'
```
Both should print `READY`. `codex login status` should say "Logged in".

➡️ Next: `03-agent-environment.md`.
