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
for bin in hid-keyboard usbwifi wmon; do
  [ -f "$MODPATH/system/bin/$bin" ] && set_perm "$MODPATH/system/bin/$bin" 0 0 0755
done

FWCOUNT=$(find "$MODPATH/system/etc/firmware" -type f 2>/dev/null | wc -l)
ui_print "- Drivers de dongle WiFi vem como .ko (nao mais built-in),"
ui_print "  com $FWCOUNT firmwares para /etc/firmware:"
ui_print "    usbwifi        carrega o driver do dongle plugado"
ui_print "    usbwifi -l     lista os drivers disponiveis"
ui_print "    wmon           monitor + airodump-ng (usa o dongle wlan1)"
ui_print "  O ath9k_htc (AR9271) e carregado no boot (service.sh): o dongle"
ui_print "  vira wlan1 sozinho ao plugar, sem rodar usbwifi."

# --- uso imediato, sem reboot ------------------------------------------------
#
# O magic mount so acontece no boot. Ate la, publicamos as tres coisas na mao:
#
#  binarios  -> /debug_ramdisk, o tmpfs do proprio Magisk (MAGISKTMP). E o
#               PRIMEIRO diretorio do PATH, inclusive no PATH do su, e some no
#               reboot -- exatamente quando o magic mount assume o /system/bin.
#  .ko       -> nada a fazer: o usbwifi procura os modulos tambem no diretorio
#               do modulo em /data/adb (ver o proprio usbwifi).
#  firmware  -> SO no reboot. Antes o pacote montava um overlay sobre
#               /vendor/firmware para valer na hora; agora o firmware vai para
#               /etc/firmware (= /system/etc/firmware), que nao existe no stock,
#               entao nao ha o que sobrepor sem reboot. O magic mount cria o
#               diretorio no boot. So precisamos deixar o contexto SELinux certo
#               no $MODPATH para o ueventd conseguir ler depois do reboot.
ui_print "- Publicando sem reboot:"

for bin in hid-keyboard usbwifi wmon; do
  SRC=$MODPATH/system/bin/$bin
  if [ -d /debug_ramdisk ] && cp -f "$SRC" "/debug_ramdisk/$bin" 2>/dev/null; then
    chmod 0755 "/debug_ramdisk/$bin"
    ui_print "    $bin ja esta no PATH"
  else
    ui_print "  ! $bin so depois do reboot ($MODPATH/system/bin/$bin)"
  fi
done

# O ueventd so le o firmware do fallback se o contexto for vendor_firmware_file
# (o mesmo de /vendor/firmware, que e por onde isto foi validado). O magic mount
# preserva o label do arquivo no $MODPATH, entao basta rotular aqui.
FWSRC=$MODPATH/system/etc/firmware
[ -d "$FWSRC" ] && chcon -R u:object_r:vendor_firmware_file:s0 "$FWSRC" 2>/dev/null
ui_print "    firmware ($FWCOUNT) so em /etc/firmware apos o reboot"

ui_print "- Instalado. O reboot troca estes atalhos pelo magic mount."
