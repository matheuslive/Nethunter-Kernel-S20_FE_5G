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
  [ -f "$MODPATH/system/bin/$bin" ] && set_perm "$MODPATH/system/bin/$bin" 0 0 0755
done

FWCOUNT=$(find "$MODPATH/system/vendor/firmware" -type f 2>/dev/null | wc -l)
ui_print "- Drivers de dongle WiFi vem como .ko (nao mais built-in),"
ui_print "  com $FWCOUNT firmwares para /vendor/firmware:"
ui_print "    usbwifi        carrega o driver do dongle plugado"
ui_print "    usbwifi -l     lista os drivers disponiveis"

# --- uso imediato, sem reboot ------------------------------------------------
#
# O magic mount so acontece no boot. Ate la, publicamos as tres coisas na mao:
#
#  binarios  -> /debug_ramdisk, o tmpfs do proprio Magisk (MAGISKTMP). E o
#               PRIMEIRO diretorio do PATH, inclusive no PATH do su, e some no
#               reboot -- exatamente quando o magic mount assume o /system/bin.
#  .ko       -> nada a fazer: o usbwifi procura os modulos tambem no diretorio
#               do modulo em /data/adb (ver o proprio usbwifi).
#  firmware  -> overlayfs sobre /vendor/firmware, e SO se os arquivos ainda nao
#               estiverem la. NAO usar "mount --bind": ele ESCONDERIA os 57
#               firmwares do aparelho (wifi interno, bluetooth, GPU) ate o
#               reboot; o overlay soma (lowerdir mantem os originais).
#               Nao adianta testar com "mountpoint": /vendor/firmware ja e um
#               tmpfs do Magisk desde o boot. O teste util e procurar um
#               arquivo nosso la dentro.
ui_print "- Publicando sem reboot:"

for bin in hid-keyboard usbwifi; do
  if [ -d /debug_ramdisk ] && cp -f "$MODPATH/system/bin/$bin" "/debug_ramdisk/$bin" 2>/dev/null; then
    chmod 0755 "/debug_ramdisk/$bin"
    ui_print "    $bin ja esta no PATH"
  else
    ui_print "  ! $bin so depois do reboot ($MODPATH/system/bin/$bin)"
  fi
done

FWSRC=$MODPATH/system/vendor/firmware
WORK=/data/adb/.nethunter-fw-work
SAMPLE=$(cd "$FWSRC" 2>/dev/null && find . -type f | head -1 | sed 's#^\./##')
if [ -z "$SAMPLE" ]; then
  :
elif [ -e "/vendor/firmware/$SAMPLE" ]; then
  ui_print "    $FWCOUNT firmwares ja estao em /vendor/firmware"
else
  rm -rf "$WORK"; mkdir -p "$WORK"
  # Mesmo contexto SELinux do diretorio original, senao o ueventd nao le.
  chcon -R u:object_r:vendor_firmware_file:s0 "$FWSRC" 2>/dev/null
  if mount -t overlay overlay \
       -o "lowerdir=/vendor/firmware,upperdir=$FWSRC,workdir=$WORK" \
       /vendor/firmware 2>/dev/null; then
    ui_print "    $FWCOUNT firmwares em /vendor/firmware (overlay, ate o reboot)"
  else
    rm -rf "$WORK"
    ui_print "  ! overlay do firmware falhou; dongle que precisa de firmware"
    ui_print "    so funciona depois do reboot"
  fi
fi

ui_print "- Instalado. O reboot troca estes atalhos pelo magic mount."
