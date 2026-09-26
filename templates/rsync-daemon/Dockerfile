# Готовый rsync daemon: собрали образ, запустили — модуль "workspace"
# (то есть ./workspace на хосте) сразу доступен по rsync://, с логином
# и паролем. Для быстрой синхронизации файлов между машинами и
# инкрементальных бэкапов без SSH.
#
# Быстрый старт:
#   ./sandbox.sh -p 873:873 -t rsync-daemon backup
# Подробности и переменные окружения — в README.md рядом с этим файлом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    rsync \
    && rm -rf /var/lib/apt/lists/*

COPY rsyncd.conf.template /etc/rsyncd.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV RSYNC_PORT=873 \
    RSYNC_SHARE_PATH=/workspace \
    RSYNC_USER=sandbox \
    RSYNC_PASSWORD=sandbox \
    RSYNC_READ_ONLY=false

EXPOSE 873/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
