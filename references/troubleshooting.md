# Troubleshooting — the traps that actually cost hours

Every item below was hit for real during the setup this skill is based on. Check
here **before** improvising.

## OS / provisioning

**`ec2-user` means Amazon Linux, not Ubuntu.** The default AWS AMI logs in as
`ec2-user` (Amazon Linux 2023), `ubuntu` = Ubuntu. You **cannot convert** one to the
other in place — if someone needs Ubuntu, they must launch a new Ubuntu instance.
Always detect: `. /etc/os-release; echo $ID` (`amzn`/`ubuntu`/`debian`).

**`dnf install curl` fails on Amazon Linux 2023.** It conflicts with the preinstalled
`curl-minimal`. `curl` is already there — just don't install it.

**Node is the wrong version after installing `nodejs22` (AL2023).** AL2023 ships
parallel `nodejsXX` via `alternatives`. Installing the `npm` package can pull in the
default `nodejs` (v18), and with both at equal priority `alternatives` auto-picks
18, so `node -v` shows 18 even though 22 is installed. **Fix:**
`sudo alternatives --set node /usr/bin/node-22` (then `hash -r`).

**`npm i -g` wants sudo.** Set a user prefix instead:
`npm config set prefix ~/.npm-global` + add `~/.npm-global/bin` to PATH. Now global
installs (pnpm, claude, codex) need no sudo and live in your home.

**`docker` permission denied right after install.** Adding yourself to the `docker`
group only takes effect on a **new login session**. Reconnect (or `newgrp docker`),
then `docker ps` works.

**`tmux: MISSING` immediately after installing it.** Stale PATH hash in that subshell.
It's installed — verify in a fresh shell. (`hash -r` clears it.)

**Codex won't install / wrong tool.** The package is **`@openai/codex`** (scoped).
The unscoped `codex` on npm is an unrelated 2012 project.

## GitHub CLI

**`gh` dnf install aborts (GPG / "saved in cache until next successful transaction").**
The GitHub dnf repo's key import can fail the transaction. Skip the repo — install
the **binary**: download `gh_<ver>_linux_amd64.tar.gz` from GitHub releases into
`~/.local/bin/gh`. Also `sudo rm -f /etc/yum.repos.d/gh-cli.repo` so the broken repo
doesn't break later `dnf` commands. (See `09-migration.md` for the one-liner.)

## Managed / work laptop (no admin) — the big one

**`sudo systemsetup -setremotelogin on` errors about Full Disk Access.** Apple gates
the `systemsetup` *command* behind FDA — but the service isn't. Use the **GUI toggle**
(System Settings → General → Sharing → Remote Login) or
`sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist`. If you
have **no admin at all**, you can't enable system Remote Login — use the **user-level
sshd** in `08-reverse-access.md` (Path B).

**Writing `~/Library/LaunchAgents/*.plist` → "permission denied".** MDM blocks user
LaunchAgents on many managed Macs. You can't use a LaunchAgent for persistence.
**Workaround:** a guard line in `~/.zshrc` that (re)starts your user service when you
open a terminal. Survives reboots because you open a terminal after logging in.

**cron doesn't run on the managed Mac.** macOS `cron` also needs Full Disk Access.
Don't schedule on the laptop at all — **drive scheduled work (auto-sync) from the
VPS via the VPS's cron**, reaching back to the laptop. (See `10-autosync.md`.)

## Tailscale

**`ssh ai-vps.<tailnet>.ts.net` → "could not resolve hostname".** The open-source
`tailscaled` (CLI, via `brew install tailscale`) often doesn't serve MagicDNS on
macOS. **Fix:** put the **Tailscale IP (`100.x.y.z`)** in `~/.ssh/config` `HostName`
— it always works once both nodes are up. The GUI app resolves MagicDNS fine.

**`brew install --cask tailscale` download 404s.** The cask's versioned `.pkg` URL
can lag a release. Use the **Mac App Store** Tailscale app, or `brew install
tailscale` (CLI formula) + `sudo tailscaled install-system-daemon`.

**`tailscale up` just hangs.** It blocks until you authorize in a browser. For
headless capture, run `sudo nohup tailscale up --ssh --hostname ai-vps
>/tmp/ts.log 2>&1 </dev/null &` then read the auth URL from `/tmp/ts.log`; the
daemon finishes the handshake once you approve.

## SSH / scripting

**Output truncates after the first `ssh mac '...'` inside an outer SSH heredoc.**
The inner `ssh` reads from **stdin** by default and swallows the rest of the heredoc.
**Fix:** use `ssh -n mac '...'` (or `</dev/null`) for every nested ssh.

**Writing scripts over SSH via nested heredocs.** Use **distinct quoted delimiters**
(`<<'REMOTE'` outer, `<<'SCRIPT_EOF'` to write the file, `<<'PY'` inside that). Quoted
delimiters pass content through literally so `$VARS`/backticks aren't expanded at the
wrong layer.

## Credentials / security

**Claude Code login isn't a file on macOS.** It's in the **Keychain**, service
`Claude Code-credentials`. Extract with `security find-generic-password -w -s "Claude
Code-credentials" -a "$USER"` and **pipe it straight to the VPS** (never print it).
First access may pop a Keychain dialog — click *Always Allow*.

**Don't paste private keys / tokens into a chat.** If it happens, treat the key as
compromised and **rotate it**. Pipe secrets device-to-device; `chmod 600` on landing.

**Reverse access = blast radius.** A YOLO agent on the VPS can reach whatever the VPS
can reach on your laptop, including deletes. Scope it (shared folder) and keep
`revoke-vps-access` handy.

## Cost

**Hourly clouds are a 24/7 trap.** AWS `m6a.2xlarge` (8 vCPU/32 GB) ≈ $0.35/hr ≈
**$252/mo if always on**. Either pick a **flat-rate** provider for an always-on box,
or **stop the instance when idle** on AWS/GCP/Azure (you then pay only for the disk).
Note: flat-rate VPS providers keep billing while powered off — snapshot + destroy to
actually stop paying.

## Sync / history

**Resume doesn't follow you across machines.** Claude Code indexes sessions by
absolute project path; Codex has no native cross-device sync. Use `claude
--continue` (latest session **in the current dir**) — simplest and matches the DIY
rsync model. For true cross-machine resume, use a `$HOME`-remapping sync tool
(claude-sync / claude-code-sync).

**Two-way rsync caveats.** This setup uses `rsync -azu` with **no `--delete`**:
deletions don't propagate (safety), newer-wins can drop one side's edit if the *same*
file was edited on both (rare for memory; uniquely-named session files never
collide), and a live sqlite copied mid-write has a tiny corruption risk (fine in
practice).
