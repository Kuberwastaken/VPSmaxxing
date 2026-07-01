# 11 — Session hand-off (move a live session between machines)

Auto-sync (`10`) copies transcript **files** both ways — but that alone does **not**
let you resume a laptop conversation on the VPS. Claude Code keys every session by
the **absolute working directory**: a chat in `/Users/you/Projects/x` is stored under
`~/.claude/projects/-Users-you-Projects-x/`. On the VPS your home is
`/home/<vpsuser>`, so no directory there ever encodes to that folder — and
`claude --continue` (which is locked to the current dir's project) shows **nothing**,
even though the file is sitting right there.

## Key insight: make the paths identical, and resume is free
Claude derives the project folder from the **canonical** cwd (`process.cwd()`, which
resolves symlinks). So if the VPS exposes your projects at the **same absolute path**
your laptop uses, the folder key is identical on both machines and a synced transcript
resumes natively — no path rewriting, no cloud service.

We do it with a real directory + a symlink:

```
# on the VPS (real dir at the laptop's path; ~/work becomes a symlink to it)
sudo mkdir -p /Users/you && sudo chown "$(id -un)":"$(id -gn)" /Users/you
mv ~/work /Users/you/Projects        # same-filesystem rename: inode-preserving,
ln -s /Users/you/Projects ~/work     #   running agents are NOT disturbed
```

Now `cd ~/work/x` (or `/Users/you/Projects/x`) resolves to `/Users/you/Projects/x`
on **both** machines → same key `-Users-you-Projects-x` → `--continue`/`--resume`
Just Work across the two. It's reboot-safe (a real dir + a real symlink; no fstab).

> Why the `mv` is safe even with live agents: on one filesystem it's a `rename(2)`,
> so inodes don't move. A running agent keeps its open transcript fd and its
> inode-tracked cwd; only the printed path string changes. Verify with
> `pgrep -af 'claude|codex'` before/after — the PID set is identical.

## Set it up (one command)
```bash
# ON THE VPS, from the skill's scripts/ dir:
MAC_HOME=/Users/you bash setup-handoff.sh
```
It creates the symmetric root, patches `claudemaxxing` to pre-trust the **canonical**
cwd (`pwd -P`, else the trust entry won't match after the symlink), writes
`~/.config/vpsmaxxing/handoff.env`, and installs `handoff` + `resume-here` on the VPS
**and** the laptop (over the reverse SSH from `08`; prints manual steps if it can't
reach the laptop). Keep repos under `/Users/you/Projects` on **both** machines with
matching folder names.

## Use it
```bash
# laptop -> VPS: sync the session up and resume it on the VPS in tmux 'ho-<project>'
handoff marketing-outbound
ssh ai-vps -t "tmux attach -t ho-marketing-outbound"

# VPS -> laptop: sync down and print the pickup command
handoff marketing-outbound       # then on the laptop:
resume-here marketing-outbound
```
- `handoff [project] [session-id] [-f] [-n]` — default project = current dir, default
  session = most recent. `-n` dry-run; `-f` overrides the 20s "looks-active" guard.
- `resume-here [project] [session-id]` — pull latest from the other machine + resume.

## Two rules that keep it clean
- **Hand off at a turn boundary (idle).** You move the *conversation* (its transcript
  is the whole state), not a live in-flight turn — you can't teleport a running
  process, so let the current turn finish first.
- **Never run the same session live on both machines at once.** The sync is
  newer-wins with no deletes; two live copies would fork into divergent branches.

## Just want to browse, not move?
Resume is cwd-scoped, but the picker can widen: `claude --resume`, then **`Ctrl+A`**
lists **all projects on the machine** (incl. every synced folder) — `Ctrl+W` widens to
the current repo's worktrees. And for *searching* across every session of **both
tools on both machines**, register the `reference` MCP (`12`) — that's the companion
to hand-off: hand-off *moves* one session, reference *finds* any of them.

## Verify (full round-trip)
```bash
# laptop: seed a session with a codeword
mkdir -p /Users/you/Projects/_ho_test && cd $_
claude --dangerously-skip-permissions -p "Remember codeword BANANA-7. Reply OK"
# hand it off, then on the VPS resume and ask for the codeword:
handoff _ho_test
ssh ai-vps "cd /Users/you/Projects/_ho_test && claude --dangerously-skip-permissions \
  --resume \$(ls -t ~/.claude/projects/-Users-you-Projects--ho-test/*.jsonl | head -1 | xargs -n1 basename | sed 's/.jsonl//') \
  -p 'what was the codeword?'"     # -> BANANA-7  ==> context crossed machines
# cleanup /Users/you/Projects/_ho_test + its projects/ folder on BOTH sides
```

➡️ Traps (empty `--continue`, `$PWD` vs `pwd -P`, split-brain) are in
`troubleshooting.md`.
