#!/usr/bin/env bash
# VPSmaxxing — user-level sshd on a managed macOS laptop (NO admin needed).
# Gives the VPS reverse access (ssh/rsync/sftp/git) to your laptop, bound to your
# Tailscale IP only. Also installs a persistence guard + a kill switch.
#
# Usage:
#   VPS_PUBKEY="ssh-ed25519 AAAA... ai-vps->mac" TS_IP="100.x.y.z" bash mac-user-sshd.sh
#
#   VPS_PUBKEY  the VPS's public key (get it: ssh ai-vps 'cat ~/.ssh/id_ed25519.pub')  REQUIRED
#   TS_IP       this laptop's Tailscale IP (tailscale ip -4). Default 0.0.0.0 (less private).
#   PORT        listen port (default 2222)
set -euo pipefail
: "${VPS_PUBKEY:?set VPS_PUBKEY to the VPS public key}"
TS_IP="${TS_IP:-0.0.0.0}"; PORT="${PORT:-2222}"
mkdir -p ~/.ssh ~/.local/bin; chmod 700 ~/.ssh

[ -f ~/.ssh/mac_hostkey ] || ssh-keygen -t ed25519 -f ~/.ssh/mac_hostkey -N "" -C mac-user-sshd
chmod 600 ~/.ssh/mac_hostkey
cat > ~/.ssh/sshd_user_config <<EOF
Port $PORT
ListenAddress $TS_IP
HostKey $HOME/.ssh/mac_hostkey
PidFile $HOME/.ssh/sshd_user.pid
AuthorizedKeysFile $HOME/.ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
Subsystem sftp /usr/libexec/sftp-server
EOF
touch ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys
grep -q "vpsmaxxing" ~/.ssh/authorized_keys || echo "$VPS_PUBKEY vpsmaxxing" >> ~/.ssh/authorized_keys

# idempotent starter (respects disable flag; no admin, no LaunchAgent)
cat > ~/.local/bin/mac-vps-server <<'EOF'
#!/usr/bin/env bash
[ -f "$HOME/.ssh/.vps-access-disabled" ] && exit 0
lsof -nP -iTCP:2222 -sTCP:LISTEN >/dev/null 2>&1 && exit 0
/usr/sbin/sshd -f "$HOME/.ssh/sshd_user_config" -E "$HOME/.ssh/sshd_user.log" 2>/dev/null
EOF
chmod +x ~/.local/bin/mac-vps-server

# kill switch + re-enable (flag-based)
cat > ~/.local/bin/revoke-vps-access <<'EOF'
#!/usr/bin/env bash
touch "$HOME/.ssh/.vps-access-disabled"; pkill -f sshd_user_config 2>/dev/null
sed -i '' 's/^\(.*vpsmaxxing\)$/#REVOKED \1/' "$HOME/.ssh/authorized_keys" 2>/dev/null || true
echo "VPS access REVOKED. Re-enable: enable-vps-access"
EOF
chmod +x ~/.local/bin/revoke-vps-access
cat > ~/.local/bin/enable-vps-access <<'EOF'
#!/usr/bin/env bash
rm -f "$HOME/.ssh/.vps-access-disabled"
sed -i '' 's/^#REVOKED \(.*vpsmaxxing\)$/\1/' "$HOME/.ssh/authorized_keys" 2>/dev/null || true
"$HOME/.local/bin/mac-vps-server"; sleep 1
lsof -nP -iTCP:2222 -sTCP:LISTEN >/dev/null 2>&1 && echo "VPS access ENABLED (:2222)" || echo "key on; sshd starting…"
EOF
chmod +x ~/.local/bin/enable-vps-access

# persistence: a guard in the shell rc (MDM blocks LaunchAgents; cron needs FDA)
RC="$HOME/.zshrc"
grep -q '.local/bin' "$RC" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
grep -q 'mac-vps-server' "$RC" 2>/dev/null || \
  echo 'command -v mac-vps-server >/dev/null 2>&1 && mac-vps-server >/dev/null 2>&1' >> "$RC"

~/.local/bin/mac-vps-server; sleep 1
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "✅ user sshd listening on $TS_IP:$PORT"
else
  echo "⚠️  not listening — check ~/.ssh/sshd_user.log"
fi
cat <<EOF

On the VPS, add to ~/.ssh/config:
  Host mac
      HostName $TS_IP
      Port $PORT
      User $USER
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking accept-new
Then from the VPS:  ssh mac 'hostname && ls ~'
macOS TCC note: to read ~/Desktop ~/Documents ~/Downloads over ssh, grant Full Disk
Access to /usr/libexec/sshd-keygen-wrapper (System Settings → Privacy & Security).
EOF
