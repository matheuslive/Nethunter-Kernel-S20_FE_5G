#!/system/bin/sh
# customize.sh -- roda no momento da instalacao pelo Magisk.

SKIPUNZIP=0

DEVICE=$(getprop ro.product.device)
KREL=$(uname -r)
PSY=/sys/class/power_supply/battery
CONF=/data/adb/nethunter-battery.conf

ui_print "- Device: $DEVICE"
ui_print "- Kernel rodando: $KREL"

case "$DEVICE" in
  r8q|r8qxxx|r8qxx) ;;
  *)
    ui_print "! Este modulo e so para o Galaxy S20 FE 5G (r8q)."
    abort   "! Device '$DEVICE' nao suportado. Abortando."
    ;;
esac

[ -d "$PSY" ] || abort "! $PSY nao existe -- driver sec_battery ausente. Abortando."

# Os batt_tune_* so existem com CONFIG_ENG_BATTERY_CONCEPT=y. Sem eles o modulo
# ainda serve (limite de carga, slate mode, store mode), entao so avisamos.
if [ -e "$PSY/batt_tune_float_voltage" ]; then
  ui_print "- Kernel com ENG_BATTERY_CONCEPT: tuning completo disponivel."
else
  ui_print "! Kernel sem CONFIG_ENG_BATTERY_CONCEPT."
  ui_print "! Disponivel: FULL_CAPACITY (limite de carga), slate e store mode."
  ui_print "! Float voltage, correntes e limites termicos exigem o kernel"
  ui_print "! Nethunter r8q v4.3 ou mais novo."
fi

# A configuracao mora em /data/adb (fora do modulo) para sobreviver a update e
# a reinstalacao. Nunca sobrescrever uma existente.
if [ -f "$CONF" ]; then
  ui_print "- Configuracao ja existe, preservada: $CONF"
else
  cp -f "$MODPATH/nethunter-battery.conf.example" "$CONF"
  ui_print "- Configuracao criada (tudo comentado = nada muda): $CONF"
fi
set_perm "$CONF" 0 0 0644
rm -f "$MODPATH/nethunter-battery.conf.example" "$MODPATH/README.md"

ui_print "- Ajustando permissoes"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/battctl" 0 0 0755

# --- uso imediato, sem reboot ------------------------------------------------
#
# O magic mount do /system/bin so acontece no boot, entao ate reiniciar o
# battctl nao estaria no PATH. /debug_ramdisk e o tmpfs do proprio Magisk
# (MAGISKTMP): e o PRIMEIRO diretorio do PATH -- inclusive no PATH que o su
# monta -- e some sozinho no reboot, quando o magic mount assume. Copia, nao
# symlink: o modulo ainda esta em modules_update/ e muda de lugar no boot.
if [ -d /debug_ramdisk ] && cp -f "$MODPATH/system/bin/battctl" /debug_ramdisk/battctl 2>/dev/null; then
  chmod 0755 /debug_ramdisk/battctl
  ui_print "- battctl disponivel AGORA (via /debug_ramdisk, sem reboot)"
  IMMEDIATE=1
else
  ui_print "! nao consegui publicar o battctl sem reboot; use o caminho completo:"
  ui_print "  sh $MODPATH/system/bin/battctl status"
  IMMEDIATE=0
fi

# Config ja preenchida de uma instalacao anterior: aplica agora, senao so teria
# efeito no proximo boot (quando o service.sh roda). Config toda comentada da
# "0 parametro(s) aplicado(s)" e nao muda nada.
if [ "$IMMEDIATE" = 1 ]; then
  /debug_ramdisk/battctl apply 2>&1 | while read -r l; do ui_print "  $l"; done
fi

ui_print " "
ui_print "  battctl status              estado e parametros ativos"
ui_print "  battctl limit 80            para de carregar em 80%"
ui_print "  battctl set FLOAT_VOLTAGE 4200"
ui_print "  battctl show                chaves, faixas e a configuracao"
ui_print " "
ui_print "- Instalado. Nada e aplicado ate voce configurar."
