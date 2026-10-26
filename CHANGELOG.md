# Changelog

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
