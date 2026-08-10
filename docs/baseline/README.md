# Baseline da v4.4 — antes de flashar a v4.6

Capturada em **2026-08-10 20:00 -03**, com o aparelho rodando
`4.19.113-NetHunter_matheuslive_r8q_v4.4` (#26). Serve de ponto de comparação
para a primeira onda de otimização (v4.6).

## ⚠️ São DUAS janelas diferentes — não misturar

| Fonte | Janela | Zera quando |
|---|---|---|
| Contadores do kernel (`suspend_stats`, `wakeup_sources`, `cpuidle`, `/proc/interrupts`) | **46 h 43 min** de uptime | no boot |
| `dumpsys batterystats --charged` | **3 h 22 min** | na última carga completa (16:38 deste dia) |

Comparar um número de 46 h com um de 3 h dá conclusão errada. Depois de flashar,
**deixar rodar 24–48 h** antes de comparar os contadores do kernel, e comparar o
batterystats só entre janelas de duração parecida e uso parecido.

Nesta captura a tela estava **ligada** e ficou ligada 89,2% do tempo na bateria —
uso pesado, não idle. Uma comparação honesta precisa de um período de uso
semelhante do outro lado.

## Arquivos

- `v4.4-sistema.txt` — identificação, `suspend_stats`, PSI, cpufreq (policies,
  schedutil, `time_in_state`), cpuidle, core_ctl
- `v4.4-wakeups.txt` — `wakeup_sources` ordenado por `total_time` e o dump bruto
- `v4.4-recursos.txt` — memória/zram/vmstat, I/O e diskstats, TCP, bateria, GPU,
  thermal, `/proc/stat`, `/proc/interrupts`
- `v4.4-batterystats.txt` — `dumpsys batterystats --charged` (6453 linhas)
- `v4.4-uid-time-in-state.txt` — residência por frequência **por UID**
  (`CONFIG_CPU_FREQ_TIMES=y`)

## Números-chave

**Suspend — 25,6% de falha.** `success: 47977`, `fail: 16496`
(`failed_freeze: 5541`, `failed_suspend: 7104`, `failed_suspend_noirq: 327`).
Culpados registrados: `alarmtimer` e `0000:01:00.0` (PCIe), errno `-16` (EBUSY).

**Wakelocks, `total_time` acumulado em 46 h:**

| Wakelock | total_time | nota |
|---|---|---|
| `nfc_wake_lock` | 15,1 h | ainda ativo há 34,8 min na captura |
| `998000.qcom,qup_uart` | 13,5 h | UART do Bluetooth |
| `hal_bluetooth_lock` | 13,3 h | |
| `qcom_rx_wakelock` | 5,1 h | 2264 ativações só na janela do batterystats |
| `pca9468-charger-monitor` | 4,8 h | |

**Consumo estimado na janela de 3 h 22 min** (drain computado 2418 mAh, real
2655–2700): `cpu: 718 mAh` — **maior que a tela** (`screen: 566 mAh`).
`mobile_radio: 105`, `idle: 98,4`, `system_services: 58,2`, `audio: 57,1`.

**CPU em kernel space é alto:** UID 0 fechou `u=18m 13s` de user contra
**`s=1h 10m 17s` de system** numa janela de 3 h 22 min. UID 1000 tem
`u=50m 27s` / `s=38m 33s`. É exatamente o tipo de carga que os debugs de hot
path removidos na v4.6 encarecem — o que torna essa medição promissora.

**As 4 frequências mais baixas do little nunca são usadas.** Somando
`uid_time_in_state` sobre **todos** os UIDs, o tempo em 300000, 403200, 518400 e
614400 kHz é **exatamente 0**; tudo começa em 691200. Bate com
`scaling_min_freq=691200` contra `cpuinfo_min_freq=300000`, confirmado
persistente (não era boost transitório). Não é cooling device (todos em 0), não é
`/sys/power/cpufreq_min_limit` (-1) e não é `msm_performance` (`cpu_min_freq=0`).
**Falta descobrir quem impõe** — são os degraus mais eficientes do cluster.

**Memória sob pressão:** `MemFree` ~200 MB de 5,7 GB, zram 78% cheio (2,4 de
3 GB, `lzo-rle`), `swappiness=160`.

## Como comparar depois do flash

1. `uname -r` tem que dizer `v4.6`.
2. `cat /sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state` passa a
   responder (`CPU_FREQ_STAT=y`) — é a métrica principal, e agora dá para ver
   residência **do sistema todo**, não só por UID.
3. `cat /sys/block/sda/queue/scheduler` → `[deadline]`; e
   `cat /proc/sys/net/ipv4/tcp_congestion_control` → `cubic`.
4. `/proc/last_kmsg` tem que continuar existindo (preservado de propósito).
5. Repetir esta captura com os mesmos comandos e comparar seção por seção. O
   número mais direto de performance é a razão system/user do
   `Total cpu time` no batterystats, para carga parecida.
