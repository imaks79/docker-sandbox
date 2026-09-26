#!/usr/bin/env bash
#
# Запускает Syncthing с домашней папкой конфига внутри /workspace, чтобы
# идентификатор устройства (Device ID) и ключи переживали пересоздание
# контейнера и были видны прямо на хосте.
set -euo pipefail

ST_HOME="${ST_HOME:-/workspace/.syncthing}"
ST_GUI_USER="${ST_GUI_USER:-sandbox}"
ST_GUI_PASSWORD="${ST_GUI_PASSWORD:-sandbox}"

mkdir -p "$ST_HOME"

# `syncthing generate` создаёт config.xml, ключи устройства и сразу
# прописывает GUI-логин/пароль (с правильным bcrypt-хэшем) — без
# запуска самого демона. Если конфиг уже есть (повторный старт
# контейнера) — не трогаем его, иначе слетит Device ID. Сам Device ID
# вытаскиваем из вывода generate и сохраняем — на новых версиях
# Syncthing нет простого отдельного флага, чтобы прочитать его повторно.
if [[ ! -f "$ST_HOME/config.xml" ]]; then
    syncthing generate \
        --home="$ST_HOME" \
        --gui-user="$ST_GUI_USER" \
        --gui-password="$ST_GUI_PASSWORD" \
        --no-default-folder \
        | tee "$ST_HOME/generate.log"
    grep -o 'Device ID: [A-Z0-9-]*' "$ST_HOME/generate.log" | sed 's/Device ID: //' > "$ST_HOME/device-id.txt" || true
fi

syncthing serve \
    --home="$ST_HOME" \
    --gui-address=0.0.0.0:8384 \
    --no-browser \
    --no-restart &

DEVICE_ID="$(cat "$ST_HOME/device-id.txt" 2>/dev/null || echo "(смотрите Settings -> This Device в Web UI)")"

cat <<EOF

Syncthing запущен.
  Web UI:    http://localhost:8384  (логин $ST_GUI_USER, пароль задаётся ST_GUI_PASSWORD)
  Device ID: $DEVICE_ID
  Папка синхронизации по умолчанию: /workspace (добавьте её в Web UI, если ещё не добавлена)

EOF

exec "$@"
