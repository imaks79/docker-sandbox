# Учебный шаблон: "чистая" Ubuntu-машина для тренировки ручной настройки
# Samba-шары с нуля. Пошаговая инструкция — в TUTORIAL.md рядом с этим
# файлом. Samba здесь НАРОЧНО не установлена — вы ставите и настраиваете
# её сами, как на только что полученном сервере.
#
# Запуск:
#   ./sandbox.sh -s -t samba-manual samba-training
# Дальше — следуйте TUTORIAL.md внутри контейнера.

FROM ubuntu:latest

# Без этого apt-get install на tzdata/locales открывает интерактивный
# диалог выбора часового пояса, а отвечать в неинтерактивном контейнере
# некому — сборка/установка зависнет.
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# Только базовые утилиты, которые обычно уже есть на свежем сервере:
# редакторы, чтобы править smb.conf, и сетевые инструменты, чтобы
# проверять, что smbd реально слушает порт. samba/samba-common-bin
# сюда намеренно не входят.
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    nano \
    vim \
    iproute2 \
    net-tools \
    procps \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
