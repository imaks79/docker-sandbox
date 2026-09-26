# Контейнер с настоящим systemd в роли PID 1 — для сравнения с обычными
# песочницами sandbox.sh, где PID 1 это просто `sleep infinity` без
# всякого init. Требует привилегированный режим и cgroup — запускать с
# флагом -i: ./sandbox.sh -i -t systemd-timer sysd
# Пошаговая инструкция и сравнение с cron — в TUTORIAL.md рядом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    dbus \
    cron \
    procps \
    less \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Классический набор масок для systemd-в-Docker: отключаем юниты, которые
# либо не имеют смысла без реального железа (getty на несуществующих
# tty, udev, hugepages/config mounts), либо просто зависают, ожидая
# ресурсы, которых в контейнере нет.
RUN systemctl mask \
        systemd-udevd.service \
        systemd-udev-trigger.service \
        systemd-remount-fs.service \
        dev-hugepages.mount \
        sys-kernel-config.mount \
        display-manager.service \
        getty.target \
        getty-static.service \
    || true

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sandbox-demo.service /etc/systemd/system/sandbox-demo.service
COPY sandbox-demo.timer /etc/systemd/system/sandbox-demo.timer
RUN chmod +x /usr/local/bin/entrypoint.sh

# ENTRYPOINT игнорирует переданную команду (см. entrypoint.sh) и всегда
# exec'ает /sbin/init — тому нужно быть PID 1, background-процессом он
# нормально не работает.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
