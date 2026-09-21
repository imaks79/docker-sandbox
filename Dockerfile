# Образ для тестирования bootstrap-скриптов проекта dotfiles
# (../dotfiles — виден внутри контейнера как /workspace/dotfiles через
# симлинк workspace/dotfiles -> ../../dotfiles).
#
# Пересобрать после правок:  ./sandbox.sh rebuild
# Запустить и потестировать:
#   ./sandbox.sh
#   cd dotfiles && ./setup.sh

FROM ubuntu:latest

# Без этого apt-get install на пакетах вроде tzdata/locales открывает
# интерактивный диалог выбора часового пояса — в неинтерактивном контейнере
# отвечать некому, и сборка/установка виснет.
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# curl/git/ca-certificates/rsync — то же самое, что ensure_prereqs() в
# lib/packages.sh поставит сама при первом запуске setup.sh; пре-бейк в
# образ убирает сетевую зависимость первого запуска и ускоряет повторные
# пересоздания контейнера (./sandbox.sh rm && ./sandbox.sh).
# sudo — на случай запуска setup.sh не от root (docker run -u/--user);
# сам setup.sh это тоже умеет (SUDO="" когда мы уже root, см. lib/common.sh),
# но со своим пользователем внутри контейнера потребуется sudo в PATH.
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    git \
    ca-certificates \
    rsync \
    locales \
    && rm -rf /var/lib/apt/lists/*
