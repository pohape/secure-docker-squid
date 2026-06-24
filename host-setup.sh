#!/bin/sh
# One-time host setup: fail2ban jail (brute-force protection) + log rotation.
# Run AFTER ./up.sh (so log/access.log exists). Safe to re-run.
set -eu
cd "$(dirname "$0")"
REPO="$(pwd)"
LOGDIR="$REPO/log"

# --- fail2ban ---
if ! command -v fail2ban-client >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y fail2ban
fi

# Ban IPs that repeatedly fail proxy auth (HTTP 407).
# chain=DOCKER-USER is REQUIRED: traffic to a published container port is
# filtered in FORWARD/DOCKER-USER, not INPUT — an INPUT jail would NOT block it.
sudo tee /etc/fail2ban/jail.d/squid.local >/dev/null <<EOF
[squid]
enabled  = true
port     = 3128
protocol = tcp
filter   = squid
logpath  = $LOGDIR/access.log
chain    = DOCKER-USER
maxretry = 5
findtime = 600
bantime  = 3600
EOF

sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

# --- log rotation (access.log/cache.log grow unbounded otherwise) ---
sudo tee /etc/logrotate.d/secure-docker-squid >/dev/null <<EOF
$LOGDIR/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
EOF

echo "host-setup done: fail2ban (DOCKER-USER) + logrotate"
sudo fail2ban-client status squid || true
