#!/usr/bin/env python3
"""Projecao da 5a onda do kmsg (v4.19): linhas/min por fonte rebaixada.

Uso: tools/kmsg-onda5-proj.py <dmesg.txt[.gz]> ...
Conta, em cada captura, as linhas que a v4.19 deixa de mandar ao kmsg
(padroes abaixo, espelhando as mudancas no fonte) e divide pelo intervalo.
Ficam no kmsg: erros/timeouts do cnss e do qcacld, "WLAN triggered wakeup",
"WOW Wakeup: <proto>" e a linha Pkt_len/portas, "Disabling/Enabling non-boot
CPUs" e o hotplug durante o boot.
"""
import gzip, re, sys

G = [
 ('touch fts5cu56a ttype(N->P/P->N)', r'fts_event_handler_type_b: tID:\d+ ttype\('),
 ('input_booster IB is null on release', r'IB is null on release'),
 ('cnss vdbg (runtime PM, PCI link, MHI state)',
  r'cnss: (Use PCIe DRV suspend|(Suspending|Resuming) PCI link|Setting MHI state|Set PCI link status'
  r'|Runtime (idle|suspend start|resume start|(suspend|resume) status: 0\b))'),
 ('qcacld: contadores de wake (4 linhas por wake), Src_mac',
  r'\[\d+:F:WMA\] (WLAN wake reason counters|uc:\d|assoc:\d|pno_match:)|wma_wow_parse_data_pkt: \d+: Src_mac'),
 ('qcacld: PMO/WMI WoW enable, HIF wake irq/RTPM, HDD bus suspend/resume',
  r'\[\d+:I:PMO\] pmo_core_(enable_wow_in_fw: \d+: (drv wow is enabled|RTPM wow)|psoc_send_host_wakeup_ind_to_fw|is_wow_applicable: \d+: lpass)'
  r'|send_wow_enable_cmd_tlv: \d+: suspend type|\[\d+:I:HIF\] (wake interrupt received|Runtime PM resume is requested)'
  r'|\[\d+:I:HDD\] (__wlan_hdd_bus_suspend: \d+: (starting bus suspend|bus suspend succeeded)'
  r'|wlan_hdd_bus_resume: \d+: (starting bus resume|bus resume succeeded)|hdd_(suspend|resume)_wlan: \d+: WLAN being)'),
 ('hotplug de CPU no suspend/resume',
  r'psci: CPU\d+ killed|\] CPU\d+: shutdown|\] CPU\d+ is up|CPU\d+: Booted secondary|CPU\d+: Trapping CNTVCT'
  r'|Detected \w+ I-cache on CPU|IRQ \d+: no longer affine'),
]
TS = re.compile(r'^\[\s*([\d.]+)\]')
for f in sys.argv[1:]:
    op = gzip.open if f.endswith('.gz') else open
    with op(f, 'rt', errors='replace') as fh:
        L = fh.read().splitlines()
    ts = [float(m.group(1)) for l in L if (m := TS.match(l))]
    mins = (ts[-1] - ts[0]) / 60
    print(f'{f}\n  {len(L)} linhas em {mins:.1f} min = {len(L)/mins:.0f}/min')
    tot = 0
    for name, rx in G:
        r = re.compile(rx)
        n = sum(1 for l in L if r.search(l))
        tot += n
        print(f'  {n/mins:7.1f}/min  {name}')
    print(f'  {tot/mins:7.1f}/min  SOMA -> sobra ~{(len(L)-tot)/mins:.0f}/min')
