#!/bin/bash
# =============================================================
# DevSecOps Stand — VPS Setup Script
# Ubuntu 22.04 LTS
# =============================================================

set -e

echo "=== [1/6] Обновление системы ==="
apt update && apt upgrade -y
apt install -y curl wget git ufw fail2ban

echo "=== [2/6] Установка Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
tee /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker $USER

echo "=== [3/6] Настройка UFW firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Caddy redirect)
ufw allow 443/tcp   # HTTPS
ufw allow 2222/tcp  # Gitea SSH
ufw --force enable

echo "=== [4/6] Настройка Fail2ban ==="
systemctl enable fail2ban
systemctl start fail2ban

echo "=== [5/6] Клонирование репозитория ==="
git clone git@github.com:byemoto/devsecops-stand.git /opt/devsecops-stand
cd /opt/devsecops-stand

echo "=== [6/6] Подготовка конфигов ==="
cp .env.vps.example .env
cp docker-compose.vps.yml docker-compose.yml
cp caddy/Caddyfile.vps caddy/Caddyfile

echo ""
echo "=== ГОТОВО ==="
echo ""
echo "Следующие шаги:"
echo "1. Настроить DNS записи для security-stand.space"
echo "2. Заполнить .env значениями"
echo "3. docker compose up -d gitea-db gitea"
echo "4. Создать OAuth приложение в Gitea"
echo "5. docker compose up -d"
echo ""
echo "DNS записи (добавить у регистратора):"
echo "  @ A <IP_VPS>"
echo "  * A <IP_VPS>"
