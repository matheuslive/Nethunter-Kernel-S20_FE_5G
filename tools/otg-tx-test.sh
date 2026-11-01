#!/system/bin/sh
# Teste de OTG em TX: wlan1 (AR9271) num netns próprio, associada à OpenWRT,
# iperf3 em upload para a workstation, vigiando overcurrent e corrente da bateria.
# Uso: scp para /data/local/tmp e "ssh root@s20 sh /data/local/tmp/otg-tx-test.sh <ip-servidor> [s]",
# com "iperf3 -s -1 -p 5299" no servidor. Exige wpa-supplicant do Termux (2026-11-01).
T=/data/data/com.termux/files/usr/bin
BB=$T/busybox
SRV=${1:-10.0.0.162}; DUR=${2:-60}
D=/data/local/tmp/otgtest; mkdir -p $D; cd $D
F=/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml
PSK=$(awk '/<string name="SSID">&quot;OpenWRT&quot;</{f=1} f&&/PreSharedKey/{print;exit}' $F | sed 's/.*PreSharedKey">//; s/<.*//; s/&quot;/"/g')
[ -n "$PSK" ] || { echo "sem PSK"; exit 1; }
printf 'ctrl_interface=%s/ctrl\nnetwork={\n ssid="OpenWRT"\n psk=%s\n}\n' $D "$PSK" > wpa.conf; chmod 600 wpa.conf
printf '#!/system/bin/sh\n[ "$1" = bound ] && echo "$ip $mask $router" > %s/lease\n' $D > dhcp.sh; chmod 755 dhcp.sh
$BB unshare -n sleep 900 & NS=$!; sleep 1
$T/iw phy phy1 set netns $NS || { kill $NS; exit 1; }
N="$BB nsenter -t $NS -n"
$N ip link set lo up; $N ip link set wlan1 up
$N $T/wpa_supplicant -B -i wlan1 -c wpa.conf -P wpa.pid >/dev/null
i=0; until $N $T/wpa_cli -p $D/ctrl -i wlan1 status 2>/dev/null | grep -q wpa_state=COMPLETED; do i=$((i+1)); [ $i -gt 30 ] && break; sleep 1; done
$N $T/wpa_cli -p $D/ctrl -i wlan1 status | grep -E 'wpa_state|bssid|freq'
rm -f lease; $N $BB udhcpc -i wlan1 -s $D/dhcp.sh -q -n -t 5 >/dev/null 2>&1
read IP MASK GW < lease 2>/dev/null
echo "ip=$IP"
if [ -n "$IP" ]; then
  $N ip addr add $IP/24 dev wlan1
  OC0=$(dmesg | grep -ci overcurrent)
  ( for s in $(seq 1 $DUR); do cat /sys/class/power_supply/battery/current_now; sleep 1; done > cur.txt ) & CP=$!
  $N $T/iperf3 -c $SRV -t $DUR -p 5299 2>&1 | tail -4
  wait $CP
  echo "overcurrent: antes=$OC0 depois=$(dmesg | grep -ci overcurrent)"
  sort -n cur.txt | awk '{a[NR]=$1} END{print "corrente bateria (mA): min="a[1]" mediana="a[int(NR/2)]" max="a[NR]}'
  $N $T/iw dev wlan1 station dump | grep -E 'tx (bitrate|retries|failed)|signal:'
fi
kill $(cat wpa.pid) 2>/dev/null; sleep 1; kill $NS; sleep 2
$T/iw dev wlan1 info >/dev/null 2>&1 && echo "wlan1 de volta no netns principal"
dmesg | grep -iE 'ath9k|usb 3-1|otg' | tail -5
rm -f wpa.conf lease cur.txt
