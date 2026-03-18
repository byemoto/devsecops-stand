# DevSecOps Home Lab

Личный стенд для практики DevSecOps.

## Стенд

VPS на Ubuntu 22.04, 8GB RAM. Docker Compose, Caddy как reverse proxy с автоматическим TLS.

| Сервис | URL | Назначение |
|--------|-----|------------|
| Gitea | [git.security-stand.space](https://git.security-stand.space) | Git сервер |
| Woodpecker CI | [ci.security-stand.space](https://ci.security-stand.space) | CI/CD pipeline |
| Authentik | [auth.security-stand.space](https://auth.security-stand.space) | OAuth2/OIDC/PKCE/MFA |
| DefectDojo | [dojo.security-stand.space](https://dojo.security-stand.space) | Vulnerability management |
| Grafana | [grafana.security-stand.space](https://grafana.security-stand.space) | Мониторинг |
| n8n | [n8n.security-stand.space](https://n8n.security-stand.space) | AI автоматизация |
| Juice Shop | [app.security-stand.space](https://app.security-stand.space) | Мишень для тестов |

## Защита стенда

```
Облачный firewall провайдера   — L3/L4 фильтрация
CrowdSec                       — поведенческий IPS
Caddy + Coraza WAF             — L7, блокировка XSS/SQLi
Falco                          — runtime security на уровне ядра
Authentik                      — SSO для всех сервисов
```

Coraza WAF стоит перед Juice Shop. Можно проверить:

```bash
# XSS — 403
curl "https://app.security-stand.space/?q=<script>alert(1)</script>"

# SQLi — 403
curl "https://app.security-stand.space/?q=union+select+1,2,3"
```

## Pipeline

```
push в Gitea
    │
    ▼
Woodpecker CI
    ├── Gitleaks     — ищет секреты в коде
    ├── Semgrep      — SAST
    ├── Trivy        — уязвимости в зависимостях
    ├── n8n → Claude API → анализ находок с рекомендациями
    └── DefectDojo   — загрузка результатов
```

## Тестовое приложение

[vulnerable-app](https://git.security-stand.space/byemoto/vulnerable-app) — Python с намеренными уязвимостями: SQL injection, command injection, hardcoded secrets, небезопасная десериализация.

Semgrep находит 4 blocking findings, Gitleaks — hardcoded API key в строке 5. После сканирования Claude анализирует находки и возвращает приоритизированный список с примерами исправления (P0/P1/P2). Результаты уходят в DefectDojo.

Часть уязвимостей которые Semgrep находит в коде — это те же техники MITRE ATT&CK которые описаны в [soc-detection-rules](https://github.com/byemoto/soc-detection-rules). Полезно смотреть на одну проблему с двух сторон.

## Структура репозитория

```
├── docker-compose.yml
├── docker-compose.vps.yml
├── setup-vps.sh
├── .env.vps.example
├── caddy/
│   ├── Caddyfile               # reverse proxy + Coraza WAF
│   └── Dockerfile              # Caddy с Coraza плагином
├── crowdsec/acquis.yaml
├── grafana/dashboards/
├── prometheus/prometheus.yml
├── loki/
├── falco/falco_rules.yaml
└── scripts/
    └── upload_to_defectdojo.py
```

## Запуск локально

```bash
git clone git@github.com:byemoto/devsecops-stand.git
cd devsecops-stand
cp .env.vps.example .env
# заполнить .env своими значениями
docker compose up -d
```

## Другие репозитории

**[soc-detection-rules](https://github.com/byemoto/soc-detection-rules)** — detection rules для Sigma, MaxPatrol и R-Vision SIEM. Правила основаны на разборе реальных атак, в том числе с HTB машин.

**[htb-practice](https://github.com/byemoto/htb-practice)** (private) — разборы HackTheBox машин с упором на Blue Team: что остаётся в логах, какие IOC можно вытащить.
