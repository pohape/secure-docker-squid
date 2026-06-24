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

# Extend the stock squid filter to also catch auth failures (407) and 401/511,
# not just 403 — repeated wrong-password attempts are what we mainly want to ban.
sudo tee /etc/fail2ban/filter.d/squid.local >/dev/null <<'EOF'
[Definition]
failregex = ^\s*\d+\s+<HOST>\s+[A-Z_]+/(401|403|407|511)\b
EOF

# Ban IPs that repeatedly fail proxy auth / hit denied ACLs.
# - chain=DOCKER-USER: traffic to a published container port is filtered in
#   FORWARD/DOCKER-USER, not INPUT — an INPUT jail would NOT block it.
# - backend=polling: always watch the access.log FILE (never the systemd
#   journal, which some distros default to and which has no squid data).
sudo tee /etc/fail2ban/jail.d/squid.local >/dev/null <<EOF
[squid]
enabled   = true
port      = 3128
protocol  = tcp
filter    = squid
backend   = polling
logpath   = $LOGDIR/access.log
chain     = DOCKER-USER
maxretry  = 5
findtime  = 600
bantime   = 3600
# Never ban localhost / private ranges / the Docker bridge gateway —
# only public attacker IPs should be banned.
ignoreip  = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
EOF

sudo systemctl enable fail2ban >/dev/null 2>&1 || true
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

echo "host-setup done: fail2ban (DOCKER-USER, polling, bans 401/403/407/511) + logrotate"
