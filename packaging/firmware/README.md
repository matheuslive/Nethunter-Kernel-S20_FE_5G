# Firmware dos dongles USB

Vai para `/vendor/firmware/` no device, por magic mount do modulo Magisk
companion (`system/vendor/firmware/` dentro do zip).

## Por que /vendor/firmware e nao /lib/firmware

O `fw_path[]` do kernel (`drivers/base/firmware_loader/main.c`) so lista
`/lib/firmware*` e o valor de `firmware_class.path`. No Android **nao existe
`/lib`**, entao nenhum desses caminhos resolve. O que funciona e o fallback de
userspace (`CONFIG_FW_LOADER_USER_HELPER_FALLBACK=y`): o kernel emite um uevent
e o `ueventd` procura nos diretorios do `ueventd.rc` do device --

    firmware_directories /etc/firmware/ /odm/firmware/ /vendor/firmware/ /firmware/image/

Isso so vale porque **nenhum** dos drivers de dongle usa
`request_firmware_direct()` (essa variante pula o user helper). Conferido em
ath9k_htc, mt7601u, rt2x00, zd1211rw, rtlwifi, rtl8xxxu e carl9170: todos usam
`request_firmware()` ou `request_firmware_nowait()`.

**Nao setar `firmware_class.path`.** No r8q ele ja vem apontando para
`/vendor/firmware_mnt/image` e outros subsistemas dependem disso.

## Os nomes importam

O template AnyKernel3 (`AnyKernel3/vendor/etc/firmware_mnt/image/`) trazia os
arquivos com **nome legado e sem os subdiretorios** que os drivers pedem. O
caso mais visivel e o AR9271, o dongle mais recomendado para monitor mode:

| driver pede                       | template tinha |
|-----------------------------------|----------------|
| `ath9k_htc/htc_9271-1.4.0.fw`     | `htc_9271.fw`  |
| `ath9k_htc/htc_7010-1.4.0.fw`     | `htc_7010.fw`  |

Os bytes sao os mesmos (md5 `c5b2dc29...` para o 9271, identico ao
linux-firmware), so o nome estava errado -- entao aquele layout nunca teria
carregado.

## Conferir a cobertura

O proprio `build.sh` avisa (`!! firmware declarado e ausente: ...`), mas para
checar na mao:

    for ko in build/r8q/modules/*.ko; do /sbin/modinfo -F firmware "$ko"; done |
      sort -u | while read -r fw; do
        [ -f "packaging/firmware/$fw" ] || echo "FALTA $fw"
      done

## Ausencias conhecidas (e por que nao sao problema)

- `fw.ram.bin` e `ath6k/AR6004/hw1.3/fw.ram.bin` -- nome da API 1 do ath6kl,
  declarado no `MODULE_FIRMWARE` mas nao usado: o driver carrega `fw-2.bin` /
  `fw-3.bin` (`ATH6KL_FW_API{2,3}_FILE` em `ath6kl/core.h`), que estao aqui.
- `ath6k/AR6004/hw1.0/*`, `ath6k/AR6004/hw1.1/*` -- essas revisoes nao existem
  no linux-firmware upstream.
- `rtlwifi/rtl8723bu_bt.bin` -- lado Bluetooth do RTL8723BU; o WiFi (`_nic.bin`)
  sobe sem ele.

## Origem

`ath9k_htc/*` e `ath6k/AR6004/*/fw-*.bin` vieram do linux-firmware; o restante,
do template AnyKernel3 deste repo. Firmwares sao redistribuiveis sob as
licencas dos respectivos fabricantes.
