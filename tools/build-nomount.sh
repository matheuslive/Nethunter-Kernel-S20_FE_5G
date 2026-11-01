#!/bin/bash
#
# Compila o nomount (github.com/maxsteeel/nomount) como modulo externo
# (nomount.ko) contra o out/ de uma release reproduzida por
# tools/repro-release.sh, e o CLI nm para arm64 com o NDK.
#
# Uso:
#   tools/repro-release.sh v4.11 clean     # antes: out/ = a release gravada
#   tools/build-nomount.sh [versao]        # padrao: v4.11
#
# Variaveis: KDIR (checkout do kernel, padrao o principal), NOMOUNT_REF
# (padrao v2.2.0), NOMOUNT_GIT (padrao o GitHub), NDK.
#
# - Modulo externo (M=), sem symlink em fs/ nem mudanca no fonte do kernel. O
#   Makefile do nomount sobe a arvore atras de um .git cujo origin cite
#   "nomount" para por a contagem de commits na versao; o clone abaixo satisfaz.
# - A v2.2.0 compila na 4.19 sem patch e sem warning (o gcc-wrapper.py
#   transformaria warning em erro). Patches, se um dia precisar, vao em
#   tools/nomount-patches/*.patch e sao aplicados em ordem.
# - nm: freestanding (syscalls proprias, _start proprio), mesmas flags do CI
#   do nomount (zig cc), aqui com o clang do NDK.
# - Saida: $KDIR/build/r8q/<versao>/nomount/{nomount.ko,nm} + md5 + modinfo
#   (DEST= muda; os da v4.11 ficaram em build/r8q/nomount/).
set -euo pipefail

VER=${1:-v4.11}
HERE=$(dirname "$(readlink -f "$0")")
REPO=$(readlink -f "$HERE/..")
KDIR=${KDIR:-$(git -C "$HERE" worktree list --porcelain | awk 'NR==1{print $2}')}
KDIR=$(readlink -f "$KDIR")
NOMOUNT_REF=${NOMOUNT_REF:-v2.2.0}
NOMOUNT_GIT=${NOMOUNT_GIT:-https://github.com/maxsteeel/nomount}
NDK=${NDK:-$HOME/Android/Sdk/ndk/26.1.10909125}
VARIANT=r8q
VERSION=NetHunter_matheuslive_${VARIANT}_${VER}
OUT=$KDIR/out
SRC=$REPO/tmp/nomount-src
DEST=${DEST:-$KDIR/build/$VARIANT/$VER/nomount}   # v4.11 ficou em build/r8q/nomount

REL=$(cat "$OUT/include/config/kernel.release")
[ "$REL" = "4.19.113-$VERSION" ] || { echo "!! $OUT esta em $REL, nao $VER (rode tools/repro-release.sh $VER)" >&2; exit 1; }

# Fonte do nomount, limpo, no ref pedido, com os patches locais
[ -d "$SRC/.git" ] || git clone -q "$NOMOUNT_GIT" "$SRC"
git -C "$SRC" fetch -q --tags origin 2>/dev/null || true
git -C "$SRC" checkout -q -f "$NOMOUNT_REF"
git -C "$SRC" clean -qfdx
for p in "$HERE"/nomount-patches/*.patch; do
	[ -e "$p" ] || continue
	echo ">> patch $(basename "$p")"
	git -C "$SRC" apply "$p"
done
echo ">> nomount $(git -C "$SRC" describe --tags --always) ($(git -C "$SRC" rev-parse --short HEAD))"

BUILD_CROSS_COMPILE=$KDIR/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$KDIR/toolchain/llvm-arm-toolchain-ship/10.0/bin/clang
make -C "$KDIR" O="$OUT" ARCH=arm64 \
	CROSS_COMPILE="$BUILD_CROSS_COMPILE" REAL_CC="$KERNEL_LLVM_BIN" CFP_CC="$KERNEL_LLVM_BIN" \
	CLANG_TRIPLE=aarch64-linux-gnu- DTC_EXT="$KDIR/tools/dtc" CONFIG_BUILD_ARM64_DT_OVERLAY=y \
	LOCALVERSION="-$VERSION" \
	M="$SRC/kernel/src" CONFIG_NOMOUNT=m modules

# nm (CLI) para arm64
CLANG=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang
STRIP=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip
mkdir -p "$DEST"
"$CLANG" --target=aarch64-linux-android30 -Oz -mcmodel=tiny -static -nostdlib -ffreestanding \
	-fno-unwind-tables -fno-ident -Wno-invalid-noreturn -mllvm -enable-machine-outliner=always \
	-Wl,--entry=_start -Wl,--build-id=none \
	"$SRC/userspace/src/nm.c" -o "$DEST/nm"
"$STRIP" "$DEST/nm"

cp -f "$SRC/kernel/src/nomount.ko" "$DEST/nomount.ko"
"${BUILD_CROSS_COMPILE}strip" --strip-debug "$DEST/nomount.ko"
(cd "$DEST" && md5sum nomount.ko nm > md5.txt)
/sbin/modinfo "$DEST/nomount.ko" > "$DEST/modinfo.txt"
cat "$DEST/md5.txt" "$DEST/modinfo.txt"

# CRCs que o .ko importa (__versions) x Module.symvers salvo da release
SYMVERS=$KDIR/build/$VARIANT/$VER/Module.symvers
if [ -f "$SYMVERS" ]; then
	/sbin/modprobe --dump-modversions "$DEST/nomount.ko" > "$DEST/modversions.txt"
	awk 'NR==FNR { crc[$2] = $1; next }
	     { n++; if (!($2 in crc)) { print "!! ausente: " $2; bad++ }
	       else if (tolower(crc[$2]) != tolower($1)) { print "!! CRC diferente: " $2; bad++ } }
	     END { printf ">> CRCs: %d simbolos importados, %d divergentes\n", n, bad; exit bad > 0 }' \
		"$SYMVERS" "$DEST/modversions.txt"
else
	echo ">> aviso: $SYMVERS nao existe, CRCs nao conferidos"
fi
echo ">> saida em $DEST"
