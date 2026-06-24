#!/bin/sh
set -eu

: "${PROXY_USER:?PROXY_USER is required (set it in .env)}"
: "${PROXY_PASS:?PROXY_PASS is required (set it in .env)}"

# Generate the auth file from env (apr1/MD5 — supported by basic_ncsa_auth).
# Credentials never live in the image or the repo, only in .env at runtime.
htpasswd -cbm /etc/squid/passwd "$PROXY_USER" "$PROXY_PASS"

# The log dir is bind-mounted from the host (root-owned); let squid write to it.
chown -R proxy:proxy /var/log/squid 2>/dev/null || true

exec squid -N -d1 -f /etc/squid/squid.conf
