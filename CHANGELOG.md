# Changelog

## 2026-11-01

- **18:44 Removido:** `packaging/magisk-battery/` (cópia legada do battctl, parada desde 2026-10-08) e o zip de bateria do `build.sh`; a doc do lado do kernel (atributos, o que exige a NetHunter, armadilhas, inclusive a da float ao subir o degrau de age) foi para [docs/battery-sysfs.md](docs/battery-sysfs.md) ([5bc2abf00](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/5bc2abf00))
- **18:38 Validado:** `dc_step_chg_*` e `batt_siop_*` no aparelho com PPS 25 W: `iout` e teto APDO do SIOP mudam o `Ichg` na hora, valores inválidos dão `-EINVAL`; achado: subir o `batt_age_step` com cabo plugado não sobe a float do carregador até o próximo plug ([9aff11c07](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/9aff11c07), [DONE](DONE.md))
- **18:25 Alterado:** `build.sh` salva `Module.symvers`/`vmlinux`/`.config`/`linux_version.txt` em `build/r8q/<versão>/` a cada build (o `build-nomount.sh` roda direto depois, sem repro); `repro-release.sh` aproveita o ccache (`RECACHE=1` = antigo) e a comparação da Image ficou fatal pelo `tools/image-cmp-check.py` (só build-id e data do qcacld, achados pelo vmlinux) ([dcbf685](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/dcbf685d1), [docs/nomount.md](docs/nomount.md))
- **18:18 Alterado:** nomount v2.2.0 recompilado para a v4.12 (`tools/repro-release.sh v4.12 clean`: Image com 26 bytes de diferença, nenhum de código; 60/60 CRCs), saída por versão em `build/r8q/v4.12/nomount/`; instalado com o companion v4.12 e S20 reiniciado: v4.12 rodando, nomount assumiu 3 módulos, `dc_step_chg_*`/`batt_siop_*` presentes, AGE_STEP=2 reaplicado ([d660430](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/d660430c3), [docs/nomount.md](docs/nomount.md))
- **16:46 Alterado:** v4.12 (`dc_step_chg_*` + `batt_siop_*`) buildada do zero e gravada no S20 com o Android ligado (md5 relido `d0986046…`; backup da v4.11 em `build/r8q/boot-v4.11-2026-11-01.img`), reboot com o usuário ([3a5a3c9b2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/3a5a3c9b2625030c0799c22012f6705158047945))
- **16:46 Corrigido:** `tools/flash-booted.sh` nomeava o backup com a versão do kernel NOVO (lia o `u/kernel` depois de trocá-lo) ([3a5a3c9b2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/3a5a3c9b2625030c0799c22012f6705158047945))
- **15:54 Implementado:** `batt_siop_*` pelo sysfs (10 tetos de corrente do SIOP por tipo de cabo, faixa validada, vale na hora; o 1800 fixo da carga com fio no SIOP passa a ler o `siop_charging_limit_current`), entra na v4.12 junto do dc step, não gravada ([abc2f79](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/abc2f795a), [docs/siop-sysfs.md](docs/siop-sysfs.md))
- **16:09 Implementado:** `dc_step_chg_*` pelo sysfs (tabelas da carga rápida de 25 W: `val_iout`/`val_vfloat`/`cond_vol`/`cond_soc` graváveis só para baixo do DT, `cond_iin`/`info` leitura), kernel v4.12 provisória, não gravada ([14245bd](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/14245bd80), [docs/battery-sysfs.md](docs/battery-sysfs.md))
- **15:14 Incluído:** `tools/otg-tx-test.sh` (AR9271 num netns próprio, associado à OpenWRT, `iperf3` em upload vigiando `overcurrent`); OTG em 1500 mA validado: 55 Mbit/s por 60 s sem sobrecorrente ([f5ba6b51e](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/f5ba6b51e848e102d0f4e7693b310dfab24c1f69))
- **14:14 Alterado:** `docs/nomount.md` com o teste de fumaça no S20 (insmod, redirecionamento, whiteout, sem Oops) ([84dce12](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/84dce12af))
- **14:11 Incluído:** `tools/repro-release.sh` (reproduz uma release sem empacotar, compara a Image e salva `Module.symvers`/`vmlinux`) e `tools/build-nomount.sh` (nomount v2.2.0 como `.ko` externo e o CLI `nm` para a v4.11 gravada, sem patch, 60/60 CRCs) ([9d10a87](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/9d10a877e), [docs/nomount.md](docs/nomount.md))

## 2026-10-26

- **13:32 Implementado:** companion v4.11.1 com os módulos USB/IP (`usbip-core`, `vhci-hcd`, `usbip-host`), carregados no boot; o vmlinux é o mesmo da v4.11 ([2c8cea9](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/2c8cea935))

## 2026-10-24

- **15:16 Incluído:** `tools/flash-booted.sh`, grava o kernel de um zip pelo magiskboot com o Android ligado, com backup e md5 relido ([23af48a](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/23af48a46))
- **14:44 Alterado:** versão v4.11 do kernel e do companion ([3bfdf6d](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/3bfdf6d8b))
- **14:23 Implementado:** RT8547: `rear_torch_ua` (corrente da lanterna em µA; abaixo de 25 mA, PWM de 1 kHz no FLEN por hrtimer, piso de 5 %) e `rear_torch_max_s` (teto de tempo) ([d14aad2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/d14aad20b))
- **03:28 Alterado:** versão v4.10 do kernel e do companion ([5fecd63](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/5fecd63fe))
- **03:28 Alterado:** RT8547: o valor 2000 do `rear_flash` liga a lanterna no degrau 0 (25 mA) ([165c0af](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/165c0afdb))
- **03:28 Alterado:** battery_v2 sem `#define DEBUG` e com os prints de leitura do sysfs/get_property em `pr_debug` (spam do kmsg) ([fd873d2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/fd873d231))
- **03:27 Alterado:** `kernel/signal.c` deixa de logar o SIGSEGV de fault em 0 no system_server (checagem implícita de suspend do ART) ([bff174a](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/bff174af2))
