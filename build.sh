#!/bin/bash
#
# Build do kernel Nethunter para o Galaxy S20 FE 5G (r8q / SM-G781x).
#
# Tudo que e gerado fica dentro do repo (ver .gitignore):
#   out/              objdir do kbuild (~6 GB)
#   out/AnyKernel3/   copia de trabalho do template AnyKernel3/ (recriada a cada build)
#   build/<variant>/  entregaveis: zip flashavel, dtb.img, dtbo.img e os modulos
#
# Uso:
#   ./build.sh          build incremental + empacota o zip
#   ./build.sh clean    apaga o objdir (forca build do zero na proxima vez)
#
set -euo pipefail

DIR=$(readlink -f "$(dirname "$0")")
cd "$DIR"

DEFCONFIG_NAME=wirus_defconfig
CHIPSET_NAME=kona
VARIANT=r8q
ARCH=arm64
VERSION=Nethunter_WirusMOD_${VARIANT}_v4.1
JOBS=$(nproc)

OUT=$DIR/out
DIST=$DIR/build/$VARIANT
AK3=$OUT/AnyKernel3
MAG=$OUT/magisk
DTS_DIR=$OUT/arch/$ARCH/boot/dts

# Versao do modulo Magisk companion (versionCode tem que ser inteiro).
MOD_VERSION=v4.1
MOD_VERSIONCODE=41

# Toolchain versionado no proprio repo. O GCC 4.9 entra so como binutils
# (as, ld, ar...) via CROSS_COMPILE; quem compila e o clang do REAL_CC.
# O Makefile deste kernel define CC = python scripts/gcc-wrapper.py $(REAL_CC),
# e atribuicao em Makefile vence variavel de ambiente -- por isso exportar
# CC/LD/AR/LLVM=1 aqui nao teria efeito nenhum, tem que ser via linha de comando.
BUILD_CROSS_COMPILE=$DIR/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$DIR/toolchain/llvm-arm-toolchain-ship/10.0/bin/clang
CLANG_TRIPLE=aarch64-linux-gnu-

MAKE_ARGS=(
	-C "$DIR"
	O="$OUT"
	ARCH="$ARCH"
	CROSS_COMPILE="$BUILD_CROSS_COMPILE"
	REAL_CC="$KERNEL_LLVM_BIN"
	CFP_CC="$KERNEL_LLVM_BIN"
	CLANG_TRIPLE="$CLANG_TRIPLE"
	DTC_EXT="$DIR/tools/dtc"
	CONFIG_BUILD_ARM64_DT_OVERLAY=y
	LOCALVERSION="-$VERSION"
)

if [ "${1:-}" = "clean" ]; then
	echo ">> apagando $OUT"
	rm -rf "$OUT"
	exit 0
fi

# Os submodules em drivers/net/can sao obj-y: sem eles o build quebra no link.
if [ -f .gitmodules ] && [ -z "$(ls -A drivers/net/can/can-isotp 2>/dev/null)" ]; then
	echo ">> inicializando submodules"
	git submodule update --init --recursive
fi

# Compila o kernel
mkdir -p "$OUT"
make -j"$JOBS" "${MAKE_ARGS[@]}" "$DEFCONFIG_NAME"
make -j"$JOBS" "${MAKE_ARGS[@]}"

if [ ! -e "$OUT/arch/$ARCH/boot/Image.gz-dtb" ]; then
	echo "!! Image.gz-dtb nao foi gerada" >&2
	exit 1
fi

# Imagens de device tree
mkdir -p "$DIST/modules"
cat "$DTS_DIR"/vendor/qcom/*.dtb > "$DIST/dtb.img"
mapfile -t DTBO_FILES < <(find "$DTS_DIR/samsung/" -name "${CHIPSET_NAME}-sec-${VARIANT}-*-r*.dtbo")
"$DIR/tools/mkdtimg" create "$DIST/dtbo.img" --page_size=4096 "${DTBO_FILES[@]}"

# Coleta os modulos ANTES de mexer em $OUT/AnyKernel3|magisk (ambos moram
# dentro do $OUT; um find posterior acharia as copias que acabamos de por la).
mapfile -t MODULES < <(find "$OUT" \( -path "$AK3" -o -path "$MAG" \) -prune -o -name '*.ko' -print)
rm -f "$DIST/modules"/*.ko
[ ${#MODULES[@]} -gt 0 ] && cp -f "${MODULES[@]}" "$DIST/modules/"

# --- 1. Zip flashavel KERNEL-ONLY (nao toca particao; ver packaging/) --------
# So o zImage + o anykernel enxuto. Sem system/, vendor/, ramdisk-patch/,
# patch.d/, modules/, ak_patches/ -- essas eram as "NetHunter additions" que
# escreviam em particao read-only. O que ia nelas vai no modulo Magisk abaixo.
rm -rf "$AK3"
cp -a "$DIR/AnyKernel3" "$AK3"
rm -rf "$AK3"/system "$AK3"/vendor "$AK3"/ramdisk-patch "$AK3"/patch.d \
       "$AK3"/modules "$AK3"/ak_patches "$AK3"/.git
cp -f "$DIR/packaging/anykernel-kernelonly.sh" "$AK3/anykernel.sh"
cp -f "$OUT/arch/$ARCH/boot/Image.gz-dtb" "$AK3/zImage"

rm -f "$DIST/$VERSION.zip"
(cd "$AK3" && zip -qr9 "$DIST/$VERSION.zip" ./* -x README.md '*placeholder')

# --- 2. Modulo Magisk companion (.ko + hid-keyboard + init HID) --------------
rm -rf "$MAG"
cp -a "$DIR/packaging/magisk" "$MAG"
rm -f "$MAG/overlay.d/sbin/.gitkeep"
sed -i -e "s/@VERSION@/$MOD_VERSION/" -e "s/@VERSIONCODE@/$MOD_VERSIONCODE/" "$MAG/module.prop"

# .ko via magic mount
mkdir -p "$MAG/system/lib/modules"
[ ${#MODULES[@]} -gt 0 ] && cp -f "${MODULES[@]}" "$MAG/system/lib/modules/"

# hid-keyboard e descriptors HID (fontes do template AnyKernel3)
mkdir -p "$MAG/system/xbin" "$MAG/system/etc/nethunter"
cp -f "$DIR/AnyKernel3/system/xbin/hid-keyboard" "$MAG/system/xbin/"
cp -f "$DIR/AnyKernel3/ramdisk-patch"/*-descriptor.bin "$MAG/system/etc/nethunter/"

# init.nethunter.rc: importado no boot via overlay.d. Reaponta os descriptors
# de / (onde o ramdisk-patch os punha) para /system/etc/nethunter (magic mount).
sed -e 's#copy /\([a-z]*-descriptor.bin\)#copy /system/etc/nethunter/\1#' \
    "$DIR/AnyKernel3/ramdisk-patch/init.nethunter.rc" > "$MAG/overlay.d/sbin/init.nethunter.rc"

rm -f "$DIST/nethunter-companion-$VARIANT.zip"
(cd "$MAG" && zip -qr9 "$DIST/nethunter-companion-$VARIANT.zip" ./*)

echo
echo ">> $(cat "$OUT/include/config/kernel.release")"
echo ">> kernel   : $DIST/$VERSION.zip ($(du -h "$DIST/$VERSION.zip" | cut -f1))"
echo ">> companion: $DIST/nethunter-companion-$VARIANT.zip ($(du -h "$DIST/nethunter-companion-$VARIANT.zip" | cut -f1))"
echo ">> modulos  : $(ls "$DIST/modules" | tr '\n' ' ')"
