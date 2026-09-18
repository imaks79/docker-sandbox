#!/usr/bin/env bash
#
# Разворачивает docker-контейнер для экспериментов со скриптами и
# подключается к нему интерактивным shell'ом.
#
# Подробности и примеры — в README.md.

set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$WORKDIR/workspace"
mkdir -p "$WORKSPACE"

usage() {
    cat <<EOF
Использование:
  ./sandbox.sh [опции] [образ] [имя]
  ./sandbox.sh stop    [имя]
  ./sandbox.sh rm      [имя]
  ./sandbox.sh logs    [имя]
  ./sandbox.sh rebuild [имя]   # пересобрать образ из ./Dockerfile

Опции (учитываются только при СОЗДАНИИ контейнера, на уже существующий не влияют):
  -p HOST:CONTAINER   проброс порта (можно указывать несколько раз)
  -m LIMIT            лимит памяти, например 512m или 1g
  -c LIMIT            лимит CPU, например 1.5
  -u                  запускать процессы от имени текущего пользователя хоста,
                      чтобы файлы в ./workspace не создавались от root
  -s                  пробросить порты Samba/SMB, чтобы smbd из
                      workspace/dotfiles/samba-share.sh был виден снаружи.
                      TCP 445 внутри контейнера публикуется на хостовый порт
                      $SAMBA_HOST_PORT, а не на 445 — на macOS порт 445 всегда занят
                      системным File Sharing (com.apple.smbd), даже если он
                      выключен в System Settings. Подключаться:
                      smb://localhost:$SAMBA_HOST_PORT/имя-шары
  -h                  показать эту справку

Примеры:
  ./sandbox.sh
  ./sandbox.sh python:3.12-slim py
  ./sandbox.sh -p 8080:80 -m 512m nginx web
  ./sandbox.sh -s ubuntu:latest samba-box
  ./sandbox.sh stop py
  ./sandbox.sh rm py
EOF
}

SAMBA_HOST_PORT=445

PORTS=()
MEMORY=""
CPUS=""
AS_HOST_USER=0

while getopts ":p:m:c:ush" opt; do
    case "$opt" in
        p) PORTS+=("-p" "$OPTARG") ;;
        m) MEMORY="$OPTARG" ;;
        c) CPUS="$OPTARG" ;;
        u) AS_HOST_USER=1 ;;
        s) PORTS+=("-p" "$SAMBA_HOST_PORT:445" "-p" "139:139" "-p" "137:137/udp" "-p" "138:138/udp") ;;
        h) usage; exit 0 ;;
        \?) echo "Неизвестная опция: -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Опция -$OPTARG требует значение" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

cmd="${1:-}"

case "$cmd" in
    stop)
        docker stop "${2:-sandbox}"
        exit 0
        ;;
    rm)
        docker rm -f "${2:-sandbox}" 2>/dev/null || true
        exit 0
        ;;
    logs)
        docker logs -f "${2:-sandbox}"
        exit 0
        ;;
    rebuild)
        name="${2:-sandbox}"
        if [[ ! -f "$WORKDIR/Dockerfile" ]]; then
            echo "Dockerfile не найден в $WORKDIR (см. Dockerfile.example)" >&2
            exit 1
        fi
        docker build -t "sandbox-image:$name" "$WORKDIR"
        docker rm -f "$name" 2>/dev/null || true
        echo "Образ пересобран. Запустите ./sandbox.sh снова, чтобы создать контейнер заново."
        exit 0
        ;;
esac

IMAGE="${1:-ubuntu:latest}"
NAME="${2:-sandbox}"

# Если в проекте есть Dockerfile — используем собранный из него образ
# вместо переданного/дефолтного, чтобы сохранять доустановленные пакеты.
if [[ -f "$WORKDIR/Dockerfile" ]]; then
    IMAGE="sandbox-image:$NAME"
    if [[ "$(docker images -q "$IMAGE")" == "" ]]; then
        echo "Собираю образ '$IMAGE' из Dockerfile..."
        docker build -t "$IMAGE" "$WORKDIR"
    fi
fi

EXISTS="$(docker ps -aq -f name="^${NAME}$")"

if [[ -n "$EXISTS" ]] && { [[ ${#PORTS[@]} -gt 0 ]] || [[ -n "$MEMORY" ]] || [[ -n "$CPUS" ]] || [[ "$AS_HOST_USER" -eq 1 ]]; }; then
    echo "Внимание: контейнер '$NAME' уже существует, опции -p/-m/-c/-u/-s применяются только при создании." >&2
    echo "Чтобы применить их, сначала выполните: ./sandbox.sh rm $NAME" >&2
fi

RUN_ARGS=(-d --name "$NAME" -v "$WORKSPACE:/workspace" -w /workspace)
[[ ${#PORTS[@]} -gt 0 ]] && RUN_ARGS+=("${PORTS[@]}")
[[ -n "$MEMORY" ]] && RUN_ARGS+=(--memory "$MEMORY")
[[ -n "$CPUS" ]] && RUN_ARGS+=(--cpus "$CPUS")
[[ "$AS_HOST_USER" -eq 1 ]] && RUN_ARGS+=(--user "$(id -u):$(id -g)")

if [[ -z "$EXISTS" ]]; then
    echo "Создаю контейнер '$NAME' из образа '$IMAGE'..."
    docker run "${RUN_ARGS[@]}" "$IMAGE" sleep infinity
elif [[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != "true" ]]; then
    echo "Запускаю остановленный контейнер '$NAME'..."
    docker start "$NAME" >/dev/null
fi

echo "Подключаюсь к '$NAME' (папка ./workspace доступна как /workspace)..."
docker exec -it "$NAME" bash
