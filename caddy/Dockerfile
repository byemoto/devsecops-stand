FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/corazawaf/coraza-caddy/v2 \
    --with github.com/hslatman/caddy-crowdsec-bouncer
FROM caddy:2-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
