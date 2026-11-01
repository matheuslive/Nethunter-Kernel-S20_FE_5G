# Changelog

## 2026-11-01

- **16:46 Alterado:** v4.12 (`dc_step_chg_*` + `batt_siop_*`) buildada do zero e gravada no S20 com o Android ligado (md5 relido `d0986046…`; backup da v4.11 em `build/r8q/boot-v4.11-2026-11-01.img`), reboot com o usuário ([3a5a3c9b2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/3a5a3c9b2625030c0799c22012f6705158047945))
- **16:46 Corrigido:** `tools/flash-booted.sh` nomeava o backup com a versão do kernel NOVO (lia o `u/kernel` depois de trocá-lo) ([3a5a3c9b2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/3a5a3c9b2625030c0799c22012f6705158047945))
- **15:54 Implementado:** `batt_siop_*` pelo sysfs (10 tetos de corrente do SIOP por tipo de cabo, faixa validada, vale na hora; o 1800 fixo da carga com fio no SIOP passa a ler o `siop_charging_limit_current`), entra na v4.12 junto do dc step, não gravada ([abc2f79](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/abc2f795a), [docs/siop-sysfs.md](docs/siop-sysfs.md))
- **16:09 Implementado:** `dc_step_chg_*` pelo sysfs (tabelas da carga rápida de 25 W: `val_iout`/`val_vfloat`/`cond_vol`/`cond_soc` graváveis só para baixo do DT, `cond_iin`/`info` leitura), kernel v4.12 provisória, não gravada ([14245bd](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/14245bd80), [README](packaging/magisk-battery/README.md))
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
