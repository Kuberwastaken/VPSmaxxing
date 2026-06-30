# 10 — Automatic two-way sync

Neither Claude Code nor Codex syncs history across machines natively (CC indexes
sessions by absolute path; Codex cross-device sync is an open feature request). So
we DIY it with a small cron-driven two-way rsync.

## Key insight: drive it from the VPS
A managed laptop usually **can't schedule jobs** (cron needs Full Disk Access;
MDM blocks LaunchAgents). The VPS can — and it already has SSH to the laptop. So put
the **cron on the VPS** and have it rsync both directions with the laptop. The
laptop only needs its (user-level) sshd up — which the rc guard handles.

## The sync script (`~/.local/bin/agent-sync` on the VPS)
```bash
#!/usr/bin/env bash
# Two-way (additive, newer-wins, no deletes) sync of agent state, VPS <-> laptop.
exec 9>/tmp/agent-sync.lock; flock -n 9 || exit 0          # no overlap
log(){ echo "[$(date '+%F %T')] $*"; }
ssh -n -o ConnectTimeout=8 -o BatchMode=yes mac true 2>/dev/null || { log "laptop unreachable, skip"; exit 0; }
sync_dir(){  ssh -n mac "mkdir -p \"$2\"" 2>/dev/null; mkdir -p "$1"
             rsync -azu --timeout=30 mac:"$2/" "$1/" 2>/dev/null
             rsync -azu --timeout=30 "$1/" mac:"$2/" 2>/dev/null; }
sync_file(){ rsync -azu --timeout=30 mac:"$2" "$1" 2>/dev/null
             rsync -azu --timeout=30 "$1" mac:"$2" 2>/dev/null; }
H=$HOME
sync_dir  "$H/.claude/skills"                          ".claude/skills"
sync_dir  "$H/.claude/projects/-home-<vpsuser>/memory" ".claude/projects/-Users-<you>/memory"
sync_dir  "$H/.claude/projects"                         ".claude/projects"
sync_file "$H/.claude/history.jsonl"                    ".claude/history.jsonl"
sync_dir  "$H/.codex/skills"                            ".codex/skills"
sync_dir  "$H/.codex/sessions"                          ".codex/sessions"
sync_file "$H/.codex/memories_1.sqlite"                 ".codex/memories_1.sqlite"
sync_file "$H/.codex/session_index.jsonl"             ".codex/session_index.jsonl"
log "sync complete"
```
`chmod +x`. (`<vpsuser>`/`<you>` = the encoded home dirs from `09`.)

## The cron (on the VPS)
```bash
sudo dnf install -y cronie && sudo systemctl enable --now crond   # Amazon Linux
# (Ubuntu/Debian: cron is usually preinstalled & running)
( crontab -l 2>/dev/null | grep -v agent-sync; \
  echo "*/5 * * * * $HOME/.local/bin/agent-sync >> $HOME/.agent-sync.log 2>&1" ) | crontab -
```
Every 5 minutes. When the laptop is asleep/unreachable, the run no-ops and retries.

## What's synced vs not
- **Synced:** skills, Claude memory + transcripts + history, Codex sessions +
  memories. All uniquely-named/append-mostly, so additive two-way is safe.
- **NOT synced:** `CLAUDE.md`/`AGENTS.md`/`settings.json` — they were *merged* once
  (VPS briefing + your global rules); auto-syncing would clobber the merge.
- **No deletes propagate** (`rsync` without `--delete`) — favors safety; clean up
  both sides manually if needed. Live-sqlite is copied newer-wins (tiny corruption
  risk; fine in practice).

## Verify it moves files both ways
```bash
echo hi > ~/.claude/projects/-Users-<you>/memory/_t_mac.md          # laptop marker
ssh ai-vps 'echo hi > ~/.claude/projects/-home-<vpsuser>/memory/_t_vps.md; ~/.local/bin/agent-sync; ls ~/.claude/projects/-home-<vpsuser>/memory | grep _t_'
ls ~/.claude/projects/-Users-<you>/memory | grep _t_                # both markers present?
# cleanup both sides afterward
```

## Want cloud-backed resume instead?
If you'd rather have full session **resume** follow you across machines (not just
per-dir `claude --continue`), use a tool that remaps `$HOME` during sync —
[claude-sync](https://github.com/tawanorg/claude-sync) (Cloudflare R2, E2E) or
[claude-code-sync](https://github.com/porkchop/claude-code-sync) (git). This DIY
rsync is simpler and dependency-free; pick based on whether you need resume.

➡️ See `troubleshooting.md` for every trap this setup hit.
