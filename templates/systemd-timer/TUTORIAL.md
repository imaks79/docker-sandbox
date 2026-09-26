# Тренировка: cron vs systemd-timer, и PID 1 с init-системой и без

Тема из двух частей: сначала смотрим, как выглядят периодические задачи
и вообще управление процессами в **обычном** контейнере sandbox.sh (где
PID 1 — это просто `sleep infinity`, без какой-либо init-системы), а
потом — в **этом** шаблоне, где PID 1 — настоящий `systemd`.

## Часть 1. Без init-системы (обычная песочница)

Поднимите самый обычный контейнер — без всяких флагов:

```bash
./sandbox.sh cron-baseline
```

Посмотрите, кто внутри PID 1:

```bash
ps -p 1 -o pid,ppid,comm
```

Увидите `sleep` — это и есть тот самый `sleep infinity`, которым
sandbox.sh держит контейнер живым. Это НЕ init-система: он не следит за
дочерними процессами, не перезапускает упавшие сервисы, не "пожинает"
(reap) осиротевших детей.

### Ставим и запускаем cron вручную

```bash
apt-get update && apt-get install -y cron
service cron start
# или, если service недоступен без init:
cron -f &
```

Добавьте задачу — раз в минуту дописывать метку времени:

```bash
echo '* * * * * echo "$(date -Is) tick from cron" >> /workspace/cron.log' | crontab -
```

Подождите пару минут и проверьте:

```bash
tail -f /workspace/cron.log
```

### Проблема 1: никто не следит за cron

```bash
pkill cron
tail /workspace/cron.log   # новые строки перестали появляться
```

В отличие от systemd-сервиса с `Restart=on-failure`, здесь никто не
перезапустит демон — cron просто "умер молча", и узнать об этом можно
только вручную проверив, что процесс исчез (`pgrep cron`).

### Проблема 2: зомби-процессы

Запустите что-нибудь, что форкается и не дожидается потомка:

```bash
for i in $(seq 1 5); do
    (sleep 2 & true) &
done
wait
ps aux | grep -i defunct
```

В контейнере с полноценным init'ом (или PID 1, специально
предназначенным для reaping — например `tini`) такие "осиротевшие"
процессы подхватываются и убираются (reaped). Здесь же PID 1 — обычный
`sleep infinity`, который вызовом `wait()` не занимается: зомби
копятся, пока контейнер жив.

Уберите за собой:

```bash
./sandbox.sh rm cron-baseline
```

## Часть 2. С systemd как PID 1 (этот шаблон)

```bash
./sandbox.sh -i -t systemd-timer sysd
```

Флаг `-i` обязателен — без `--privileged` и монтирования
`/sys/fs/cgroup` systemd не сможет стартовать как PID 1 внутри
контейнера. **`--privileged` даёт контейнеру расширенный доступ к
хосту** — используйте этот шаблон только для обучения, не как основу
для чего-то ещё.

Дайте systemd несколько секунд на загрузку (может недолго ругаться
"System is booting up" на первые команды), затем проверьте PID 1:

```bash
docker exec -it sysd ps -p 1 -o pid,ppid,comm
```

Увидите `systemd` — теперь это настоящая init-система.

### Смотрим на предустановленный таймер

В образ уже добавлены `sandbox-demo.service` и `sandbox-demo.timer`
(рядом с этим файлом, `/etc/systemd/system/` внутри контейнера) — они
делают то же самое, что и cron-задача из Части 1, но через systemd:

```bash
docker exec -it sysd systemctl status sandbox-demo.timer
docker exec -it sysd systemctl enable --now sandbox-demo.timer
docker exec -it sysd systemctl list-timers
```

Подождите минуту-другую и посмотрите результат — здесь тоже пишется в
`/workspace`, то есть виден прямо на хосте:

```bash
tail -f ./workspace/systemd-timer.log
```

Логи самого юнита (в отличие от cron — не нужен отдельный лог-файл,
всё уже в journald):

```bash
docker exec -it sysd journalctl -u sandbox-demo.service
```

### Демонстрация автоперезапуска

Сравните с Проблемой 1 из Части 1. Поставьте cron и на этот раз опишите
его как systemd-сервис с автоперезапуском (в реальной жизни cron уже
идёт как systemd-сервис из коробки — тут делаем то же самое руками для
наглядности):

```bash
docker exec -it sysd bash -c '
cat > /etc/systemd/system/demo-cron.service <<EOF
[Unit]
Description=cron с автоперезапуском под systemd

[Service]
ExecStart=/usr/sbin/cron -f
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now demo-cron.service
'

docker exec -it sysd systemctl status demo-cron.service
docker exec -it sysd pkill -9 cron
sleep 3
docker exec -it sysd systemctl status demo-cron.service   # снова active — systemd перезапустил
```

### Проверяем зомби-процессы

Повторите тест из Части 1 внутри этого контейнера:

```bash
docker exec -it sysd bash -c 'for i in $(seq 1 5); do (sleep 2 & true) & done; wait; ps aux | grep -i defunct'
```

С systemd как PID 1 осиротевшие процессы должны нормально
подхватываться и не копиться (systemd, как и любой уважающий себя
init, реализует reaping).

## Итог

| | Обычная песочница (`sleep infinity`) | Этот шаблон (`systemd`) |
|---|---|---|
| PID 1 | `sleep infinity`, ничего не делает | `systemd`, полноценная init-система |
| Перезапуск упавшего демона | нет, вручную | да, через `Restart=` |
| Reaping зомби-процессов | нет | да |
| Периодические задачи | cron, без мониторинга | `systemd.timer` + `journalctl` |
| Цена | обычный контейнер | `--privileged`, cgroup mount |

Для большинства задач в этой песочнице (гонять скрипт, потестировать
пакет) init-система не нужна — `sleep infinity` работает прекрасно и
проще. Но если внутри контейнера должно жить несколько
взаимозависимых демонов с перезапуском и таймерами — вот для чего
нужен настоящий init, и вот какую цену (привилегии) он стоит.

## Очистка

```bash
./sandbox.sh rm sysd
```
