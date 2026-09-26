#!/usr/bin/env bash
#
# Запускается при каждом старте контейнера (docker run/start), в т.ч.
# при повторных запусках уже существующего контейнера через sandbox.sh —
# поэтому все шаги идемпотентны: смб-конфиг перегенерируется из шаблона,
# пользователь создаётся только если его ещё нет, пароль переустанавливается
# заново (безопасно перезапускать сколько угодно раз).
set -euo pipefail

SAMBA_USER="${SAMBA_USER:-sandbox}"
SAMBA_PASSWORD="${SAMBA_PASSWORD:-sandbox}"
SAMBA_SHARE_PATH="${SAMBA_SHARE_PATH:-/workspace}"

mkdir -p "$SAMBA_SHARE_PATH" /var/log/samba /var/run/samba /var/lib/samba/private

sed \
    -e "s|__SAMBA_USER__|$SAMBA_USER|g" \
    -e "s|__SAMBA_SHARE_PATH__|$SAMBA_SHARE_PATH|g" \
    /etc/samba/smb.conf.template > /etc/samba/smb.conf

if ! id -u "$SAMBA_USER" >/dev/null 2>&1; then
    useradd --no-create-home --shell /usr/sbin/nologin "$SAMBA_USER"
fi

# smbpasswd -a создаёт запись если её нет, обновляет пароль если есть —
# так что при перезапуске контейнера с изменённым SAMBA_PASSWORD пароль
# подхватится заново.
printf '%s\n%s\n' "$SAMBA_PASSWORD" "$SAMBA_PASSWORD" | smbpasswd -a -s "$SAMBA_USER"
smbpasswd -e "$SAMBA_USER" >/dev/null

testparm -s >/dev/null

smbd --foreground --no-process-group &
nmbd --foreground --no-process-group &

cat <<EOF

Samba запущена.
  Шара:      $SAMBA_SHARE_PATH -> \\\\<host>\\workspace  /  smb://<host>/workspace
  Логин:     $SAMBA_USER
  Пароль:    $SAMBA_PASSWORD  (задаётся переменными SAMBA_USER/SAMBA_PASSWORD)

С хоста (пробросьте порты флагом -s у sandbox.sh):
  macOS:   Finder -> Cmd+K -> smb://localhost:1445/workspace
  Linux:   smbclient -p 1445 -L localhost -U $SAMBA_USER

EOF

exec "$@"
