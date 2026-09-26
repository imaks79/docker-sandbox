# Готовая к работе Samba-шара: собрали образ, запустили — шара уже
# работает и раздаёт /workspace (т.е. ./workspace на хосте). Для тех
# случаев, когда просто хочется быстро поделиться файлами в локальной
# сети, без ручной настройки — см. templates/samba-manual для тренировки
# делать то же самое руками.
#
# Быстрый старт:
#   ./sandbox.sh -s -t samba-ready share
# Подробности и переменные окружения — в README.md рядом с этим файлом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    samba \
    samba-common-bin \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/samba /var/lib/samba/private /var/log/samba

COPY smb.conf.template /etc/samba/smb.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Логин/пароль и путь шары по умолчанию — переопределяются пересборкой
# образа (или `docker run -e ...`, если запускать не через sandbox.sh).
ENV SAMBA_USER=sandbox \
    SAMBA_PASSWORD=sandbox \
    SAMBA_SHARE_PATH=/workspace

EXPOSE 445/tcp 139/tcp 137/udp 138/udp

# ENTRYPOINT не переопределяется командой из `docker run IMAGE sleep
# infinity`, которую использует sandbox.sh, — она приходит как аргументы
# entrypoint.sh и выполняется через `exec "$@"` в конце скрипта, уже
# после того как подняты smbd/nmbd.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
