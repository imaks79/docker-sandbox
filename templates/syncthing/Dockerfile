# Готовый Syncthing: собрали образ, запустили — Web UI и синхронизация
# сразу доступны, конфиг живёт в ./workspace/.syncthing на хосте. Для
# постоянной двусторонней синхронизации файлов между несколькими
# контейнерами/хостами.
#
# Быстрый старт:
#   ./sandbox.sh -p 8384:8384 -p 22000:22000 -p 22000:22000/udp -p 21027:21027/udp -t syncthing sync
# Подробности — в README.md рядом с этим файлом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    syncthing \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV ST_HOME=/workspace/.syncthing \
    ST_GUI_USER=sandbox \
    ST_GUI_PASSWORD=sandbox

EXPOSE 8384/tcp 22000/tcp 22000/udp 21027/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
