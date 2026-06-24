FROM ubuntu/squid:latest

# htpasswd (apache2-utils) to generate the auth file at startup
RUN apt-get update \
    && apt-get install -y --no-install-recommends apache2-utils \
    && rm -rf /var/lib/apt/lists/*

COPY squid.conf /etc/squid/squid.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
