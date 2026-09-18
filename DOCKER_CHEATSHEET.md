# Шпаргалка по Docker

Базовые команды на каждый день. Не привязана к `sandbox.sh` — пригодится
в любом проекте с Docker.

## Образы (images)

```bash
docker images                     # список локальных образов
docker pull ubuntu:latest         # скачать образ
docker rmi <образ>                # удалить образ
docker build -t myimage:tag .     # собрать образ из Dockerfile в текущей папке
docker history <образ>            # из каких слоёв состоит образ
```

## Контейнеры (containers)

```bash
docker ps                         # запущенные контейнеры
docker ps -a                      # все контейнеры, включая остановленные
docker run <образ>                # запустить контейнер (создаёт новый!)
docker start <имя|id>             # запустить существующий (остановленный)
docker stop <имя|id>              # остановить
docker restart <имя|id>           # перезапустить
docker rm <имя|id>                # удалить остановленный контейнер
docker rm -f <имя|id>             # принудительно удалить (даже запущенный)
docker logs <имя|id>              # вывод контейнера (stdout/stderr)
docker logs -f <имя|id>           # смотреть логи в реальном времени
```

### Частые флаги `docker run`

```bash
-d                        # detached — в фоне
-it                       # интерактивный терминал (i=stdin, t=tty)
--name myapp              # задать имя вместо случайного
-v host_path:container_path   # смонтировать том/папку
-p host_port:container_port   # пробросить порт
-e VAR=value               # переменная окружения
--rm                        # удалить контейнер сразу после остановки
--memory 512m --cpus 1.5    # лимиты ресурсов
--user 1000:1000            # запуск от конкретного uid:gid
-w /path                    # рабочая директория внутри контейнера
```

Пример: разово запустить и удалить после выхода —

```bash
docker run --rm -it ubuntu:latest bash
```

## Подключение к работающему контейнеру

```bash
docker exec -it <имя|id> bash     # открыть shell в уже запущенном контейнере
docker exec <имя|id> <команда>    # выполнить одну команду и выйти
```

Отличие `run` от `exec`: `run` создаёт новый контейнер, `exec` заходит
в уже существующий и запущенный.

## Копирование файлов хост ↔ контейнер

```bash
docker cp file.txt myapp:/path/         # с хоста в контейнер
docker cp myapp:/path/file.txt ./       # из контейнера на хост
```

(Обычно удобнее volume/bind mount через `-v`, чем `cp` — файлы сразу
синхронизированы в обе стороны.)

## Тома и сети

```bash
docker volume ls                  # именованные тома
docker volume create myvolume
docker volume rm myvolume
docker run -v myvolume:/data ...  # именованный том (в отличие от bind mount с путём хоста)

docker network ls
docker network create mynet
docker run --network mynet ...    # контейнеры в одной сети видят друг друга по имени
```

## Диагностика

```bash
docker inspect <имя|id>           # вся метаинформация о контейнере/образе в JSON
docker stats                      # использование CPU/RAM всеми контейнерами в реальном времени
docker top <имя|id>               # процессы внутри контейнера
docker port <имя|id>              # какие порты проброшены
```

## Очистка

```bash
docker container prune            # удалить все остановленные контейнеры
docker image prune                # удалить "висячие" (dangling) образы
docker image prune -a             # удалить все неиспользуемые образы
docker volume prune               # удалить неиспользуемые тома
docker system prune               # почистить всё сразу (контейнеры, сети, dangling-образы)
docker system prune -a --volumes  # агрессивная очистка, включая тома — осторожно!
```

## Dockerfile — основные инструкции

```dockerfile
FROM ubuntu:latest        # базовый образ
WORKDIR /app              # рабочая директория (создаст, если нет)
COPY . .                  # скопировать файлы из контекста сборки
RUN apt-get update && apt-get install -y curl   # выполнить команду при сборке
ENV KEY=value             # переменная окружения для рантайма
EXPOSE 8080               # документирует порт (не публикует сам по себе)
CMD ["python3", "app.py"] # команда по умолчанию при запуске контейнера
```

`RUN` выполняется при сборке образа, `CMD`/`ENTRYPOINT` — при запуске
контейнера.

## docker compose (если несколько сервисов)

```bash
docker compose up -d       # поднять все сервисы из docker-compose.yml в фоне
docker compose down        # остановить и удалить контейнеры/сети
docker compose logs -f     # логи всех сервисов
docker compose ps          # статус сервисов
docker compose exec <сервис> bash   # зайти в сервис
```

## Частые ошибки и как читать

- `Cannot connect to the Docker daemon` — Docker не запущен (запустите
  Docker Desktop / `dockerd`).
- `port is already allocated` — порт на хосте уже занят другим
  процессом/контейнером, выберите другой `-p`.
- `No such container` — опечатка в имени, или контейнер уже удалён
  (`docker ps -a` покажет реальный список).
- Файлы, созданные в контейнере от root, на хосте принадлежат root —
  либо запускайте с `--user $(id -u):$(id -g)`, либо `chown` их потом.
