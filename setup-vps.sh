#!/bin/bash
# =============================================================
# DevSecOps Stand — VPS Setup Script
# Ubuntu 22.04 LTS
# =============================================================

set -e

echo "=== [1/5] Обновление системы ==="
apt update && apt upgrade -y
apt install -y curl wget git ufw fail2ban

echo "=== [2/5] Установка Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
tee /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker $USER

echo "=== [3/5] Настройка UFW firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Caddy redirect)
ufw allow 443/tcp   # HTTPS
ufw allow 2222/tcp  # Gitea SSH
ufw --force enable

echo "=== [4/5] Настройка Fail2ban ==="
systemctl enable fail2ban
systemctl start fail2ban

echo "=== [5/5] Клонирование и запуск ==="
git clone https://github.com/byemoto/devsecops-stand.git /opt/devsecops-stand
cd /opt/devsecops-stand
cp .env.example .env

echo ""
echo "=== ГОТОВО ==="
echo ""
echo "Следующие шаги:"
echo "1. Настроить DNS: *.security-stand.space → IP VPS"
echo "2. Заполнить .env значениями"
echo "3. Собрать Caddy: docker build -t caddy-coraza:latest ./caddy/"
echo "4. Запустить: docker compose up -d"
echo "5. Создать OAuth приложение в Gitea для Woodpecker"
echo "6. Настроить Authentik (создать flows, providers, applications)"
