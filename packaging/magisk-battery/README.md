# NetHunter Battery (r8q) — módulo Magisk

Tuning de carga do Galaxy S20 FE 5G pelo sysfs do driver `sec_battery`
(`/sys/class/power_supply/battery/`), **system-less** e reversível.

Módulo independente do `nethunter-companion`: pode ser instalado, desabilitado
ou removido sozinho.

## Por que via sysfs e não pelo device tree

Todos os números de carga do r8q vivem no device tree
(`arch/arm64/boot/dts/samsung/r8q/kona-sec-r8q-*-overlay-r*.dts`:
`battery,charging_current`, `battery,chg_float_voltage`, thresholds térmicos,
degraus do step charging). O boot image v2 deste device usa a **seção dtb
stock**, e o AnyKernel não substitui essa seção — ou seja, editar `.dts` no
kernel não chega ao aparelho. O que resta como superfície de controle é o
sysfs, e é nele que este módulo trabalha.

## Conteúdo

| O quê | Onde no device |
|---|---|
| `battctl` (CLI) | `/system/bin/battctl` (magic mount) — **não `xbin`**, o Magisk 30700 não o monta |
| Aplicação no boot | `service.sh` do módulo (late_start) |
| Configuração | `/data/adb/nethunter-battery.conf` (fora do módulo) |
| Log | `/data/adb/nethunter-battery.log` |

A configuração fica em `/data/adb` de propósito: sobrevive a atualizar ou
reinstalar o módulo, e o `customize.sh` nunca sobrescreve uma existente.

### Formato da configuração

O arquivo tem duas partes. O corpo é **template comentado** — documenta as
chaves, as faixas e o efeito de cada uma, e não vale nada por si. O que vale
fica numa seção no fim:

```
#FLOAT_VOLTAGE=4200          <- template: doc, sem efeito

# === Configurado (o battctl escreve daqui para baixo) ===
FULL_CAPACITY=80
FAST_CURRENT=1800
```

`set` e `limit` gravam sempre nessa seção. Editar a seção à mão também
funciona (rode `battctl apply` depois). Qualquer `apply` ou `set` normaliza o
arquivo: linha ativa escrita no corpo migra para a seção, chave repetida
colapsa numa só (vence a última) e espaços/comentário inline são limpos — ou
seja, dá para ver de relance tudo o que está fora do padrão do device tree.

## Uso

```sh
su
battctl status              # carga, tensão, corrente, temp + parâmetros ativos
battctl show                # chaves, faixas aceitas e a configuração atual
battctl limit 80            # para de carregar em 80%, recarrega em 78%
battctl set FLOAT_VOLTAGE 4200
battctl charge off          # slate mode: corta a carga mantendo o link USB
battctl apply               # reaplica o arquivo de configuração
battctl reset               # desfaz o que é reversível sem reboot
```

`set` e `limit` gravam no arquivo **e** aplicam na hora; o `service.sh`
reaplica a cada boot.

## O que exige o kernel NetHunter

| Parâmetro | Kernel stock | NetHunter r8q v4.3+ |
|---|---|---|
| `FULL_CAPACITY` (limite de carga) | ✅ | ✅ |
| slate mode, store mode | ✅ | ✅ |
| `SIOP_LEVEL` + `SIOP_LOCK`, `WC_*`, `SKIP_SWELLING`, `SAFETY_TIMER`, `WDT_KICK_DISABLE`, `BATTERY_CYCLE` | ✅ | ✅ |
| `FLOAT_VOLTAGE`, correntes, corrente de corte, limites térmicos, `WPC_TEMP_*` | ❌ | ✅ |

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

Os `batt_tune_*` só são criados com `CONFIG_ENG_BATTERY_CONCEPT=y`, habilitado
no `wirus_defconfig` a partir da v4.3. Sem eles o módulo instala e funciona,
apenas com o conjunto reduzido — o `customize.sh` avisa qual dos dois casos é o
seu.

## Armadilhas conhecidas

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
