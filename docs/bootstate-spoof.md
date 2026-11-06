# Ocultar o estado do bootloader em `/proc` (bootstate spoof)

> ## ❌ SHELVED — NÃO COMPILAR
>
> **Este approach BOOTLOOPA neste aparelho (Galaxy S20 FE, r8q).** Gravado no kernel
> v4.16 em 2026-11-06, causou bootloop; o aparelho foi recuperado por re-flash do boot
> v4.15. Approach **shelved**: o `obj-y += bootstate_spoof.o` foi removido do
> `init/Makefile`; `init/bootstate_spoof.c` fica só como referência. Não recompilar como
> está.
>
> **Causa confirmada** (pelo `/proc/last_kmsg` do boot v4.16, com 6 oops): `Unable to
> handle kernel write to read-only memory` em `replace_token` ← `spoof_buf`, na escrita
> **in-place** em `prop->value` da propriedade `bootargs` do `/chosen`. No arm64 o
> `unflatten_device_tree()` não copia os valores das propriedades: `prop->value` aponta
> para dentro do FDT ([`drivers/of/fdt.c`](../drivers/of/fdt.c), `populate_properties`), e
> o `setup_machine_fdt()` remapeia o FDT no fixmap como `PAGE_KERNEL_RO` depois do scan
> inicial ([`arch/arm64/kernel/setup.c`](../arch/arm64/kernel/setup.c)). Foi a proteção
> de página normal do kernel, **não** o RKP/KDP da Samsung (a hipótese anterior, agora
> descartada).
>
> **Como seria um spoof correto do DT:** trocar a propriedade inteira com
> `of_update_property(np, newprop)`, com uma `struct property` nova e um `value` novo
> alocados (`kzalloc`/`kmemdup`), em vez de escrever em `prop->value`.
>
> **`saved_command_line` é outro caso:** a escrita nele vem antes no código e não foi ela
> que falhou no oops. Isso não prova que ela seja segura, só que não foi a causa observada.

O bootloader passa, pelo cmdline (nó `chosen/bootargs` do device tree), os tokens que
denunciam o estado real do aparelho:

- `androidboot.verifiedbootstate=orange` — bootloader destravado
- `androidboot.warranty_bit=1` — warranty/Knox queimado

Esses dois tokens vazam para o userspace por duas fontes que o kernel expõe e que um detector
nativo lê por syscall direta (furando hooks de Zygisk, que só interceptam as *props*):

1. `/proc/cmdline` — impresso por [`fs/proc/cmdline.c`](../fs/proc/cmdline.c), que faz
   `seq_puts(m, saved_command_line)`.
2. `/proc/device-tree/chosen/bootargs` — a mesma string, vinda da propriedade `bootargs` do nó
   `/chosen` do device tree desdobrado.

As *props* (`ro.boot.verifiedbootstate`, `warranty_bit`, `flash.locked`,
`vbmeta.device_state`) já são spoofadas por `resetprop` no aparelho; estas duas fontes do
kernel não eram cobertas.

## O patch

[`init/bootstate_spoof.c`](../init/bootstate_spoof.c) — um `late_initcall` novo, mínimo e
sempre ativo (sem Kconfig). No boot ele faz substituição de string **in-place** e de **mesmo
comprimento** (nunca realoca) nas duas memórias:

- `saved_command_line` (o que `/proc/cmdline` imprime);
- a propriedade `bootargs` do nó `/chosen` (via `of_find_node_by_path("/chosen")` →
  `of_find_property(np, "bootargs", &len)` → `prop->value` in-place), que alimenta
  `/proc/device-tree/chosen/bootargs`.

Substituições (ambas preservam o comprimento):

| de | para | observação |
|----|------|------------|
| `verifiedbootstate=orange` | `verifiedbootstate=green ` | `orange` (6) → `green ` (5+espaço) |
| `warranty_bit=1` | `warranty_bit=0` | 1 char, mesmo tamanho |

O token é casado inteiro (`verifiedbootstate=orange`, não só `orange`) para não acertar outra
ocorrência. O espaço extra antes do próximo token é inofensivo para qualquer parser. As duas
fontes são tratadas de forma independente.

## Por que `late_initcall` (ordem — senão vira bootloop)

[`drivers/md/dm-android-verity.c`](../drivers/md/dm-android-verity.c) lê
`androidboot.verifiedbootstate=` por `__setup` (cedo, no `parse_args` do `start_kernel`) para
o buffer estático `verifiedbootstate`, e em `is_unlocked()` compara com `"orange"`: se **não**
for `orange`, liga o `dm-verity` em enforcing — o que **quebra o boot** num `/system`
modificado (bootloop). Vários `security/samsung/*` (five, defex, kdp) e `sec_debug_pwdt`
também leem via `__setup`, cedo.

Por isso a troca **tem** de ser num `late_initcall`, que roda muito depois de todos os
`__setup`/initcalls e antes do `init` do userspace ser exec'd. Nesse ponto:

- o `dm-android-verity` já leu o `orange` real para o buffer estático dele → verity permanece
  off;
- a decisão in-kernel de verity **não** usa `saved_command_line` nem a prop do DT, então
  reescrevê-los tarde só muda o que `/proc` expõe.

**Nunca** usar `early_param` / `__setup` / `core_initcall` para isto.

## Validação no aparelho (pendente)

Depois de gravar:

```sh
cat /proc/cmdline                               # verifiedbootstate=green, warranty_bit=0
cat /proc/device-tree/chosen/bootargs | tr '\0' '\n' | grep -E 'verifiedbootstate|warranty'
```

Ambos devem mostrar `green` e `0`. O boot deve continuar normal (verity off, sem bootloop).
