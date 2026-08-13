# NetHunter Companion (r8q) — módulo Magisk

Complemento **system-less** do kernel Nethunter para o Galaxy S20 FE 5G (`r8q`).
Faz, de forma reversível e sem tocar em partição read-only, o que as "NetHunter
additions" do `anykernel.sh` original tentavam fazer escrevendo em `/system` e
`/vendor` — o que não funciona em One UI 13 (super dinâmica + A13 SAR).

## Conteúdo (preenchido pelo `build.sh`)

| O quê | Onde no device | Como |
|---|---|---|
| Módulos `.ko` do kernel | `/system/lib/modules/` | magic mount |
| `hid-keyboard`, `usbwifi`, `wmon` | `/system/bin/` | magic mount |
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

## Monitor mode + airodump-ng (`wmon`)

Roda **sob demanda** no Termux, como root. Autodetecta a interface: prefere o
**dongle USB (`wlan1`)** — o caminho estável do NetHunter — e cai no **rádio
interno `wlan0`** só se não houver dongle.

```sh
sudo wmon              # autodetecta; dongle=hopping, interno=exige -c
sudo wmon -c 6         # trava no canal 6
sudo wmon -i wlan1 -c 36
sudo wmon -l           # lista as interfaces WiFi
sudo wmon -h
```

Ao sair (`Ctrl-C`), o `wmon` restaura sozinho: dongle → `managed`; interno →
`con_mode=0` + religa o WiFi.

⚠️ **No `wlan0` interno (QCA6390) o monitor é frágil.** Trocar de canal
(`iw set channel`, que é o que o airodump faz ao pular canais) **deadlocka o
driver qcacld** (D-state), exigindo hard reboot (`echo b > /proc/sysrq-trigger`).
Por isso no interno o `wmon` **obriga um canal fixo** (`-c`) e exige o `wlan0`
já conectado a um AP (`operstate=up`) antes de entrar em monitor — mas mesmo
assim é arriscado. **Use um dongle USB** (`usbwifi` carrega o driver → vira
`wlan1`) para captura confiável com hopping e injection.
