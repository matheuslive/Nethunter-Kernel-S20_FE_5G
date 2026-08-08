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
| `FLOAT_VOLTAGE`, correntes, corrente de corte, limites térmicos | ❌ | ✅ |

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
