#!/usr/bin/env bash
#
# sandbox.sh всегда запускает контейнер как `docker run IMAGE sleep
# infinity` — но этому шаблону нужен именно systemd в роли PID 1, а не
# фоновый процесс. Поэтому аргументы от sandbox.sh ("sleep" "infinity")
# сюда приходят, но намеренно игнорируются: вместо них exec'аем systemd.
exec /sbin/init
