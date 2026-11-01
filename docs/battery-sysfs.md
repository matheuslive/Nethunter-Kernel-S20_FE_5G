# Bateria do r8q pelo sysfs — o que o kernel NetHunter expõe

O módulo Magisk que aplica estes ajustes no boot (`battctl`,
`/data/adb/nethunter-battery.conf`) **não mora mais neste repo** desde
2026-11-01: a cópia que ficava em `packaging/magisk-battery/` era legado
desde 2026-10-08 e foi removida. Aqui fica a parte do kernel: o que cada
atributo de `/sys/class/power_supply/battery/` faz, o que exige o kernel
NetHunter e as armadilhas do driver `sec_battery`. As correntes do SIOP
estão em [siop-sysfs.md](siop-sysfs.md).

## Por que via sysfs e não pelo device tree

Todos os números de carga do r8q vivem no device tree
(`arch/arm64/boot/dts/samsung/r8q/kona-sec-r8q-*-overlay-r*.dts`:
`battery,charging_current`, `battery,chg_float_voltage`, thresholds térmicos,
degraus do step charging). O boot image v2 deste device usa a **seção dtb
stock**, e o AnyKernel não substitui essa seção — ou seja, editar `.dts` no
kernel não chega ao aparelho. O que resta como superfície de controle é o
sysfs, e é nele que este módulo trabalha.

## O que exige o kernel NetHunter

| Parâmetro | Kernel stock | NetHunter r8q v4.3+ |
|---|---|---|
| `FULL_CAPACITY` (limite de carga) | ✅ | ✅ |
| slate mode, store mode | ✅ | ✅ |
| `SIOP_LEVEL` + `SIOP_LOCK`, `WC_*`, `SKIP_SWELLING`, `SAFETY_TIMER`, `WDT_KICK_DISABLE`, `BATTERY_CYCLE` | ✅ | ✅ |
| `FLOAT_VOLTAGE`, correntes, corrente de corte, limites térmicos, `WPC_TEMP_*` | ❌ | ✅ |
| `AGE_STEP` (exige **v4.5+**) | ❌ | ✅ |
| `dc_step_chg_*`, carga rápida de 25 W, e `batt_siop_*` (v4.12+) | ❌ | ✅ |

### SIOP e o `siop.sh` absorvido

`SIOP_LEVEL` é o throttle global de corrente: o framework o baixa com a tela
ligada ou o aparelho quente. `SIOP_LOCK=1` deixa o atributo em `0444` depois de
aplicar, e aí nem o framework nem o root escrevem nele (o `battctl` destranca
sozinho quando você manda um valor novo). Isso substitui o
`/data/adb/service.d/siop.sh`, que o instalador **importa e desativa**
(renomeia para `siop.sh.absorvido-pelo-modulo`) — manter os dois faria os dois
brigarem no boot. O `service.sh` do módulo roda depois do `sys.boot_completed`,
o que fecha melhor a janela em que o framework poderia escrever primeiro.

Travar o SIOP em 100 tira o principal freio térmico da carga; o que sobra para
conter calor é `CHG_TEMP_HIGH`/`CHG_TEMP_REC` + `CHG_LIMIT_CURRENT`.

### `BATTERY_CYCLE` não é cosmético

Define o degrau de *age forecast*, e com ele a float voltage e o "cheio". No
r8q os degraus são 0/300/400/700/1000 ciclos → 4380/4360/4340/4320/4270 mV.
Baixar o número devolve a tensão de célula nova, desfazendo a proteção que o
kernel aplica a uma velha. Depois de escrever, o `battctl` dispara
`battery_cycle_test`, que é quem chama o `sec_bat_aging_check()` — sem isso o
degrau só seria recalculado no próximo boot.

### `AGE_STEP` é o caminho direto (v4.5+)

O `BATTERY_CYCLE` chega no mesmo lugar **mentindo a contagem de ciclos**, que
também alimenta o `sec_bat_check_battery_health()` — você perde a leitura real
do desgaste junto. O `AGE_STEP` fixa o degrau sem tocar no contador: escreve em
`batt_age_step`, que chama o `sec_bat_set_aging_step()` direto, pulando o
recálculo por ciclos. `0` = célula nova (4380 mV no r8q), `4` = o último degrau.

Vale para o pacote inteiro — float, `swelling_normal_float_voltage`, tensão de
recarga e condição de cheio —, ao contrário do `FLOAT_VOLTAGE`, que só empurra
`VOLTAGE_MAX` ao charger e é desfeito por qualquer swelling/step charging.

É o único atributo deste sysfs que **recusa com `-EINVAL`** um valor inválido
em vez de aceitar e ignorar em silêncio; nele o código de retorno do write vale.
Se os dois estiverem no arquivo de configuração, o `AGE_STEP` é aplicado depois
do `BATTERY_CYCLE` e vence.

⚠️ A proteção existe por um motivo: numa célula com ~1700 ciclos, fixar o
degrau 0 é carregar a 4380 mV justamente o que já está gasto.

Os `batt_tune_*` só são criados com `CONFIG_ENG_BATTERY_CONCEPT=y`, habilitado
no `wirus_defconfig` a partir da v4.3. Sem eles o módulo instala e funciona,
apenas com o conjunto reduzido — o `customize.sh` avisa qual dos dois casos é o
seu.

### Carga rápida de 25 W: `dc_step_chg_*` (kernel v4.12+)

O *direct charging* (carregador PPS, cabo APDO) carrega em 3 passos que só
existiam no device tree. A partir da v4.12 o kernel os expõe em
`/sys/class/power_supply/battery/`. Cada atributo gravável lê e aceita
**uma lista com um inteiro por passo** (3 no r8q). `iout`, `vfloat` e
`cond_soc` têm uma linha por degrau de age e o atributo mexe só na do degrau
atual; `cond_vol` é uma tabela só, para todos os degraus (o aging apenas a
recorta para baixo):

