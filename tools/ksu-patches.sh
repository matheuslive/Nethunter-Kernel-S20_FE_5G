#!/bin/sh
# ksu-patches.sh [<arvore do kernel>]
#
# Aplica patches/kernelsu-next/*.patch no submodulo KernelSU-Next/ (tag
# v3.4.0-legacy), de forma idempotente: patch ja aplicado e pulado, patch que
# nao aplica nem reverte e erro fatal. Fica no working tree do submodulo (o
# git status do kernel mostra "modified content" nele): o commit do
# submodulo continua o da tag, entao a versao do driver (git rev-list --count
# + 289 = 33294) nao muda. Chamado pelo build.sh e pelo repro-release.sh antes
# do make; ver docs/kernelsu.md.
set -eu
K=$(readlink -f "${1:-$(dirname "$0")/..}")
S=$K/KernelSU-Next
# arvore de antes da v4.13 (sem KernelSU): nada a fazer
grep -q 'path = KernelSU-Next' "$K/.gitmodules" 2>/dev/null || exit 0
[ -e "$S/kernel/Kbuild" ] || { echo "!! $S vazio: git submodule update --init KernelSU-Next" >&2; exit 1; }
for p in "$K"/patches/kernelsu-next/*.patch; do
	[ -e "$p" ] || continue
	n=${p##*/}
	if git -C "$S" apply --check "$p" 2>/dev/null; then
		git -C "$S" apply "$p" && echo ">> KernelSU-Next: aplicado $n"
	elif git -C "$S" apply -R --check "$p" 2>/dev/null; then
		echo ">> KernelSU-Next: $n ja aplicado"
	else
		echo "!! KernelSU-Next: $n nao aplica (submodulo fora da tag?)" >&2
		exit 1
	fi
done
