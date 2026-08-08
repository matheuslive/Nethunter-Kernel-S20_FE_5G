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

ui_print " "
ui_print "  battctl status              estado e parametros ativos"
ui_print "  battctl limit 80            para de carregar em 80%"
ui_print "  battctl set FLOAT_VOLTAGE 4200"
ui_print "  battctl show                chaves, faixas e a configuracao"
ui_print " "
ui_print "- Instalado. Nada e aplicado ate voce configurar."
