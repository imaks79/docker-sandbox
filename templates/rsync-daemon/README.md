# rsync-daemon — быстрая синхронизация файлов и инкрементальные бэкапы

Готовый к работе `rsync` в режиме daemon (протокол `rsync://`, без SSH):
собрали образ — сразу можно синхронизировать файлы с хостом или другой
машиной в локальной сети. Раздаёт модуль `workspace`, смотрящий в
`./workspace` на хосте.

## Быстрый старт

```bash
./sandbox.sh -p 873:873 -t rsync-daemon backup
```

С хоста:

```bash
# список модулей
rsync rsync://localhost:873/

# скопировать локальную папку В контейнер (в ./workspace на хосте)
rsync -av --port=873 ./my-folder/ rsync://sandbox@localhost/workspace/my-folder/
# пароль спросит интерактивно, либо переменной окружения:
RSYNC_PASSWORD=sandbox rsync -av --port=873 ./my-folder/ rsync://sandbox@localhost/workspace/my-folder/

# скопировать ИЗ контейнера на хост
rsync -av --port=873 rsync://sandbox@localhost/workspace/my-folder/ ./my-folder-copy/
```

Логин и пароль по умолчанию — `sandbox`/`sandbox`, см. переменные ниже.

## Переменные окружения

| Переменная | По умолчанию | Что это |
|---|---|---|
| `RSYNC_PORT` | `873` | порт демона |
| `RSYNC_SHARE_PATH` | `/workspace` | какую папку раздавать модулем `workspace` |
| `RSYNC_USER` | `sandbox` | логин |
| `RSYNC_PASSWORD` | `sandbox` | пароль |
| `RSYNC_READ_ONLY` | `false` | `true` — запретить запись, только скачивание |

Чтобы поменять — поправьте `ENV` в [`Dockerfile`](Dockerfile) и
пересоберите:

```bash
./sandbox.sh -t rsync-daemon rebuild backup
./sandbox.sh rm backup
./sandbox.sh -p 873:873 -t rsync-daemon backup
```

## Инкрементальные бэкапы

`rsync` сам по себе всегда копирует только разницу (delta-transfer) —
это уже экономит трафик и время на повторных синхронизациях одной и той
же папки. Но для бэкапов часто хочется ещё и **историю версий** — серию
снэпшотов, где не изменившиеся файлы не занимают место повторно.
Классический приём — захардлинкованные снэпшоты через `--link-dest`:

```bash
# на хосте, для каждого следующего бэкапа:
DATE=$(date +%F_%H%M)
rsync -av --port=873 \
    --link-dest=../latest \
    rsync://sandbox@localhost/workspace/data/ \
    ./backups/$DATE/
ln -sfn "$DATE" ./backups/latest
```

Каждый снэпшот в `./backups/<дата>/` выглядит как полная копия, но
файлы, не изменившиеся с прошлого бэкапа, — это хардлинки на предыдущую
версию (места на диске почти не занимают). Изменившиеся файлы
копируются заново. Так делают, например, `rsnapshot` и Time Machine.

## Диагностика

- Логи демона внутри контейнера: `docker exec backup cat /var/log/rsyncd.log`.
- `@ERROR: auth failed` — неверные логин/пароль, либо не тот `RSYNC_USER`.
- `rsync: failed to connect` — контейнер создавали без `-p 873:873`;
  опции применяются только при создании, нужно `./sandbox.sh rm backup`
  и создать заново с нужным пробросом порта.
