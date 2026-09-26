#!/usr/bin/env bash
#
# Разворачивает docker-контейнер для экспериментов со скриптами и
# подключается к нему интерактивным shell'ом.
#
# Подробности и примеры — в README.md.

set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$WORKDIR/workspace"
PROJECTS_ROOT="$(cd "$WORKDIR/.." && pwd)"
TEMPLATES_DIR="$WORKDIR/templates"
mkdir -p "$WORKSPACE"

SAMBA_HOST_PORT=1445

usage() {
    cat <<EOF
Использование:
  ./sandbox.sh [опции] [образ] [имя]
  ./sandbox.sh -t ШАБЛОН [опции] [имя]   # развернуть готовый шаблон
  ./sandbox.sh templates                 # список готовых шаблонов
  ./sandbox.sh stop    [имя]
  ./sandbox.sh rm      [имя]
  ./sandbox.sh logs    [имя]
  ./sandbox.sh rebuild [имя]   # пересобрать образ из ./Dockerfile (или из
                                # шаблона, если передан -t)

Опции (учитываются только при СОЗДАНИИ контейнера, на уже существующий не влияют):
  -t ШАБЛОН           использовать готовый шаблон из templates/<ШАБЛОН>
                      вместо обычного образа/Dockerfile — вместе с ним
                      первый позиционный аргумент означает ИМЯ контейнера,
                      а не образ. Список шаблонов: ./sandbox.sh templates
  -p HOST:CONTAINER   проброс порта (можно указывать несколько раз)
  -m LIMIT            лимит памяти, например 512m или 1g
  -c LIMIT            лимит CPU, например 1.5
  -u                  запускать процессы от имени текущего пользователя хоста,
                      чтобы файлы в ./workspace не создавались от root
  -s                  пробросить порты Samba/SMB наружу (нужно для шаблонов
                      samba-manual/samba-ready и для своих Samba-экспериментов).
                      TCP 445 внутри контейнера публикуется на хостовый порт
                      $SAMBA_HOST_PORT, а не на 445 — на macOS порт 445 всегда занят
                      системным File Sharing (com.apple.smbd), даже если он
                      выключен в System Settings. Подключаться:
                      smb://localhost:$SAMBA_HOST_PORT/имя-шары
  -n                  добавить сетевые capability (NET_ADMIN, NET_RAW) и
                      устройство /dev/net/tun — нужно шаблонам firewall-lab
                      (nftables/iptables) и wireguard-ready (туннель), без
                      этого их команды падают с "Operation not permitted"
  -i                  режим "systemd как PID 1": --privileged, tmpfs для
                      /run и /run/lock, монтирование /sys/fs/cgroup — нужно
                      шаблону systemd-timer. --privileged даёт контейнеру
                      расширенный доступ к хосту, использовать только для
                      этого конкретного учебного контейнера
  -h                  показать эту справку

Примеры:
  ./sandbox.sh
  ./sandbox.sh python:3.12-slim py
  ./sandbox.sh -p 8080:80 -m 512m nginx web
  ./sandbox.sh -s -t samba-ready share
  ./sandbox.sh -s -t samba-manual samba-training
  ./sandbox.sh -n -t firewall-lab fw
  ./sandbox.sh -n -p 51820:51820/udp -t wireguard-ready vpn
  ./sandbox.sh -i -t systemd-timer sysd
  ./sandbox.sh -p 873:873 -t rsync-daemon backup
  ./sandbox.sh -p 8384:8384 -p 22000:22000 -p 22000:22000/udp -p 21027:21027/udp -t syncthing sync
  ./sandbox.sh templates
  ./sandbox.sh stop py
  ./sandbox.sh rm py
EOF
}

PORTS=()
MEMORY=""
CPUS=""
AS_HOST_USER=0
TEMPLATE=""
NET_ADMIN=0
SYSTEMD_MODE=0

