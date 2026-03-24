#!/bin/bash
# =============================================================
# Egress filtering for Docker containers
# Blocks internet access for internal-only containers
# =============================================================

DOCKER_SUBNET="172.18.0.0/16"

# Контейнеры БЕЗ доступа в интернет (только внутренняя сеть)
BLOCKED_CONTAINERS=(
  "gitea-db"
  "authentik-db"
  "authentik-redis"
  "defectdojo-db"
  "defectdojo-redis"
  "prometheus"
  "loki"
  "promtail"
  "falco"
  "cadvisor"
  "defectdojo-uwsgi"
  "defectdojo"
)

echo "=== Applying egress filters ==="

for CONTAINER in "${BLOCKED_CONTAINERS[@]}"; do
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER" 2>/dev/null)
  if [ -n "$IP" ]; then
    # Разрешить трафик внутри Docker сетей
    iptables -C DOCKER-USER -s "$IP" -d "$DOCKER_SUBNET" -j ACCEPT 2>/dev/null || \
    iptables -I DOCKER-USER -s "$IP" -d "$DOCKER_SUBNET" -j ACCEPT
    
    # Заблокировать всё остальное (интернет)
    iptables -C DOCKER-USER -s "$IP" -j DROP 2>/dev/null || \
    iptables -A DOCKER-USER -s "$IP" -j DROP
    
    echo "  ✓ $CONTAINER ($IP) — internet blocked"
  else
    echo "  ✗ $CONTAINER — not found"
  fi
done

echo ""
echo "=== Containers with internet access ==="
echo "  Caddy        — Let's Encrypt, CrowdSec hub"
echo "  CrowdSec     — CrowdSec hub updates"
echo "  n8n          — Anthropic API"
echo "  Gitea        — webhook delivery"
echo "  Grafana      — plugin updates"
echo "  Authentik    — external providers"
echo "  Woodpecker   — Docker image pulls"
echo ""
echo "=== Done ==="
