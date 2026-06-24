# secure-docker-squid

A hardened **Squid forward proxy** in Docker — one standard you can deploy to any
server in a couple of minutes. Security is baked into the image, credentials live
only in a local `.env`, and a single script wires up brute-force protection and log
rotation on the host.

> Built for a fleet of VPSes: clone, set credentials, `up`. Every server ends up
> byte-for-byte identical — no per-host hand-editing, no config drift.

---

## Features

- **Authentication required** — Basic auth, no anonymous use.
- **CONNECT restricted to ports 80/443** — a leaked password can only be used for
  ordinary web browsing. It cannot relay spam (`:25`), reach SSH/databases, or
  port-scan from your server.
- **No caching, no identity leaks** — `cache deny all`, `forwarded_for off`, `via off`.
- **Secrets stay out of git** — credentials are read from `.env` (git-ignored) and
  turned into the auth file at container start. Nothing sensitive is ever committed.
- **Brute-force protection + log rotation** — one-shot `host-setup.sh` installs a
  fail2ban jail and a logrotate policy.
- **Reproducible** — fixed image + config; the same artifact runs everywhere.

---

## Quick start

```bash
git clone https://github.com/pohape/secure-docker-squid.git
cd secure-docker-squid

cp .env.example .env
$EDITOR .env          # set PROXY_USER / PROXY_PASS (shared across servers) + PROXY_PORT
chmod 600 .env

./up.sh               # build the image and start the container
./host-setup.sh       # one-time: fail2ban jail + log rotation (run after up.sh)
```

The proxy then listens on `PROXY_PORT` (default `3128`) on all interfaces.

---

## Configuration

`.env` (copied from `.env.example`):

| Variable | Description |
|----------|-------------|
| `PROXY_USER` | Proxy login (use the same value on every server). |
| `PROXY_PASS` | Proxy password — use a long random string. |
| `PROXY_PORT` | Host port to expose (default `3128`). |

To rotate credentials: edit `.env`, then run `./up.sh` again — the auth file is
regenerated on start.

---

## Test it

```bash
# allowed — normal web, with valid credentials
curl -x "http://USER:PASS@SERVER:3128" -I http://example.com     # 200/3xx
curl -x "http://USER:PASS@SERVER:3128" -I https://example.com    # 200/3xx

# rejected — wrong credentials
curl -x "http://USER:wrong@SERVER:3128" -I http://example.com    # 407

# blocked — CONNECT to anything but :443
curl -x "http://USER:PASS@SERVER:3128" -I https://example.com:25 # blocked
```

---

## Use it in Chrome

Point Chrome at `SERVER:3128` (system proxy settings or a PAC file). Chrome will
prompt for the proxy username and password. Only ports 80/443 are proxied, which
covers normal browsing.

---

## Operations

```bash
docker logs -f squid            # live logs (also written to ./log/)
./down.sh                       # stop and remove the container
docker compose up -d --build    # apply changes to config or Dockerfile
```

`host-setup.sh` installs:

- **fail2ban** jail `squid` — bans IPs that repeatedly fail proxy auth (HTTP 407).
  It uses the `DOCKER-USER` iptables chain, which is required to filter traffic to a
  published container port (a plain `INPUT` jail would not catch it).
- **logrotate** for `./log/*.log` so the access/cache logs never grow unbounded.

---

## Security notes

- Basic-auth credentials are sent to the proxy on every request. The proxy port is
  plain HTTP, so on an **untrusted network the credentials are sniffable in transit**.
  Mitigations in place — a strong password and the 80/443 CONNECT restriction — limit
  the damage, but do not prevent interception.
- For full protection, terminate **TLS** in front of the proxy (so Chrome connects
  over HTTPS) or reach it over a **VPN/SSH tunnel**. TLS on the proxy port requires a
  publicly trusted certificate (e.g. Let's Encrypt for the server's hostname) and a
  client configured for an HTTPS proxy (via PAC or `--proxy-server=https://`).
- Keep the image up to date: `docker compose build --pull && docker compose up -d`.

---

## Repository layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Service definition: port mapping, log bind-mount. |
| `squid/Dockerfile` | Image: `ubuntu/squid` + `apache2-utils`. |
| `squid/entrypoint.sh` | Builds the auth file from `.env`, then launches Squid. |
| `squid/squid.conf` | Hardened config: auth + CONNECT 80/443 only. |
| `up.sh` / `down.sh` | Start / stop. |
| `host-setup.sh` | fail2ban jail (`DOCKER-USER`) + logrotate. |
| `.env.example` | Credential template (no real secrets). |
