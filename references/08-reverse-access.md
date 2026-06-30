# 08 — Reverse access: let the VPS reach your laptop's files

By default access is one-way (laptop → VPS). If you want the VPS (and its agents)
to clone/copy/read/**delete** files on your laptop, you need the reverse path.

## ⚠️ Decide the scope first (ask the user)
VPS agents often run in **YOLO mode**, so anything the VPS can reach, an auto-running
agent can too — including deleting laptop files. Offer:
- **Full home** — simplest, matches "do everything"; biggest blast radius.
- **Shared folder only** — sandbox the VPS to e.g. `~/vps-share` (SFTP chroot or a
  forced-command key); safest, but file-transfer only (no remote shell/git there).
- **None** — keep the VPS isolated; use laptop-initiated push/pull helpers instead.

Always set up the **kill switch** (below) regardless of scope.

## Path A — laptop with admin (normal personal machine)
1. Enable the laptop's SSH server:
   - macOS: System Settings → General → Sharing → **Remote Login** ON (or
     `sudo systemsetup -setremotelogin on`).
   - Linux: `sudo systemctl enable --now ssh`/`sshd`.
2. Generate a key on the VPS and authorize it on the laptop:
   ```bash
   ssh ai-vps 'test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519; cat ~/.ssh/id_ed25519.pub'
   # paste that line into the laptop's ~/.ssh/authorized_keys (chmod 700 ~/.ssh; chmod 600 authorized_keys)
   ```
3. Add a `mac` (or `laptop`) alias in the VPS `~/.ssh/config` pointing at the
   laptop's **Tailscale IP**. Done.

## Path B — managed / work laptop (NO admin) ⭐ the hard-won one
Work laptops usually **block the system SSH server** (`systemsetup` is gated behind
Full Disk Access; MDM blocks LaunchAgents; cron needs FDA). Run a **user-level
sshd** instead — entirely in your home dir, no admin, bound to the Tailscale IP:

```bash
# on the laptop (macOS shown; Linux paths differ slightly)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/mac_hostkey -N ""        # user-owned host key
cat > ~/.ssh/sshd_user_config <<EOF
Port 2222
ListenAddress <LAPTOP_TAILSCALE_IP>     # tailnet-only; or 0.0.0.0 if you must
HostKey $HOME/.ssh/mac_hostkey
PidFile $HOME/.ssh/sshd_user.pid
AuthorizedKeysFile $HOME/.ssh/authorized_keys
PasswordAuthentication no
UsePAM no
Subsystem sftp /usr/libexec/sftp-server
EOF
# authorize the VPS key, then start (non-root sshd works for command/sftp/rsync):
echo '<VPS_PUBKEY>' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
/usr/sbin/sshd -f ~/.ssh/sshd_user_config -E ~/.ssh/sshd_user.log
lsof -nP -iTCP:2222 -sTCP:LISTEN     # confirm listening
```
On the VPS, the `mac` alias uses **Port 2222** and the Tailscale IP.

**Persistence without admin** (LaunchAgents/cron are blocked): a guard in the
laptop shell rc that (re)starts it when you open a terminal:
```bash
# ~/.zshrc (or ~/.bashrc)
command -v mac-vps-server >/dev/null 2>&1 && mac-vps-server >/dev/null 2>&1
```
where `~/.local/bin/mac-vps-server` is an idempotent starter (exits if a disable
flag exists or it's already listening, else launches `/usr/sbin/sshd ...`). See
`scripts/mac-user-sshd.sh` for the full, ready version.

> Non-root sshd notes: interactive PTYs may not allocate as non-root, but
> `ssh mac 'cmd'`, **rsync, sftp, and git-over-ssh all work** — which is what file
> access needs. Bind to the Tailscale IP so it's never exposed to the work network.

## Kill switch (always install)
```bash
revoke-vps-access     # stop sshd + comment out the VPS key + set a disable flag
enable-vps-access     # undo
```
(Flag file `~/.ssh/.vps-access-disabled`; the rc guard respects it.) See
`scripts/mac-user-sshd.sh`.

## Use it (from the VPS / its agents)
```bash
ssh mac 'ls ~/Projects'
rsync -av mac:Projects/foo/ ~/work/foo/      # pull
rsync -av ~/work/foo/ mac:Projects/foo/      # push
git clone mac:Projects/foo                   # clone a local repo over ssh
ssh mac 'rm ~/path/thing'                    # yes, delete
```

## macOS TCC caveat
Even over SSH, `~/Desktop`, `~/Documents`, `~/Downloads` are blocked by macOS
privacy (TCC) until you grant **Full Disk Access** to `/usr/libexec/sshd-keygen-wrapper`
(System Settings → Privacy & Security → Full Disk Access). Other dirs (e.g.
`~/Projects`) work without it.

➡️ Next: `09-migration.md`.