| Atributo | O que é | No aparelho (degrau 2) |
|---|---|---|
| `dc_step_chg_val_iout` | corrente de saída de cada passo (mA) | `5290 4090 3670` |
| `dc_step_chg_val_vfloat` | float de cada passo (mV) | `4125 4250 4340`* |
| `dc_step_chg_cond_vol` | tensão que passa ao próximo passo (mV) | `4125 4250 4270`** |
| `dc_step_chg_cond_soc` | SOC que passa ao próximo passo (%) | `35 60 100` |
| `dc_step_chg_cond_iin` | só leitura: corrente de entrada da troca (mA) | `2045 1835 0` |
| `dc_step_chg_info` | só leitura: tipo, passo atual, valores e os do DT | — |

\* O DT diz 4380 no último passo; o age forecast já o recorta para a float do
degrau (4340 no degrau 2). \*\* O último valor das condições não é limiar de
nada (não há passo depois); o 4270 é sobra de um recorte do degrau 4 no boot.

```sh
B=/sys/class/power_supply/battery
cat $B/dc_step_chg_info
echo "4000 3500 3000" > $B/dc_step_chg_val_iout   # carga rápida mais fria
```

Regras (o `write` devolve **`-EINVAL`** e não grava nada se um valor falhar;
`-ENODEV` se o DT não trouxe a tabela):

- **nunca acima da fábrica**: o teto é a cópia do DT tirada no boot, e
  `vfloat`/`cond_vol` também não passam da float do degrau;
- `iout` ≥ 2000 mA (o mínimo do direct charger) e não crescente entre passos;
  gravar `iout` recalcula o `cond_iin` (`iout[i+1] / 2`, a conta do próprio
  driver);
- `vfloat` ≥ 4000 mV e não decrescente; `cond_vol` e `cond_soc` não
  decrescentes;
- `cond_vol[i]` ≤ `vfloat[i]` nos passos que trocam por tensão (senão o passo
  nunca alcança a condição e trava ali): **para baixar os dois, grave
  `cond_vol` primeiro; para subir, `vfloat` primeiro**.

Com o carregador PPS plugado, a escrita vale **na hora** (o driver reescolhe
o passo pelo mesmo caminho da troca de degrau de age); sem ele, no próximo
plug. Os valores são da linha do degrau atual: escreva **depois** do
`AGE_STEP`, porque trocar o degrau passa a usar a linha do novo degrau (com os
valores de fábrica dela, recortados pela float). Nada persiste no reboot.

A releitura ecoa exatamente o que foi gravado. Validado no aparelho em
2026-11-01 com PPS de 25 W (o `Ichg` muda na checagem seguinte do driver).

## Armadilhas conhecidas

- **Subir o degrau de age com o cabo plugado não sobe a float do carregador.**
  O `sec_bat_set_aging_step()` só repassa a float nova ao charger se ela for
  **menor** que a atual. Indo do degrau 3 (4320 mV) para o 2 (4340 mV) com o
  PPS plugado, o carregador ficou em 4320 até o próximo plug (o primeiro
  número do `fg_full_voltage` mostra o valor do charger). No boot isso não
  aparece, porque o plug reaplica a float. Corrigir na hora gravando a float
  do degrau em `batt_tune_float_voltage` (visto 2026-11-01).
- **`INPUT_CURRENT`/`FAST_CURRENT` desligam o step charging.** Escrever nesses
  atributos liga as flags `test_max_current`/`test_charge_current` do driver, e
  `sec_step_charging.c` passa a retornar cedo. A carga vira corrente constante
  até a float voltage, sem os degraus da Samsung. É modo de engenharia; use
  consciente.
- **O framework disputa `batt_full_capacity`.** É o mesmo atributo que o
  "Proteger bateria" da One UI usa. Quem escreve por último vence — daí o
  `BOOT_DELAY_SEC` (aplica depois do boot completar) e o `WATCHDOG_SEC`
  opcional, que devolve o seu valor se alguém o mudar.
- **`STORE_MODE` é one-way.** O handler do driver só trata valor diferente de
  zero; não há caminho de desligamento. Para sair, comente a chave e reinicie.
- **Float voltage, correntes e temperaturas não voltam sozinhas.** `reset`
  desfaz limite de carga e slate mode; o resto só retorna ao padrão do device
  tree depois de um reboot (com as chaves comentadas no arquivo, senão o
  `service.sh` reaplica).
- **Temperaturas são em décimos de grau**: `500` = 50,0 °C.
- **O `write` nesses atributos "falha" mesmo funcionando.**
  `sec_bat_store_attrs()` começa com `ret = -EINVAL` e nenhum handler
  `batt_tune_*` faz `ret = count` — só `batt_full_capacity`, `store_mode` e
  `batt_slate_mode` fazem. O valor é aplicado e o `write(2)` devolve erro assim
  mesmo, então um `echo ... > batt_tune_fast_charge_current` na mão sempre
  reclama. O `battctl` decide pela releitura, não pelo código de retorno.
- **`FLOAT_VOLTAGE` não pode ser conferido pela leitura.** O `store` repassa o
  valor ao charger (`POWER_SUPPLY_PROP_VOLTAGE_MAX`), mas o `show` lê
  `battery->pdata->chg_float_voltage`, que continua com o número do device
  tree. O `status` sinaliza isso na linha; para confirmar o valor real, veja o
  `dmesg` do charger. Medido: `set FLOAT_VOLTAGE 4200` → leitura segue 4270.
