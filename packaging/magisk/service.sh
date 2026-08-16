#!/system/bin/sh
# service.sh -- roda no late_start do Magisk (boot, com /data ja montado).
#
# Carrega o driver do dongle AR9271 (ath9k_htc) no boot, para o dongle virar
# 'wlan1' assim que plugado (hotplug), SEM precisar rodar 'usbwifi' na mao. Os
# drivers de dongle sao .ko (=m) e nao carregam sozinhos; com o ath9k_htc ja
# residente, o usbcore casa o AR9271 (0cf3:9271) e cria a interface ao plugar.
#
# Reusa o proprio usbwifi (resolucao de MODDIR + modprobe com deps). Chamamos a
# copia do modulo em /data/adb, que existe mesmo antes do magic mount de /system.
MODID=nethunter_companion_r8q
USBWIFI="/data/adb/modules/$MODID/system/bin/usbwifi"

# Espera curta: em alguns aparelhos o service.sh dispara antes do modulo estar
# pronto. No maximo ~40 s; sai assim que o usbwifi aparecer.
i=0
while [ ! -x "$USBWIFI" ] && [ "$i" -lt 20 ]; do
	sleep 2
	i=$((i + 1))
done

[ -x "$USBWIFI" ] && "$USBWIFI" ath9k_htc >/dev/null 2>&1
