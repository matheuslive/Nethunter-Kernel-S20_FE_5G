# Correntes do SIOP pelo sysfs (`batt_siop_*`)

Grupo 3 do item "Expor por patch em C o que só existe no device tree" do
`TODO.md`. As correntes que o SIOP (controle térmico do sistema, One UI) impõe
em cada tipo de cabo vinham só do device tree, e o DTB não chega ao aparelho
(o boot v2 usa a seção dtb stock). Agora cada uma é um atributo em
`/sys/class/power_supply/battery/`.

## Atributos

| Atributo | Campo do DT | DT r8q | Onde vale | Faixa (mA) |
|---|---|---|---|---|
| `batt_siop_input_limit_current` | `siop_input_limit_current` | 1200 | entrada, com fio 5 V (USB/TA comum) | 100..3000 |
| `batt_siop_charging_limit_current` | `siop_charging_limit_current` | 1800 | carga, com fio (exceto direct charging) | 100..6000 |
| `batt_siop_hv_input_limit_current` | `siop_hv_input_limit_current` | 700 | entrada, AFC 9 V | 100..3000 |
| `batt_siop_hv_input_limit_current_2nd` | `siop_hv_input_limit_current_2nd` | 450 | entrada no nível 0, AFC 9 V e PD fixo | 100..3000 |
| `batt_input_current_by_siop_20` | `input_current_by_siop_20` | 500 | entrada no nível 20, AFC 9 V; 0 desliga | 0..3000 |
| `batt_siop_apdo_charging_limit_current` | `siop_apdo_charging_limit_current` | 2000 | carga, direct charging 25 W (PPS) | 1000..6000 |
| `batt_siop_wireless_input_limit_current` | `siop_wireless_input_limit_current` | 700 | entrada, wireless comum | 100..3000 |
| `batt_siop_wireless_charging_limit_current` | `siop_wireless_charging_limit_current` | 700 | carga, wireless comum | 100..6000 |
| `batt_siop_hv_wireless_input_limit_current` | `siop_hv_wireless_input_limit_current` | 700 | entrada, wireless HV (e FULL/2nd, ver abaixo) | 100..3000 |
| `batt_siop_hv_wireless_charging_limit_current` | `siop_hv_wireless_charging_limit_current` | 700 | carga, wireless HV | 100..6000 |

O teto de entrada (3000) é o `battery,max_input_current` do DT, lido em
runtime. O piso de 1000 mA do direct charging é o mesmo do
`batt_max_charge_current` e do `batt_dchg_limit_current`: a entrada é a metade
da carga e o PCA9468 não regula abaixo de 500 mA.

- `cat` devolve só o número (a releitura ecoa o que foi escrito).
- Valor fora da faixa, ou que não é número: o `write` falha com `-EINVAL` e
  nada muda.
- A escrita vale **na hora**: chama o `sec_bat_refresh_charging_current()`, que
  reroda o cálculo de corrente e passa pelo SIOP de novo.
- Não persiste: no boot volta ao DT. Quem quiser fixar reaplica no boot
  (módulo/app).

## Quando têm efeito

Todos são **tetos** (`if (corrente > teto) corrente = teto`) aplicados no
`sec_bat_get_charging_current_by_siop()`, que só age com `siop_level < 100`
(e não age no nível 80 com fio). Portanto:

- **Com o SIOP travado em 100** (`SIOP_LEVEL=100` + `SIOP_LOCK=1`, o estado do
  S20), nenhum deles muda nada, com uma exceção: o
  `batt_siop_hv_wireless_input_limit_current` também limita a entrada no
  wireless quando a bateria está em FULL e na carga adicional (2nd), em
  qualquer nível (`sec_bat_get_wireless_current()`, passo 5).
- **Com nível < 100** (One UI controlando o SIOP, ou nível fixado à mão), eles
  definem quanto o throttle térmico corta em cada tipo de cabo.
- Subir acima do valor do DT **não** passa da corrente normal do cabo nem do
  `max_input_current`: só afrouxa (ou anula) aquele degrau do SIOP. Baixar
  aperta o throttle.

No nível 0, além dos tetos acima, o AFC 9 V e o PD fixo caem para o `_2nd`;
no nível 20, o AFC 9 V cai para o `input_current_by_siop_20` (se > 0). O teto
de entrada do PD fixo (60000 / tensão, ~666 mA em 9 V) e os de carga do
wireless (1000 mA; 500 no nível ≤ 10; 0 no nível 0) continuam fixos no código.

## O que mudou no driver além do sysfs

A corrente de carga com fio no SIOP era o literal `1800` no
`sec_bat_get_charging_current_by_siop()`, e o `siop_charging_limit_current` do
DT (também 1800) era lido e nunca usado. Agora o código usa o campo — mesmo
valor no boot, sem mudança de comportamento até alguém escrever no atributo.

## Deixados de fora

- `siop_hv_charging_limit_current` (DT 1000), `siop_apdo_input_limit_current`
  (DT 1000) e `siop_hv_12v_charging_limit_current`: lidos e nunca usados.
  Ligar o `siop_hv_charging` mudaria o comportamento (a carga em AFC no SIOP
  hoje usa os mesmos 1800 do 5 V, e passaria a 1000).
- `siop_hv_12v_input_limit_current`: só vale para cabo 12 V (`12V_TA`/QC 3.0),
  ausente do DT r8q (fica no default do código).
- `siop_store_hv_input_limit_current_2nd`: só no modo loja. O DTS tem um
  `siop_store_hv_wireless_input_limit_current`, nome que o parser não lê.
- LRP (`lrp_temp_check_type = 0` no DT) e ISDB (`CONFIG_ISDB_CHARGING_CONTROL`
  fora do build) também leem alguns destes campos, mas estão desligados.

## Testar no aparelho

Precisa do SIOP destravado (`SIOP_LOCK=0`; com o lock o `siop_level` fica 0444
e nem o root escreve) e de um cabo do tipo testado. Exemplo com fio 5 V:

```sh
B=/sys/class/power_supply/battery
cat $B/batt_siop_input_limit_current          # 1200
echo 99 > $B/siop_level                       # entra no SIOP
echo 600 > $B/batt_siop_input_limit_current
cat $B/input_current_limit 2>/dev/null; dmesg | grep -E 'by_siop|batt_siop'
echo 50 > $B/batt_siop_input_limit_current    # deve falhar: Invalid argument
echo 100 > $B/siop_level                      # volta
```
