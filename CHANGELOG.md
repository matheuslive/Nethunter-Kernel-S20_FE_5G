# Changelog

## 2026-10-24

- **03:28 Alterado:** versão v4.10 do kernel e do companion ([5fecd63](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/5fecd63fe))
- **03:28 Alterado:** RT8547: o valor 2000 do `rear_flash` liga a lanterna no degrau 0 (25 mA) ([165c0af](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/165c0afdb))
- **03:28 Alterado:** battery_v2 sem `#define DEBUG` e com os prints de leitura do sysfs/get_property em `pr_debug` (spam do kmsg) ([fd873d2](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/fd873d231))
- **03:27 Alterado:** `kernel/signal.c` deixa de logar o SIGSEGV de fault em 0 no system_server (checagem implícita de suspend do ART) ([bff174a](https://github.com/matheuslive/Nethunter-Kernel-S20_FE_5G/commit/bff174af2))
