#!/bin/bash
#
# LEGADO: script original da Samsung (defconfig stock vendor/r8q_eur_openx).
# O build deste repo e o ./build.sh. Mantido so como referencia; o toolchain
# agora vem de fora do repo (tools/toolchain.sh, docs/build.md).

export ARCH=arm64
mkdir out

. "$(pwd)/tools/toolchain.sh"
toolchain_check || exit 1
CLANG_TRIPLE=aarch64-linux-gnu-
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"

make -j8 -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE vendor/r8q_eur_openx_defconfig
make -j8 -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE

cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image
