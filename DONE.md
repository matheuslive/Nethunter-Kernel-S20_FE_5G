# DONE

- [x] Build local funcional do kernel Nethunter (`4.19.113-Nethunter_WirusMOD_r8q_v4.1`): resolvidos deps do host (bison/flex/libelf-dev), submodules CAN, e o fix do `-Wunused-function` que o `gcc-wrapper.py` da QCOM tornava fatal — 2026-08-06 (commit cffff32f1)
- [x] `build.sh` endurecido (set -euo pipefail, saída dentro do repo, remoção dos export inertes LLVM/CC/LD) — 2026-08-06 (commit 5b3c23d09)
- [x] Packaging separado: zip **kernel-only** (não toca partição read-only) + **módulo Magisk companion** (.ko/hid/init via overlay.d+magic mount) — 2026-08-06 (commit d61e3ce26)
- [x] `docs/diff-stock-vs-nethunter.md`: diff de config stock (via `/proc/config.gz` por SSH) vs Nethunter, categorizado — 2026-08-06 (commit 9affaf518)
- [x] Comparação dos 3 kernels (stock / Nethunter / not_samsung 4.19.325+KSU) e do driver qcacld (o `not` já tem monitor mode no source; porte desnecessário) — 2026-08-06
- [x] Diagnóstico completo do monitor mode no wlan0 interno (QCA6390): entra em monitor (radiotap) mas fixar canal deadlocka o driver → inviável para captura; dongle USB é o caminho — 2026-08-06 (ver memória do projeto)
