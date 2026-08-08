# NetHunter Companion (r8q) — módulo Magisk

Complemento **system-less** do kernel Nethunter para o Galaxy S20 FE 5G (`r8q`).
Faz, de forma reversível e sem tocar em partição read-only, o que as "NetHunter
additions" do `anykernel.sh` original tentavam fazer escrevendo em `/system` e
`/vendor` — o que não funciona em One UI 13 (super dinâmica + A13 SAR).

## Conteúdo (preenchido pelo `build.sh`)

| O quê | Onde no device | Como |
|---|---|---|
| Módulos `.ko` do kernel | `/system/lib/modules/` | magic mount |
| `hid-keyboard`, `usbwifi` | `/system/bin/` | magic mount |
| Descriptors HID (`*.bin`) | `/system/etc/nethunter/` | magic mount |
| Firmware dos dongles | `/vendor/firmware/` | magic mount (`system/vendor/`) |
| `init.nethunter.rc` | importado no boot | `overlay.d/sbin/` |

⚠️ **Binário vai em `system/bin`, nunca em `system/xbin`** — o Magisk 30700 não
monta `xbin` (o diretório nem existe em One UI 13) e o arquivo some em silêncio.
Foi o que quebrou o `hid-keyboard` e o `usbwifi` até 2026-08-08.

O firmware, esse, continua em `$MODPATH/system/vendor/` mesmo com
`/system/vendor` sendo symlink para `/vendor`: o Magisk resolve sozinho (monta
tmpfs em `/vendor/firmware` e faz bind dos originais). Conferir pelo caminho
real do arquivo — `/vendor/firmware/ath9k_htc/htc_9271-1.4.0.fw`, não
`htc_9271.fw` — senão parece ausente quando está lá.

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
