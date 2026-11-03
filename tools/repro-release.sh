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
# - clean: apaga $KDIR/out antes (build do zero). Mesmo com clean, o ccache
#   reaproveita os objetos do cache (minutos, nao ~25 min), como no build.sh
#   (sem ccache se o defconfig tiver CONFIG_DEBUG_INFO=y).
# - RECACHE=1: comportamento antigo, CCACHE_RECACHE=1 (recompila tudo e regrava
#   o cache, nada vem dele). Usar se a comparacao abaixo falhar.
# - Rede de seguranca contra objeto corrompido (suspeita de bit flip de RAM do
#   host, que pode ter entrado no cache): a Image recompilada e comparada com a
#   do zip (cmp -l) e o tools/image-cmp-check.py SAI COM ERRO se algum byte
#   diferente cair fora das duas regioes esperadas, achadas pelo out/vmlinux: o
#   descriptor do GNU build-id (.notes, 20 B) e os digitos da data no
#   g_wlan_driver_version do qcacld (~6-7 B). v4.11: 27 B; v4.12: 26 B.
#   Tamanho diferente tambem e fatal.
# - So com a comparacao limpa: salva Module.symvers, vmlinux, .config,
#   linux_version.txt e image-cmp.txt em build/r8q/<versao>/ (o build.sh
#   salva os quatro primeiros a cada build; ver tools/build-nomount.sh).
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
# Mesma regra do build.sh: ccache quebra o link com CONFIG_DEBUG_INFO=y.
if command -v ccache >/dev/null 2>&1 &&
   ! grep -q '^CONFIG_DEBUG_INFO=y' "$KDIR/arch/$ARCH/configs/wirus_defconfig"; then
	REAL_CC="ccache $KERNEL_LLVM_BIN"
else
	REAL_CC=$KERNEL_LLVM_BIN
fi

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
if [ "${RECACHE:-0}" = 1 ]; then
	echo ">> RECACHE=1: ccache sem reaproveitar objeto (CCACHE_RECACHE=1)"
	export CCACHE_RECACHE=1
fi

# KernelSU-Next (v4.13+): patches locais no submodulo; no-op em arvore sem KSU
[ ! -e "$KDIR/tools/ksu-patches.sh" ] || "$KDIR/tools/ksu-patches.sh" "$KDIR"

make "${MAKE_ARGS[@]}" wirus_defconfig
nice make -j"$JOBS" "${MAKE_ARGS[@]}"

REL=$(cat "$OUT/include/config/kernel.release")
[ "$REL" = "4.19.113-$VERSION" ] || { echo "!! kernel.release inesperado: $REL" >&2; exit 1; }

# Comparacao com a Image da release (fatal fora das regioes esperadas)
zcat "$OUT/arch/$ARCH/boot/Image.gz-dtb" > "$WORK/repro.Image" 2>/dev/null || true
S_REL=$(stat -c %s "$WORK/release.Image") S_REP=$(stat -c %s "$WORK/repro.Image")
echo ">> Image release: $S_REL B, repro: $S_REP B"
cmp -l "$WORK/release.Image" "$WORK/repro.Image" > "$WORK/cmp.txt" 2>/dev/null || true
echo ">> bytes diferentes: $(wc -l < "$WORK/cmp.txt") (lista em $WORK/cmp.txt)"
FAIL=
[ "$S_REL" = "$S_REP" ] || { echo "!! tamanhos diferentes" >&2; FAIL=1; }
"$(dirname "$(readlink -f "$0")")/image-cmp-check.py" "$OUT/vmlinux" "$WORK/cmp.txt" || FAIL=1
if [ -n "$FAIL" ]; then
	echo "!! a Image reproduzida NAO e a da release $VER: nada salvo em $SAVE." >&2
	echo "!! Causas provaveis: objeto corrompido no cache (bit flip de RAM), fonte ou" >&2
	echo "!! toolchain diferente, ou KDIR fora do caminho da release. Refazer com:" >&2
	echo "!!   RECACHE=1 $0 $VER clean" >&2
	exit 1
fi

mkdir -p "$SAVE"
cp -f "$OUT/Module.symvers" "$OUT/vmlinux" "$OUT/.config" "$SAVE/"
cp -f "$WORK/cmp.txt" "$SAVE/image-cmp.txt"
printf '%s\n' "$LV" > "$SAVE/linux_version.txt"
echo ">> salvos em $SAVE: Module.symvers vmlinux .config linux_version.txt image-cmp.txt"
