#!/system/bin/sh
# customize.sh -- roda no momento da instalacao pelo Magisk.

SKIPUNZIP=0

DEVICE=$(getprop ro.product.device)
KREL=$(uname -r)

ui_print "- Device: $DEVICE"
ui_print "- Kernel rodando: $KREL"

case "$DEVICE" in
  r8q|r8qxxx|r8qxx) ;;
  *)
    ui_print "! Este modulo e so para o Galaxy S20 FE 5G (r8q)."
    abort   "! Device '$DEVICE' nao suportado. Abortando."
    ;;
esac

# Os .ko so carregam se o kernel rodando for o Nethunter correspondente
# (CONFIG_MODVERSIONS + vermagic). Aviso, mas nao aborta: o modulo pode ser
# instalado antes do primeiro boot no kernel novo.
case "$KREL" in
  *NetHunter_matheuslive_r8q*) ui_print "- Kernel Nethunter detectado, ok." ;;
  *)
    ui_print "! ATENCAO: o kernel rodando nao parece ser o Nethunter r8q."
    ui_print "! Os modulos .ko so vao carregar depois de flashar o kernel"
    ui_print "! correspondente (vermagic tem que bater)."
    ;;
esac

ui_print "- Ajustando permissoes"
set_perm_recursive "$MODPATH" 0 0 0755 0644
for bin in hid-keyboard usbwifi; do
  [ -f "$MODPATH/system/xbin/$bin" ] && set_perm "$MODPATH/system/xbin/$bin" 0 0 0755
done

FWCOUNT=$(find "$MODPATH/system/vendor/firmware" -type f 2>/dev/null | wc -l)
ui_print "- Drivers de dongle WiFi vem como .ko (nao mais built-in),"
ui_print "  com $FWCOUNT firmwares para /vendor/firmware:"
ui_print "    usbwifi        carrega o driver do dongle plugado"
ui_print "    usbwifi -l     lista os drivers disponiveis"

ui_print "- Instalado. Reinicie para aplicar."
