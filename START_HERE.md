# collapse: быстрый запуск

Рабочее окружение состоит из двух соседних проектов: `collapse-backend` и `collapse-client`.
Бэкенд — Tinode 0.25.3 + PostgreSQL с небольшим расширением для пагинации
медиа; клиент — Flutter. Обычные сообщения и авторизация используют Tinode.
Клонируйте их в одну общую папку, не меняя расположение относительно друг друга:

```sh
git clone https://github.com/Z3R0F0/collapse-backend.git
git clone https://github.com/Z3R0F0/collapse-client.git
```

Для продолжения разработки начните с `collapse-client/HANDOFF.md` и `collapse-client/AGENTS.md`.
Архитектура и отдельные правила агентов есть внутри каждого из двух проектов.

## Что установить

- macOS или Linux, Node.js 24+, `curl`, `tar`.
- На Windows используйте Linux-окружение WSL2 (включая setup и web proxy), при
  Docker — с WSL-интеграцией. Нативные setup-скрипты из PowerShell не поддержаны;
  iOS можно собирать только на macOS с Xcode.
- Flutter **3.41.3** (Dart 3.11.1). Версия закреплена в `.fvmrc`; для FVM выполните
  `fvm install` внутри `collapse-client`, затем используйте `fvm flutter` /
  `fvm dart` вместо `flutter` / `dart` в командах ниже.
- Go **1.26+** и PostgreSQL 13+ с `initdb` и `pg_ctl` в `PATH`
  **или** Docker Compose v2 (Go собирается внутри контейнера).

На Mac PostgreSQL можно установить через Homebrew: `brew install postgresql@14`.
Добавьте его утилиты в текущий терминал:

```sh
export PATH="$(brew --prefix postgresql@14)/bin:$PATH"
```

Запускать PostgreSQL как системный сервис не требуется: проект поднимает свой
изолированный экземпляр на порту 55432.

## 1. Бэкенд — первый терминал

Из общей папки с двумя репозиториями:

```sh
cd collapse-backend
node scripts/setup.mjs
sh scripts/native.sh
```

Оставьте терминал открытым. Tinode работает на `127.0.0.1:6060`.
Для Docker вместо нативных команд выполните `node scripts/setup.mjs --docker`,
затем `docker compose up --build -d`.
Не запускайте оба варианта одновременно. На Apple Silicon Docker-вариант
требует эмуляции amd64; нативный вариант использует arm64.

## 2. Клиент в браузере — второй терминал

Снова из папки с двумя проектами:

```sh
cd collapse-client
(cd packages/tinode && dart pub get)
flutter pub get
flutter build web --profile --no-web-resources-cdn --dart-define-from-file=../collapse-backend/.local/client.json
cd ../collapse-backend
node scripts/web.mjs
```

Откройте **http://127.0.0.1:8085**. Зарегистрируйте пользователя: логин 4–32
символа, пароль от 8 символов. Для проверки переписки создайте второй аккаунт
в другом профиле браузера и найдите его логин в Контактах.

Не подменяйте этот запуск простым статическим сервером или `flutter run -d chrome`:
предоставленный Caddy проксирует API, WebSocket и медиа на один origin,
а также обслуживает прямые ссылки на чаты.

## Проверка и остановка

```sh
# Из collapse-backend при работающем сервере:
node scripts/smoke.mjs

# Из collapse-client:
flutter analyze
flutter test
```

`Ctrl-C` во втором терминале останавливает только web-сервер. `Ctrl-C` в первом
останавливает Tinode и его локальный PostgreSQL, но сохраняет данные.
Для Docker: `docker compose down` без `--volumes`.
Следующий запуск: снова `sh scripts/native.sh` и `node scripts/web.mjs`;
повторная сборка клиента нужна только после изменения его кода или конфигурации.

## Важно

- Первичная установка скачивает зависимости и проверенные upstream-бинарники:
  нужен интернет. Нативный setup также собирает закреплённый исходник Tinode
  с небольшим media-overlay. Репозитории содержат исходники, не готовое офлайн-окружение.
- Рабочая база, аккаунты, ключи, `.env`, `.local/` и сборки в репозитории
  не включены. Setup создаёт новое пустое окружение с новыми ключами. Повторный
  setup в том же окружении сохраняет ключи. Не удаляйте `.local/secrets.json`,
  сохраняя базу: ключи необходимы для существующих данных.
- Это локальная конфигурация, не production-развёртывание: HTTP только на loopback.
  Для публикации нужны TLS, собственные адреса, подпись и настройки push.
- Клиент поддерживает Android, iPhone и web. iPad не включён. Новый application /
  bundle ID — `app.collapse.collapse`. Это отдельное приложение относительно
  прежнего ID; данные старой мобильной установки автоматически не переносятся.
- Для iOS Simulator: из клиента `flutter run -d <device-id>` с тем же
  `--dart-define-from-file`. Для Android Emulator скопируйте client.json в локальный
  файл и замените только `TINODE_HOST` на `10.0.2.2:6060`. Настоящему телефону
  требуется отдельно настроенный доступный сервер, а не localhost телефона.
- Push выключен до настройки собственных Firebase/APNs/FCM реквизитов.

Подробности: `collapse-backend/SETUP.md`, `collapse-client/SETUP.md`.
Это чистый проект: переноса старых аккаунтов, сессий и клиентской базы нет.
