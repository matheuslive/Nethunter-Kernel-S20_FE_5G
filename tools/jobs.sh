# shellcheck shell=bash
# -j do make pelo MemAvailable medido na hora. Carregado (source) pelo
# build.sh e pelo tools/repro-release.sh; nao executar.
#
# A RAM da workstation e disputada com as VMs do PVE, e o clang com pouca
# memoria segfaulta (Error 139/245). Regra: ~1 GB por job, 2 GB de margem,
# no maximo nproc e NO MINIMO MIN_JOBS (padrao 4). Se a memoria livre nao
# comporta o minimo, o build NAO comeca (a -j2 um build completo passa de
# 1 h; regra do usuario de 2026-11-26): libere memoria e rode de novo.
# JOBS ja definido no ambiente vence (e pula a checagem).
#
# Uso: source tools/jobs.sh; jobs_by_mem || exit 1   (define e exporta JOBS)
JOBS_GB_PER_JOB=1
JOBS_MARGIN_GB=2
jobs_by_mem() {
	if [ -n "${JOBS:-}" ]; then
		echo ">> -j$JOBS (JOBS do ambiente)"
		return 0
	fi
	local min=${MIN_JOBS:-4} max mem_gb need n
	max=$(nproc)
	[ "$min" -gt "$max" ] && min=$max
	mem_gb=$(awk '/^MemAvailable:/ { print int($2 / 1048576) }' /proc/meminfo)
	need=$(( min * JOBS_GB_PER_JOB + JOBS_MARGIN_GB ))
	if [ "$mem_gb" -lt "$need" ]; then
		echo "!! MemAvailable ${mem_gb} GB: o minimo de -j$min pede ${need} GB." >&2
		echo "!! Build nao iniciado. Libere memoria (VMs, browser) e rode de novo," >&2
		echo "!! ou force com JOBS=<n> / MIN_JOBS=<n> no ambiente." >&2
		return 1
	fi
	n=$(( (mem_gb - JOBS_MARGIN_GB) / JOBS_GB_PER_JOB ))
	[ "$n" -gt "$max" ] && n=$max
	JOBS=$n
	export JOBS
	echo ">> -j$JOBS (MemAvailable ${mem_gb} GB, minimo $min)"
}
