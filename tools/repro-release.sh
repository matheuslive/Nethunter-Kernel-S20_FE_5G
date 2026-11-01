#!/bin/bash
#
# Reproduz o build de uma release JA GRAVADA, sem empacotar nem publicar nada,
# para compilar .ko novos contra ela (CRCs do MODVERSIONS e vermagic iguais).
#
# Uso:
#   tools/repro-release.sh <versao> [clean]      ex.: tools/repro-release.sh v4.11 clean
#   KDIR=<checkout> JOBS=<n> tools/repro-release.sh ...
#
# - KDIR: checkout onde compilar (padrao: o checkout principal do repo). Tem de
#   ser o MESMO caminho da release: com O= o kbuild grava caminhos absolutos
#   (__FILE__ de WARN/BUG), e a comparacao byte a byte so vale assim.
# - Os carimbos KBUILD_BUILD_TIMESTAMP/USER/HOST/VERSION saem da string
#   "Linux version" da Image dentro de build/r8q/NetHunter_matheuslive_r8q_<versao>.zip.
# - clean: apaga $KDIR/out antes (build do zero). O ccache roda com
#   CCACHE_RECACHE=1: recompila tudo e regrava o cache (nao reaproveita objeto
#   possivelmente corrompido por bit flip de RAM).
# - No fim: compara a Image recompilada com a do zip (cmp -l) e salva
#   Module.symvers, vmlinux e .config em build/r8q/<versao>/.
#
# Nao roda a parte de empacotamento/publicacao do build.sh (zips na raiz e no SD).
set -euo pipefail

VER=${1:?uso: $0 <versao> [clean]}
KDIR=${KDIR:-$(git -C "$(dirname "$(readlink -f "$0")")" worktree list --porcelain | awk 'NR==1{print $2}')}
KDIR=$(readlink -f "$KDIR")
JOBS=${JOBS:-4}
VARIANT=r8q
ARCH=arm64
VERSION=NetHunter_matheuslive_${VARIANT}_${VER}
OUT=$KDIR/out
DIST=$KDIR/build/$VARIANT
ZIP=$DIST/$VERSION.zip
SAVE=$DIST/$VER
WORK=$OUT/repro-$VER

[ -f "$ZIP" ] || { echo "!! zip da release nao existe: $ZIP" >&2; exit 1; }
grep -q "^VERSION=NetHunter_matheuslive_\${VARIANT}_$VER\$" "$KDIR/build.sh" ||
	echo ">> aviso: build.sh de $KDIR nao esta em $VER (confira o fonte)"

if [ "${2:-}" = "clean" ]; then
	echo ">> apagando $OUT"
	rm -rf "$OUT"
fi
mkdir -p "$WORK"

# Image da release e seus carimbos
unzip -p "$ZIP" zImage > "$WORK/release.Image.gz-dtb"
zcat "$WORK/release.Image.gz-dtb" > "$WORK/release.Image" 2>/dev/null || true
strings "$WORK/release.Image" > "$WORK/release.strings"   # sem pipe: grep -m1 + pipefail = SIGPIPE
LV=$(grep -m1 '^Linux version ' "$WORK/release.strings")
echo ">> release: $LV"
# Linux version <rel> (<user>@<host>) (<compilador>) #<n> SMP PREEMPT <data>
B_USER=$(sed -E 's/^Linux version [^ ]+ \(([^@]+)@([^)]+)\).*/\1/' <<<"$LV")
B_HOST=$(sed -E 's/^Linux version [^ ]+ \(([^@]+)@([^)]+)\).*/\2/' <<<"$LV")
B_VERS=$(sed -E 's/.*\) #([0-9]+) .*/\1/' <<<"$LV")
B_TS=$(sed -E 's/.* #[0-9]+ SMP PREEMPT //' <<<"$LV")
echo ">> KBUILD_BUILD_USER=$B_USER HOST=$B_HOST VERSION=$B_VERS TIMESTAMP=$B_TS"

BUILD_CROSS_COMPILE=$KDIR/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$KDIR/toolchain/llvm-arm-toolchain-ship/10.0/bin/clang
if command -v ccache >/dev/null 2>&1; then REAL_CC="ccache $KERNEL_LLVM_BIN"; else REAL_CC=$KERNEL_LLVM_BIN; fi

# Mesmos MAKE_ARGS do build.sh
MAKE_ARGS=(
	-C "$KDIR"
	O="$OUT"
	ARCH="$ARCH"
	CROSS_COMPILE="$BUILD_CROSS_COMPILE"
	REAL_CC="$REAL_CC"
	CFP_CC="$KERNEL_LLVM_BIN"
	CLANG_TRIPLE=aarch64-linux-gnu-
	DTC_EXT="$KDIR/tools/dtc"
	CONFIG_BUILD_ARM64_DT_OVERLAY=y
	LOCALVERSION="-$VERSION"
)
export KBUILD_BUILD_USER=$B_USER KBUILD_BUILD_HOST=$B_HOST
export KBUILD_BUILD_VERSION=$B_VERS KBUILD_BUILD_TIMESTAMP=$B_TS
export CCACHE_RECACHE=1

make "${MAKE_ARGS[@]}" wirus_defconfig
nice make -j"$JOBS" "${MAKE_ARGS[@]}"

REL=$(cat "$OUT/include/config/kernel.release")
[ "$REL" = "4.19.113-$VERSION" ] || { echo "!! kernel.release inesperado: $REL" >&2; exit 1; }

# Comparacao com a Image da release
zcat "$OUT/arch/$ARCH/boot/Image.gz-dtb" > "$WORK/repro.Image" 2>/dev/null || true
echo ">> Image release: $(stat -c %s "$WORK/release.Image") B, repro: $(stat -c %s "$WORK/repro.Image") B"
cmp -l "$WORK/release.Image" "$WORK/repro.Image" > "$WORK/cmp.txt" || true
echo ">> bytes diferentes: $(wc -l < "$WORK/cmp.txt") (lista em $WORK/cmp.txt)"

mkdir -p "$SAVE"
cp -f "$OUT/Module.symvers" "$OUT/vmlinux" "$OUT/.config" "$SAVE/"
cp -f "$WORK/cmp.txt" "$SAVE/image-cmp.txt"
echo ">> salvos em $SAVE: Module.symvers vmlinux .config image-cmp.txt"
