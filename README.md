# DevSecOps Stand

Полноценный DevSecOps стенд на базе Docker Compose с CI/CD pipeline, WAF, IPS, SSO, vulnerability management и AI-анализом результатов сканирования.

**Live:** [security-stand.space](https://security-stand.space)

## Архитектура
```
                         ┌──────────────────────────────────────────┐
                         │            Caddy (Reverse Proxy)         │
                         │         TLS + Coraza WAF + CrowdSec     │
                         └──────┬───┬───┬───┬───┬───┬───┬──────────┘
                                │   │   │   │   │   │   │
                    ┌───────────┘   │   │   │   │   │   └───────────┐
                    ▼               ▼   ▼   ▼   ▼   ▼               ▼
                 Gitea          Authentik  CI  Dojo Grafana  n8n   Juice Shop
               (Git Server)     (SSO)    (WP) (DD) (Mon.)  (AI)   (Target)
                    │               │                │       │        │
                    │               │                │       │        │
                    ▼               │                ▼       ▼        │
              Woodpecker CI ◄───────┘          Prometheus  Claude    │
                    │                          Loki        API       │
                    ▼                          Falco                 │
         ┌──────────────────┐                  CrowdSec             │
         │     Pipeline     │                                       │
         │  Gitleaks        │              ┌─── DMZ Network ────────┤
         │  Trivy           │              │  (isolated, no egress) │
         │  Semgrep (SAST)  │              └────────────────────────┘
         │  ZAP (DAST)      │
         │  DefectDojo      │
         │  AI Analysis     │
         └──────────────────┘
```

## Стек

| Компонент | Назначение | URL |
|-----------|-----------|-----|
| Caddy + Coraza WAF | Reverse proxy, TLS, Web Application Firewall | — |
| CrowdSec + Bouncer | Поведенческий IPS, блокировка через Caddy | — |
| Gitea | Git-сервер | git.security-stand.space |
| Woodpecker CI | CI/CD pipeline | ci.security-stand.space |
| Authentik | SSO (OAuth2/OIDC) для всех сервисов | auth.security-stand.space |
| DefectDojo | Vulnerability management | dojo.security-stand.space |
| Grafana | Мониторинг и дашборды | grafana.security-stand.space |
| n8n | Автоматизация, AI-анализ через Claude API | n8n.security-stand.space |
| Juice Shop | Уязвимое приложение (мишень для сканирования) | app.security-stand.space |
| Prometheus | Метрики контейнеров и хоста | internal |
| Loki + Promtail | Сбор и хранение логов | internal |
| Falco | Runtime security — детекция аномалий в контейнерах | internal |
| Fail2ban | Защита SSH от брутфорса | host |

## CI/CD Pipeline

Полный DevSecOps pipeline запускается автоматически при каждом push:
```
Push → Gitleaks → Trivy → Semgrep (SAST) → ZAP (DAST) → DefectDojo → AI Analysis
```

**Шаги:**

1. **Gitleaks** — поиск секретов в коде (API ключи, пароли, токены)
2. **Trivy** — сканирование зависимостей (SCA)
3. **Semgrep** — статический анализ кода (SAST) с правилами OWASP Top 10, SQL injection, command injection
4. **OWASP ZAP** — динамическое сканирование запущенного приложения (DAST)
5. **DefectDojo** — загрузка всех результатов (SAST, DAST, secrets) в vulnerability management
6. **AI Analysis** — Claude API анализирует findings, приоритизирует, даёт рекомендации. Результат записывается как Note в DefectDojo

AI-анализ разделён на два потока: SAST findings и DAST findings анализируются отдельно и привязываются к соответствующим тестам в DefectDojo.

## Защита (OWASP Top 10)

| # | Категория | Статус | Инструменты |
|---|----------|--------|-------------|
| A01 | Broken Access Control | ✅ Covered | Authentik SSO + OAuth2, UFW, Caddy reverse proxy |
| A02 | Cryptographic Failures | ✅ Covered | Caddy auto-TLS (Let's Encrypt), Gitleaks |
| A03 | Injection | ✅ Covered | Coraza WAF (XSS/SQLi/SSRF → 403), Semgrep SAST |
| A04 | Insecure Design | ⚠️ Partial | Semgrep SAST, DMZ сегментация |
| A05 | Security Misconfiguration | ⚠️ Partial | Trivy, CrowdSec http-cve |
| A06 | Vulnerable Components | ✅ Covered | Trivy SCA в CI/CD, DefectDojo |
| A07 | Auth Failures | ⚠️ Partial | Authentik lockout, CrowdSec bouncer, Fail2ban |
| A08 | Software Integrity | ⚠️ Partial | Gitleaks + CI/CD pipeline |
| A09 | Logging & Monitoring | ✅ Covered | Grafana + Prometheus + Loki + Falco + CrowdSec |
| A10 | SSRF | ✅ Covered | Coraza WAF SSRF rules + DMZ network isolation |

## Сетевая сегментация

- **devsecops** — основная сеть, все сервисы
- **dmz** — изолированная сеть (internal: true, нет выхода в интернет), только Juice Shop
- **Caddy** — единственный мост между сетями

Juice Shop полностью изолирован: нет доступа к внутренним сервисам, нет выхода в интернет.

## WAF

Coraza WAF перед Juice Shop блокирует:
- XSS атаки → 403
- SQL injection → 403
- SSRF (127.0.0.1, 169.254.169.254, 10.x.x.x, 172.x.x.x, 192.168.x.x) → 403

## Мониторинг

Три Grafana дашборда:

- **DevSecOps Security Dashboard** — метрики контейнеров (CPU, RAM, disk I/O, network), CrowdSec статистика, Woodpecker pipeline
- **Security Logs Dashboard** — WAF блокировки (Coraza), Falco runtime events, CrowdSec логи, Authentik auth events (через Loki)
- **Host System Dashboard** — CPU/RAM/Disk хоста в реальном времени

## SSO

Authentik обеспечивает единый вход для:
- Grafana (OAuth2/OIDC, автоматическое назначение ролей)
- Gitea (OAuth2/OIDC)

Кастомизация: тёмная тема, логотип, русские заголовки.

## Структура репозитория
```
├── docker-compose.yml          # Все сервисы (23 контейнера)
├── caddy/
│   ├── Caddyfile               # Reverse proxy + WAF + CrowdSec
│   └── Dockerfile              # Caddy + Coraza + CrowdSec bouncer
├── authentik/
│   ├── custom.css              # Тёмная тема логин-страницы
│   └── media/
│       ├── logo.svg            # Логотип
│       └── favicon.svg         # Иконка
├── crowdsec/
│   └── acquis.yaml             # Источники логов для CrowdSec
├── falco/
│   └── falco_rules.yaml        # Кастомные правила Falco
├── grafana/
│   └── dashboards/
│       └── devsecops-dashboard.json
├── loki/
│   ├── loki-config.yml         # Retention 7 дней
│   └── promtail-config.yml
├── prometheus/
│   └── prometheus.yml
└── scripts/
    └── upload_to_defectdojo.py
```

## Развёртывание
```bash
git clone https://github.com/byemoto/devsecops-stand.git
cd devsecops-stand
cp .env.example .env  # Заполнить переменные
docker compose up -d
```

Требования: Ubuntu 22.04, 8GB RAM, Docker, домен с wildcard DNS.

## Что можно улучшить

- SBOM генерация (Syft/Trivy) для A08
- Docker Bench for Security для A05
- Отдельный сервисный аккаунт ci-bot для notes в DefectDojo
- Kubernetes вариант стенда (K3s + Helm + ArgoCD + Network Policies)
- Обновление Authentik до версии с полной русской локализацией

## Связанные репозитории

- [soc-detection-rules](https://github.com/byemoto/soc-detection-rules) — Sigma/MaxPatrol/R-Vision правила
- [byemoto](https://github.com/byemoto/byemoto) — профиль GitHub

## Автор

Евгений Власенко
