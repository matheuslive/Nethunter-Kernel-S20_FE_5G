# shellcheck shell=bash
# -j do make pelo MemAvailable medido na hora. Carregado (source) pelo
# build.sh e pelo tools/repro-release.sh; nao executar.
#
# A RAM da workstation e disputada com as VMs do PVE, e o clang com pouca
# memoria segfaulta (Error 139/245). Regra: ~1 GB por job, 2 GB de margem,
# entre 2 e nproc. JOBS ja definido no ambiente vence.
#
# Uso: source tools/jobs.sh; jobs_by_mem   (define e exporta JOBS)
jobs_by_mem() {
	if [ -n "${JOBS:-}" ]; then
		echo ">> -j$JOBS (JOBS do ambiente)"
		return 0
	fi
	local mem_gb n
	mem_gb=$(awk '/^MemAvailable:/ { print int($2 / 1048576) }' /proc/meminfo)
	n=$(( mem_gb - 2 ))
	[ "$n" -gt "$(nproc)" ] && n=$(nproc)
	[ "$n" -lt 2 ] && n=2
	JOBS=$n
	export JOBS
	echo ">> -j$JOBS (MemAvailable ${mem_gb} GB)"
}
