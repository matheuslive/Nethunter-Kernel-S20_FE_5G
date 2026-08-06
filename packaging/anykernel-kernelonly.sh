# AnyKernel3 Ramdisk Mod Script -- variante KERNEL-ONLY
# osm0sis @ xda-developers (base) / enxugado para nao tocar particoes
#
# Esta versao SO substitui o kernel (zImage) no boot.img e deixa o magiskboot
# repatchar o Magisk automaticamente. Toda a parte "NetHunter additions" do
# anykernel.sh original -- que escrevia em /system_root, /vendor e /system/lib
# -- foi removida: essas particoes sao read-only (super dinamica, A13 SAR) e
# aquelas edicoes ou falhavam em silencio ou arriscavam bootloop/AVB.
#
# O que ia nelas (modulos .ko, hid-keyboard, init HID) agora vem no modulo
# Magisk companion, que faz a mesma coisa de forma system-less e reversivel.

## AnyKernel setup
# begin properties
properties() { '
kernel.string=r8q Nethunter kernel (kernel-only) by Svirusx @ xda-developers
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=r8q
device.name2=r8qxxx
device.name3=r8qxx
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/platform/soc/1d84000.ufshc/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel install
dump_boot;

# begin ramdisk changes

if [ -d $ramdisk/.backup ]; then
  patch_cmdline "skip_override" "skip_override";
else
  patch_cmdline "skip_override" "";
fi;

# end ramdisk changes

write_boot;
## end install
