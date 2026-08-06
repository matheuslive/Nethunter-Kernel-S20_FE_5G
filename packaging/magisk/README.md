# NetHunter Companion (r8q) — módulo Magisk

Complemento **system-less** do kernel Nethunter para o Galaxy S20 FE 5G (`r8q`).
Faz, de forma reversível e sem tocar em partição read-only, o que as "NetHunter
additions" do `anykernel.sh` original tentavam fazer escrevendo em `/system` e
`/vendor` — o que não funciona em One UI 13 (super dinâmica + A13 SAR).

## Conteúdo (preenchido pelo `build.sh`)

| O quê | Onde no device | Como |
|---|---|---|
| Módulos `.ko` do kernel | `/system/lib/modules/` | magic mount |
| `hid-keyboard` | `/system/xbin/hid-keyboard` | magic mount |
| Descriptors HID (`*.bin`) | `/system/etc/nethunter/` | magic mount |
| `init.nethunter.rc` | importado no boot | `overlay.d/sbin/` |

## O que é sólido e o que é experimental

- **Sólido:** os `.ko` ficam disponíveis para `insmod`/`modprobe`, o
  `hid-keyboard` fica no PATH, tudo reversível (desabilitar o módulo desfaz).
- **Experimental:** o `init.nethunter.rc` reconfigura o USB gadget (`g1`) para
  expor HID de teclado/mouse. Em ROM Samsung stock isso concorre com o
  gerenciamento de USB nativo da One UI e pode simplesmente não ativar. Se der
  problema, é só remover `overlay.d/sbin/init.nethunter.rc` do módulo (ou
  desabilitar o módulo) — não afeta o resto.

## Pré-requisito

Os `.ko` têm `vermagic`/`CONFIG_MODVERSIONS` amarrados ao kernel com que foram
compilados. Só carregam se o **kernel Nethunter correspondente** estiver
flashado. Instalar o módulo com a ROM ainda no kernel stock é inócuo — os
módulos passam a valer depois de flashar o kernel.

## Uso dos módulos

```sh
su
insmod /system/lib/modules/can-isotp.ko
insmod /system/lib/modules/can327.ko
# etc.
```
