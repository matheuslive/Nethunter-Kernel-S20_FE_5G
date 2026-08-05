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
DTS_DIR=$OUT/arch/$ARCH/boot/dts

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

# Coleta os modulos ANTES de criar o $AK3 -- ele mora dentro do $OUT, entao um
# find posterior acharia tambem as copias que acabamos de colocar la.
mapfile -t MODULES < <(find "$OUT" -path "$AK3" -prune -o -name '*.ko' -print)

# Copia de trabalho do AnyKernel3, recriada do zero para nao acumular
# modulo obsoleto de build anterior dentro do zip.
rm -rf "$AK3"
cp -a "$DIR/AnyKernel3" "$AK3"
cp -f "$OUT/arch/$ARCH/boot/Image.gz-dtb" "$AK3/zImage"

# Os .ko vao para system/lib/modules -- e o bloco NetHunter do anykernel.sh
# que os instala (install "/system/lib"), nao o do.modules do AnyKernel.
mkdir -p "$AK3/system/lib/modules"
rm -f "$DIST/modules"/*.ko
if [ ${#MODULES[@]} -gt 0 ]; then
	cp -f "${MODULES[@]}" "$AK3/system/lib/modules/"
	cp -f "${MODULES[@]}" "$DIST/modules/"
fi

# Zip flashavel
rm -f "$DIST/$VERSION.zip"
(cd "$AK3" && zip -qr9 "$DIST/$VERSION.zip" ./* -x .git README.md '*placeholder')

echo
echo ">> $(cat "$OUT/include/config/kernel.release")"
echo ">> $DIST/$VERSION.zip ($(du -h "$DIST/$VERSION.zip" | cut -f1))"
ls -1 "$DIST/modules"
