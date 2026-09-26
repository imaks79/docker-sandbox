#!/usr/bin/env bash
#
# Настраивает и запускает rsync в режиме daemon (свой протокол rsync://,
# а не поверх SSH). Идемпотентно — конфиг и секреты перегенерируются из
# шаблона при каждом старте, безопасно перезапускать.
set -euo pipefail

RSYNC_PORT="${RSYNC_PORT:-873}"
RSYNC_SHARE_PATH="${RSYNC_SHARE_PATH:-/workspace}"
RSYNC_USER="${RSYNC_USER:-sandbox}"
RSYNC_PASSWORD="${RSYNC_PASSWORD:-sandbox}"
RSYNC_READ_ONLY="${RSYNC_READ_ONLY:-false}"

mkdir -p "$RSYNC_SHARE_PATH"

sed \
    -e "s|__RSYNC_PORT__|$RSYNC_PORT|g" \
    -e "s|__RSYNC_SHARE_PATH__|$RSYNC_SHARE_PATH|g" \
    -e "s|__RSYNC_READ_ONLY__|$RSYNC_READ_ONLY|g" \
    -e "s|__RSYNC_USER__|$RSYNC_USER|g" \
    /etc/rsyncd.conf.template > /etc/rsyncd.conf

printf '%s:%s\n' "$RSYNC_USER" "$RSYNC_PASSWORD" > /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets

rsync --daemon --no-detach --config=/etc/rsyncd.conf &

cat <<EOF

rsync daemon запущен.
  Модуль:  workspace -> $RSYNC_SHARE_PATH
  Порт:    $RSYNC_PORT
  Логин:   $RSYNC_USER (пароль задаётся переменной RSYNC_PASSWORD)
  Только чтение: $RSYNC_READ_ONLY

С хоста, например:
  rsync -av --port=$RSYNC_PORT ./local-folder/ rsync://$RSYNC_USER@localhost/workspace/

EOF

exec "$@"
