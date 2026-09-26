# Готовый WireGuard-сервер: собрали образ, запустили — туннель между
# хостом и контейнером поднят, клиентский конфиг лежит в
# ./workspace/wireguard/client.conf. Требует capability NET_ADMIN и
# устройство /dev/net/tun — запускать с флагом -n:
#   ./sandbox.sh -n -p 51820:51820/udp -t wireguard-ready vpn
# Подробности и диагностика — в README.md рядом с этим файлом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    iproute2 \
    qrencode \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV WG_IFACE=wg0 \
    WG_PORT=51820 \
    WG_SERVER_ADDR=10.66.0.1 \
    WG_CLIENT_ADDR=10.66.0.2 \
    WG_ENDPOINT_HOST=127.0.0.1

EXPOSE 51820/udp

# Как и в других шаблонах с демонами — ENTRYPOINT поднимает сервис (тут:
# сетевой интерфейс wg0) и затем `exec "$@"`, чтобы не конфликтовать с
# `docker run IMAGE sleep infinity`, которым sandbox.sh держит контейнер
# живым.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
