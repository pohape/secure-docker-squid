#!/bin/sh
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
    echo "ERROR: .env missing. Run: cp .env.example .env && edit PROXY_USER/PROXY_PASS"
    exit 1
fi

docker compose up -d --build
echo "squid is up on host port ${PROXY_PORT:-$(grep -E '^PROXY_PORT=' .env | cut -d= -f2)}"
