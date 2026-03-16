# DevSecOps Home Lab

Личный стенд для практики DevSecOps.

## Что внутри

Развёрнуто на локальной машине через Docker Compose:

- **Gitea** — свой git-сервер, не хотел зависеть от GitHub для внутренних репо
- **Woodpecker CI** — CI/CD, интегрирован с Gitea через OAuth
- **Authentik** — SSO для всего стенда, OAuth2/OIDC с поддержкой PKCE и MFA
- **DefectDojo** — складываю сюда находки от сканеров, удобно смотреть динамику
- **Grafana + Prometheus** — дашборд с метриками контейнеров и результатами сканов
- **n8n** — автоматизация, подключил Anthropic API для AI-анализа результатов

Сканеры запускаются в pipeline при каждом push:
- Gitleaks — ищет секреты в коде
- Semgrep — статический анализ (SAST)
- Trivy — уязвимости в зависимостях и образах

## Как это работает

```
push в Gitea
    │
    ▼
Woodpecker CI запускает pipeline
    ├── Gitleaks scan
    ├── Semgrep SAST
    ├── Trivy fs scan
    └── n8n webhook → Claude API → анализ находок
```

Все результаты идут в DefectDojo, там можно смотреть историю по каждому репо.

## Структура

```
├── docker-compose.yml
├── scripts/
│   └── upload_to_defectdojo.py   # загрузка результатов сканов в DefectDojo
├── caddy/
│   └── Caddyfile                 # reverse proxy, на VPS будет TLS
├── grafana/
│   └── dashboards/               # дашборд безопасности
├── prometheus/
│   └── prometheus.yml
├── loki/
│   ├── loki-config.yml
│   └── promtail-config.yml
├── falco/
│   └── falco_rules.yaml          # runtime security (для Linux/VPS)
└── woodpecker/
    └── .woodpecker.yml           # пример pipeline
```

## Запуск

```bash
git clone git@github.com:byemoto/devsecops-stand.git
cd devsecops-stand

cp .env.example .env
# заполнить .env своими значениями

docker compose up -d
```

Порты:

| Сервис | Порт |
|--------|------|
| Gitea | 3000 |
| Woodpecker | 8741 |
| Authentik | 9742 |
| DefectDojo | 8743 |
| Grafana | 8744 |
| Prometheus | 8745 |
| n8n | 8747 |
| Juice Shop | 8748 |

## Тестовое приложение

В репо [vulnerable-app](https://github.com/byemoto/vulnerable-app) лежит намеренно уязвимый Python-код — SQL injection, command injection, hardcoded secrets, небезопасная десериализация. На нём тестирую pipeline.

Пример того что находит Semgrep:

```
Findings: 3 (3 blocking)
- python.lang.security.audit.sqli
- python.lang.security.audit.subprocess-shell-true  
- python.lang.security.audit.pickle
```

Gitleaks ловит hardcoded API key в строке 5.

После сканирования n8n отправляет результаты в Claude API, который объясняет каждую находку и предлагает исправления с примерами кода.

## Что планирую добавить

- [ ] DAST сканирование Juice Shop через OWASP ZAP
- [ ] Falco для runtime security (нужен Linux)
- [ ] Автоматическая загрузка в DefectDojo из pipeline
- [ ] Деплой на VPS с реальным доменом и TLS

## Заметки

На Windows стенд поднимается через Docker Desktop, но Falco не работает — только Linux. На Mac тоже без Falco, там другие ограничения с ядром. Для полноценного стенда буду использовать VPS на Ubuntu.

Authentik поначалу был избыточным решением для домашней лабы, но в итоге оказался полезным — SSO настроен для Grafana, и понял как работает PKCE на практике, не только в теории.
