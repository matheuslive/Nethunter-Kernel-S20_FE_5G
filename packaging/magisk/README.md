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

Roda **sob demanda** no Termux, como root. Por **padrão usa o dongle USB
(`wlan1`)** — o caminho estável do NetHunter; **não cai mais no rádio interno**.
Para forçar o `wlan0` interno (que não captura — muro de firmware) use
`wmon -i wlan0` de propósito, ou `wmon -t` para o autoteste.

O companion **carrega o `ath9k_htc` (AR9271) no boot** (`service.sh`), então o
dongle vira `wlan1` sozinho ao plugar, sem precisar rodar `usbwifi`.

```sh
sudo wmon              # usa o dongle wlan1 (hopping)
sudo wmon -c 6         # trava no canal 6
sudo wmon -i wlan1 -c 36
sudo wmon -i wlan0 -c 6   # forca o radio interno (nao captura)
sudo wmon -l           # lista as interfaces WiFi
sudo wmon -t           # TESTE do monitor interno wlan0 (valida o fix v4.8.2)
sudo wmon -t -c 36     # idem, no canal 36 (default 6)
sudo wmon -h
```

Ao sair (`Ctrl-C`), o `wmon` restaura sozinho: dongle → `managed`; interno →
`con_mode=0` + religa o WiFi.

⚠️ **No `wlan0` interno (QCA6390) a captura não funciona — muro de firmware.**
Confirmado no aparelho (`wmon -t`): entra em monitor, mas o firmware **não deixa
fixar canal** (`iw set channel` → `timeout -110`, não emite o `VDEV_UP`), então
não há captura útil. **Use um dongle USB** (`usbwifi` carrega o driver → vira
`wlan1`) para captura confiável com hopping e injection.

A partir da **v4.8.2** o kernel corrige o *deadlock* que esse cenário causava
(early-return de mesmo canal, self-recovery desligado no timeout de vdev monitor,
DBS pulado): o `iw set channel` agora **falha limpo (-110) em vez de travar o
aparelho** — validado no device, sem mais `reboot -f`. Além disso o `wmon` interno
agora **parte de `wlan0` DOWN** antes do `con_mode=4`, evitando o vazamento de
refcount de netdev (`unregister_netdevice: waiting for wlan0 to become free`) que
travava a troca de modo quando a STA estava ativa. Rode `sudo wmon -t` para ver o
veredito no seu aparelho.