while getopts ":p:m:c:ust:nih" opt; do
    case "$opt" in
        p) PORTS+=("-p" "$OPTARG") ;;
        m) MEMORY="$OPTARG" ;;
        c) CPUS="$OPTARG" ;;
        u) AS_HOST_USER=1 ;;
        s) PORTS+=("-p" "$SAMBA_HOST_PORT:445" "-p" "139:139" "-p" "137:137/udp" "-p" "138:138/udp") ;;
        t) TEMPLATE="$OPTARG" ;;
        n) NET_ADMIN=1 ;;
        i) SYSTEMD_MODE=1 ;;
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
    templates)
        if [[ ! -d "$TEMPLATES_DIR" ]]; then
            echo "Папка templates/ не найдена."
            exit 0
        fi
        echo "Готовые шаблоны (запуск: ./sandbox.sh -t <шаблон> [опции] [имя]):"
        found=0
        for d in "$TEMPLATES_DIR"/*/; do
            [[ -f "$d/Dockerfile" ]] || continue
            found=1
            tname="$(basename "$d")"
            desc="$(sed -n 's/^#[[:space:]]*//p' "$d/Dockerfile" | head -n1)"
            printf '  %-16s %s\n' "$tname" "$desc"
        done
        [[ "$found" -eq 0 ]] && echo "  (пусто)"
        exit 0
        ;;
    rebuild)
        name="${2:-sandbox}"
        if [[ -n "$TEMPLATE" ]]; then
            build_dir="$TEMPLATES_DIR/$TEMPLATE"
            tag="sandbox-template-$TEMPLATE:$name"
        else
            build_dir="$WORKDIR"
            tag="sandbox-image:$name"
        fi
        if [[ ! -f "$build_dir/Dockerfile" ]]; then
            echo "Dockerfile не найден в $build_dir" >&2
            [[ -z "$TEMPLATE" ]] && echo "(см. Dockerfile.example, или используйте -t ШАБЛОН)" >&2
            exit 1
        fi
        docker build -t "$tag" "$build_dir"
        docker rm -f "$name" 2>/dev/null || true
        echo "Образ '$tag' пересобран. Запустите ./sandbox.sh снова, чтобы создать контейнер заново."
        exit 0
        ;;
esac

if [[ -n "$TEMPLATE" ]]; then
    # С шаблоном образ уже определён шаблоном, поэтому единственный
    # позиционный аргумент — это имя контейнера, а не образ.
    NAME="${1:-sandbox}"
    TEMPLATE_DIR="$TEMPLATES_DIR/$TEMPLATE"
    if [[ ! -f "$TEMPLATE_DIR/Dockerfile" ]]; then
        echo "Шаблон '$TEMPLATE' не найден (нет $TEMPLATE_DIR/Dockerfile)." >&2
        echo "Список доступных шаблонов: ./sandbox.sh templates" >&2
        exit 1
    fi
    IMAGE="sandbox-template-$TEMPLATE:$NAME"
    if [[ "$(docker images -q "$IMAGE")" == "" ]]; then
        echo "Собираю образ шаблона '$TEMPLATE' -> '$IMAGE'..."
        docker build -t "$IMAGE" "$TEMPLATE_DIR"
    fi
else
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
fi

EXISTS="$(docker ps -aq -f name="^${NAME}$")"

if [[ -n "$EXISTS" ]] && { [[ ${#PORTS[@]} -gt 0 ]] || [[ -n "$MEMORY" ]] || [[ -n "$CPUS" ]] || [[ "$AS_HOST_USER" -eq 1 ]] || [[ -n "$TEMPLATE" ]] || [[ "$NET_ADMIN" -eq 1 ]] || [[ "$SYSTEMD_MODE" -eq 1 ]]; }; then
    echo "Внимание: контейнер '$NAME' уже существует, опции -p/-m/-c/-u/-s/-t/-n/-i применяются только при создании." >&2
    echo "Чтобы применить их, сначала выполните: ./sandbox.sh rm $NAME" >&2
fi

RUN_ARGS=(-d --name "$NAME" -v "$WORKSPACE:/workspace" -w /workspace)

# Соседние проекты dotfiles и fastinstall (../dotfiles, ../fastinstall)
# пробрасываются bind mount'ом напрямую как /workspace/dotfiles и
# /workspace/fastinstall — без промежуточного копирования: правки внутри
# контейнера сразу видны на хосте и наоборот, git-история доступна как есть.
for proj in dotfiles fastinstall; do
    src="$PROJECTS_ROOT/$proj"
    if [[ -d "$src" ]]; then
        RUN_ARGS+=(-v "$src:/workspace/$proj")
    fi
done

[[ ${#PORTS[@]} -gt 0 ]] && RUN_ARGS+=("${PORTS[@]}")
[[ -n "$MEMORY" ]] && RUN_ARGS+=(--memory "$MEMORY")
[[ -n "$CPUS" ]] && RUN_ARGS+=(--cpus "$CPUS")
[[ "$AS_HOST_USER" -eq 1 ]] && RUN_ARGS+=(--user "$(id -u):$(id -g)")
[[ "$NET_ADMIN" -eq 1 ]] && RUN_ARGS+=(--cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun)
[[ "$SYSTEMD_MODE" -eq 1 ]] && RUN_ARGS+=(--privileged --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:rw)

if [[ -z "$EXISTS" ]]; then
    echo "Создаю контейнер '$NAME' из образа '$IMAGE'..."
    docker run "${RUN_ARGS[@]}" "$IMAGE" sleep infinity
elif [[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != "true" ]]; then
    echo "Запускаю остановленный контейнер '$NAME'..."
    docker start "$NAME" >/dev/null
fi

echo "Подключаюсь к '$NAME' (папка ./workspace доступна как /workspace)..."
docker exec -it "$NAME" bash
