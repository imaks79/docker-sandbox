#!/usr/bin/env bash
#
# Поднимает WireGuard-сервер при каждом старте контейнера. Идемпотентно:
# ключи и интерфейс создаются только если их ещё нет, повторные запуски
# (docker start после stop) переиспользуют то же самое.
set -euo pipefail

WG_IFACE="${WG_IFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_SERVER_ADDR="${WG_SERVER_ADDR:-10.66.0.1}"
WG_CLIENT_ADDR="${WG_CLIENT_ADDR:-10.66.0.2}"
WG_ENDPOINT_HOST="${WG_ENDPOINT_HOST:-127.0.0.1}"

# Каталог внутри /workspace — значит ключи и клиентский конфиг видны и
# переживают пересоздание контейнера прямо на хосте, в ./workspace/wireguard.
WG_DIR="/workspace/wireguard"
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

if [[ ! -f "$WG_DIR/server_private.key" ]]; then
    echo "Генерирую ключи сервера и клиента..."
    umask 077
    wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
    wg genkey | tee "$WG_DIR/client_private.key" | wg pubkey > "$WG_DIR/client_public.key"
fi

SERVER_PUBLIC_KEY="$(cat "$WG_DIR/server_public.key")"
CLIENT_PRIVATE_KEY="$(cat "$WG_DIR/client_private.key")"
CLIENT_PUBLIC_KEY="$(cat "$WG_DIR/client_public.key")"

# Поднимаем интерфейс, только если его ещё нет (повторный docker start).
if ! ip link show "$WG_IFACE" &>/dev/null; then
    if ! ip link add dev "$WG_IFACE" type wireguard 2>/tmp/wg-error.log; then
        cat <<EOF

!!! Не удалось создать интерфейс WireGuard ($WG_IFACE).

Скорее всего ядро Docker-хоста собрано без поддержки WireGuard
(CONFIG_WIREGUARD) и модуль недоступен внутри контейнера — сама
Docker-песочница на это повлиять не может, нужна поддержка на уровне
ядра хоста/VM Docker Desktop. Подробности:

$(cat /tmp/wg-error.log 2>/dev/null || true)

Контейнер продолжит работать (см. sleep infinity ниже), чтобы можно
было зайти внутрь и поразбираться (./sandbox.sh -n -t wireguard-ready vpn),
но сам туннель не поднят.

EOF
        exec "$@"
    fi

    ip address add "$WG_SERVER_ADDR/24" dev "$WG_IFACE"

    wg set "$WG_IFACE" \
        listen-port "$WG_PORT" \
        private-key "$WG_DIR/server_private.key" \
        peer "$CLIENT_PUBLIC_KEY" allowed-ips "$WG_CLIENT_ADDR/32"

    ip link set up dev "$WG_IFACE"
fi

# Клиентский конфиг — забираете с хоста напрямую из ./workspace/wireguard/,
# перегенерируется на каждый старт (сами ключи стабильны, меняется только
# то, что могло поменяться через переменные окружения, например endpoint).
cat > "$WG_DIR/client.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $WG_CLIENT_ADDR/32

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $WG_ENDPOINT_HOST:$WG_PORT
AllowedIPs = $WG_SERVER_ADDR/32
PersistentKeepalive = 25
EOF
chmod 600 "$WG_DIR/client.conf"

cat <<EOF

WireGuard поднят: интерфейс $WG_IFACE, $WG_SERVER_ADDR/24, порт $WG_PORT/udp
Клиентский конфиг сохранён на хосте в ./workspace/wireguard/client.conf
Импортируйте его в приложение WireGuard на хосте и подключайтесь.

EOF

if command -v qrencode &>/dev/null; then
    echo "QR-код для мобильного приложения WireGuard:"
    qrencode -t ansiutf8 < "$WG_DIR/client.conf"
fi

exec "$@"
