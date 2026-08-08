#!/system/bin/sh
# service.sh -- roda em late_start (boot). Aplica o que esta no arquivo de
# configuracao e, se pedido, deixa o watchdog rodando.
#
# Espera o boot completar antes de aplicar: o framework Samsung mexe em
# batt_full_capacity ao restaurar o estado do "Proteger bateria", e quem
# escrever por ultimo vence. Aplicar antes disso seria trabalho perdido.

CONF=/data/adb/nethunter-battery.conf
LOG=/data/adb/nethunter-battery.log
BATTCTL=/system/xbin/battctl

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# Log rotativo simples: sem isto o watchdog engorda o arquivo para sempre.
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 65536 ] && mv -f "$LOG" "$LOG.1"

[ -f "$CONF" ] || exit 0

i=0
while [ "$(getprop sys.boot_completed)" != 1 ] && [ $i -lt 120 ]; do
	sleep 2
	i=$((i + 1))
done

delay=$(sed -n 's/^[[:space:]]*BOOT_DELAY_SEC[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' "$CONF" | tail -1)
sleep "${delay:-20}"

log "boot: aplicando $CONF"
sh "$BATTCTL" apply --boot

# Watchdog em background (nao faz nada se WATCHDOG_SEC estiver 0/ausente).
sh "$BATTCTL" watchdog &
