# secure-docker-squid

A hardened, one-standard Squid forward-proxy in Docker. Clone it on any server,
set credentials in `.env`, run `./up.sh` — every server ends up identical.

## Why this setup

- **One standard, no drift** — same image and config on every VPS (no per-host hand-editing).
- **Security baked into the image**, not bolted on per server:
  - Basic auth required (no anonymous use).
  - **CONNECT restricted to 80/443** — a leaked password can't be used to relay
    spam (:25), reach databases/SSH, or port-scan from your server.
  - No caching; client identity not leaked (`forwarded_for off`, `via off`).
- **Credentials only in `.env`** (gitignored) — generated into the auth file at
  container start. Nothing secret is ever committed (this repo is public).
- **fail2ban + log rotation** via a one-shot host script.

> **Security note:** Basic-auth credentials are sent at connection time. The proxy
> port is plain HTTP, so on untrusted networks the credentials are sniffable in
> transit. For full protection add TLS on the proxy port (see *Optional: TLS*) or
> reach the proxy over a VPN/SSH tunnel.

## Prerequisites

- Ubuntu with sudo, Docker Engine + Compose v2.

## Deploy

```bash
git clone git@github.com:pohape/secure-docker-squid.git
cd secure-docker-squid
cp .env.example .env
vim .env            # set PROXY_USER / PROXY_PASS (same on all servers) and PROXY_PORT
chmod 600 .env
./up.sh             # build + start the container
./host-setup.sh     # one-time: fail2ban jail (DOCKER-USER) + logrotate
```

The proxy listens on `PROXY_PORT` (default `3128`) on all interfaces.

## Test

```bash
# allowed: normal web (auth required)
curl -x "http://USER:PASS@SERVER_IP:3128" -I http://example.com      # 200/3xx
curl -x "http://USER:PASS@SERVER_IP:3128" -I https://example.com     # 200/3xx
# rejected: wrong creds
curl -x "http://USER:wrong@SERVER_IP:3128" -I http://example.com     # 407
# blocked by CONNECT restriction: anything but :443
curl -x "http://USER:PASS@SERVER_IP:3128" -I https://example.com:25  # blocked
```

## Use in Chrome

Point Chrome at `SERVER_IP:3128` (system proxy or a PAC file); it will prompt for
the proxy username/password. Only ports 80/443 are proxied, which covers normal
browsing.

## Operations

```bash
docker logs -f squid          # live logs (also in ./log/)
./down.sh                     # stop
docker compose up -d --build  # update after editing config/Dockerfile
# rotate creds: edit .env, then ./up.sh (recreates the auth file)
```

## Optional: TLS on the proxy port

To stop sending Basic credentials in cleartext, terminate TLS on the proxy port so
Chrome connects to it over HTTPS:

1. Provide a cert (Let's Encrypt for a hostname pointing at the server, or self-signed)
   into `./ssl/squid.pem`.
2. Add an `https_port` to `squid/squid.conf` and mount `./ssl`, then rebuild.
3. Configure Chrome to use the proxy over `https://` (via PAC or a Secure Web Proxy).

(Left optional: many clients need PAC/flags for HTTPS proxies — enable per need.)

## Files

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | service definition, port, log bind-mount |
| `squid/Dockerfile` | image (ubuntu/squid + apache2-utils) |
| `squid/entrypoint.sh` | generates auth file from `.env`, launches squid |
| `squid/squid.conf` | hardened config (auth + CONNECT 80/443) |
| `up.sh` / `down.sh` | start / stop |
| `host-setup.sh` | fail2ban (DOCKER-USER chain) + logrotate |
| `.env.example` | credential template (no real secrets) |
