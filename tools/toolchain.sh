# shellcheck shell=bash
# Toolchain do kernel, FORA do repo (docs/build.md). Carregado (source) pelo
# build.sh, tools/repro-release.sh e tools/build-nomount.sh; nao executar.
#
# Uma pasta so, compartilhada por todos os checkouts/worktrees e somente
# leitura (antes o toolchain/ versionado, 1,3 GB, ia para cada worktree):
#   $TOOLCHAINS/llvm-arm-toolchain-ship-10.0   clang 10.0.6 (Snapdragon LLVM)
#   $TOOLCHAINS/aarch64-linux-android-4.9      binutils 2.27 (as, ld, ar...)
#   $TOOLCHAINS/SHA256SUMS                     hash de cada arquivo
# TOOLCHAINS do ambiente vence. Recriar a pasta: docs/build.md.
#
# Uso: source tools/toolchain.sh; toolchain_check || exit 1
#      (define BUILD_CROSS_COMPILE e KERNEL_LLVM_BIN)
TOOLCHAINS=${TOOLCHAINS:-$HOME/Android/toolchains}
TC_CLANG_DIR=$TOOLCHAINS/llvm-arm-toolchain-ship-10.0
TC_GCC_DIR=$TOOLCHAINS/aarch64-linux-android-4.9
# O GCC 4.9 entra so como binutils via CROSS_COMPILE; quem compila e o clang.
BUILD_CROSS_COMPILE=$TC_GCC_DIR/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$TC_CLANG_DIR/bin/clang

toolchain_check() {
	local f ok=1
	for f in "$KERNEL_LLVM_BIN" "${BUILD_CROSS_COMPILE}ld" "${BUILD_CROSS_COMPILE}as"; do
		[ -x "$f" ] || { echo "!! toolchain: falta $f" >&2; ok=; }
	done
	if [ -z "$ok" ]; then
		echo "!! TOOLCHAINS=$TOOLCHAINS incompleto. Recriar a partir do historico" >&2
		echo "!! do git (ver docs/build.md, secao Toolchain)." >&2
		return 1
	fi
	# clang 10 linka libtinfo.so.5: sem ela o build morre no defconfig com um
	# enganoso "init/Kconfig:17: syntax error".
	if ! "$KERNEL_LLVM_BIN" --version >/dev/null 2>&1; then
		echo "!! $KERNEL_LLVM_BIN nao executa (falta libtinfo5:amd64?)" >&2
		return 1
	fi
	echo ">> toolchain: $TOOLCHAINS"
}

# ccache: chave do compilador = hash do clang (calculado uma vez por build; o
# compiler_check=content re-hashearia os 97 MB a cada chamada) e base_dir =
# o checkout ($1). Com o base_dir, os caminhos de dentro do checkout viram
# relativos ao objdir e os do toolchain (fora dele) ficam absolutos: o mesmo
# objeto tem a mesma chave em qualquer checkout/worktree. Com o base_dir
# global (~/Android) o -isystem/--gcc-toolchain do toolchain viraria
# ../../toolchains no principal e ../../../toolchains numa worktree (miss).
toolchain_ccache_env() {
	export CCACHE_COMPILERCHECK="string:$(sha256sum "$(readlink -f "$KERNEL_LLVM_BIN")" | cut -c1-16)"
	export CCACHE_BASEDIR=$1
}

# Checkout antigo (release anterior a remocao do toolchain/ do repo): confere
# que o toolchain/ versionado nele e byte a byte o externo, para reproduzir a
# release com o mesmo binario. Sem toolchain/ no checkout: nada a conferir.
toolchain_same_as_tree() {
	local kdir=$1
	[ -d "$kdir/toolchain" ] || return 0
	if [ ! -f "$TOOLCHAINS/SHA256SUMS" ]; then
		echo "!! falta $TOOLCHAINS/SHA256SUMS para comparar com $kdir/toolchain" >&2
		return 1
	fi
	echo ">> conferindo $kdir/toolchain contra $TOOLCHAINS (sha256)"
	if ! (cd "$kdir/toolchain" &&
	      sed -e 's#  llvm-arm-toolchain-ship-10.0/#  llvm-arm-toolchain-ship/10.0/#' \
	          -e 's#  aarch64-linux-android-4.9/#  gcc/linux-x86/aarch64/aarch64-linux-android-4.9/#' \
	          "$TOOLCHAINS/SHA256SUMS" | sha256sum -c --quiet); then
		echo "!! o toolchain/ de $kdir difere do externo: a release nao seria" >&2
		echo "!! reproduzida com o mesmo compilador. Use TOOLCHAINS=<pasta certa>." >&2
		return 1
	fi
}
