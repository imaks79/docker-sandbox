# Учебный стенд: фильтрация трафика между "сервисами" внутри контейнера
# через nftables/iptables. Требует capability NET_ADMIN/NET_RAW — запускать
# с флагом -n: ./sandbox.sh -n -t firewall-lab fw
# Пошаговая инструкция — в TUTORIAL.md рядом с этим файлом.

FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

# nftables — современный инструмент фильтрации (замена iptables), но
# ставим и iptables-legacy тоже: полезно сравнить синтаксис, много
# существующих гайдов до сих пор написаны под iptables.
# python3 нужен только чтобы поднять два учебных "сервиса" на разных
# портах командой `python3 -m http.server`.
RUN apt-get update && apt-get install -y --no-install-recommends \
    nftables \
    iptables \
    iproute2 \
    procps \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*
