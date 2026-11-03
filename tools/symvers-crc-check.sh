#!/bin/sh
# symvers-crc-check.sh <Module.symvers antigo> <Module.symvers novo>
#
# Diz se os .ko compilados contra o kernel antigo continuam carregando no novo.
# Com CONFIG_MODVERSIONS o vermagic ignora a release (same_magic() em
# kernel/module.c): o que barra o insmod e o CRC de cada simbolo importado.
# Por isso o criterio e um join por nome das linhas "vmlinux": todo simbolo do
# antigo tem de existir no novo com o MESMO CRC. Simbolos novos (ex.: os do
# KernelSU) sao permitidos -- o `build.sh --companion-only` exige igualdade
# exata, que e mais forte do que isto.
#
# Saida: contagens + os divergentes/ausentes; exit 0 = compativel, 1 = nao.
set -eu
[ $# -eq 2 ] || { echo "uso: $0 <symvers antigo> <symvers novo>" >&2; exit 2; }
awk -F'\t' '
	FNR == NR { if ($3 == "vmlinux") old[$2] = $1; next }
	$3 == "vmlinux" { new[$2] = $1 }
	END {
		for (s in old) {
			if (!(s in new)) { printf "ausente  %s\n", s; bad++ }
			else if (new[s] != old[s]) { printf "CRC     %s %s -> %s\n", s, old[s], new[s]; bad++ }
			else same++
		}
		for (s in new) if (!(s in old)) added++
		printf ">> iguais: %d, novos: %d, divergentes/ausentes: %d\n", same, added, bad
		exit bad ? 1 : 0
	}' "$1" "$2"
