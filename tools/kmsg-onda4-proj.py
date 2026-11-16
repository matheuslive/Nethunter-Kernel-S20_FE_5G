#!/usr/bin/env python3
"""Projecao da 4a onda do kmsg (v4.18): linhas/min por fonte rebaixada.

Uso: tools/kmsg-onda4-proj.py <dmesg.txt[.gz]> ...
Conta, em cada captura, as linhas que a v4.18 manda para debug (padroes
abaixo, espelhando as mudancas no fonte) e divide pelo intervalo coberto.
"""
import gzip, re, sys

G = [
 ('USB-PD: max77705 (pdmsg/psrdy/opcode/pdo/DIAES/notifier)',
  r'max77705_(pdmsg_irq: IRQ|pd_check_pdmsg:  pd_msg|psrdy_irq: (IN|OUT|psrdy_received)|get_pd_support: TYPEC_CLASS'
  r'|usbc_opcode_(read: R->R|write: W->W)|ccic_event_work: usb: DIAES .*-4-1-|ccic_event_notifier: usb: dest=BATTERY, id=ID_POWER_STATUS, attach=1)'
  r'|max77705_check_pdo : OPCODE|max77705_current_pdo : |max77705_process_pd : |max77705_select_pps : PPS PDO'
  r'|max77705_response_apdo_request: Sent'),
 ('USB-PD: typec/ccic_notifier/type-c manager/GRIP',
  r'typec_set_pwr_opmode pwr_opmode=(\d) opmode=\1\b|ccic_notifier_notify: (src:5 dest:2 id:04 attach:01|notify done)'
  r'|type-c manager: manager_(handle_ccic_notification: .*ID_POWER_STATUS attach/rid:1|event_work src:CCIC dest:BATTERY'
  r'|notifier_notify: (src:CCIC dest:BATTERY id:ID_POWER_STATUS sub1:01|notify done))'
  r'|\[GRIP\] a96t3x6_ccic_handle_notification'),
 ('USB-PD: sec-battery usb_typec_handle_notification',
  r'usb_typec_handle_notification: (action \(4\) dump\(0x5, 0x2, 0x04, 0x0001|battery->pd_list.now_pd_index\((\d+)\), prev_pd_index\(\2\)'
  r'|battery->pdic_ps_rdy\(1\)|available pdo : |CMD\[PD_ATTACH\])'),
 ('max77705 CCIC_SYSFS_USBPD_IDS', r'CCIC_SYSFS_USBPD_IDS'),
 ('pca9468 loop CC/CV/PPS',
  r'pca9468_(charge_(cc|cv)mode: (=+START|End, ret=0|CC INACTIVE|CC LOOP|CV LOOP|CV VFLOAT)|check_(cc|cv)mode_status: (CC|CV)MODE Status=\d'
  r'|send_pd_message: (msg_type|ret=0)|set_ta_(current|voltage)_comp|pps_request_work: (pps_work_start|End, ret=0)'
  r'|chg_get_property: HEALTH)|## pca9468_send_pd_message'),
 ('[FACTORY] light_brightness_store / ar_mode_store', r'\[FACTORY\] ?(light_brightness_store|ar_mode_store)'),
 ('SDE brilho/VRR/attach/ACL',
  r'\[SDE\] (ss_panel_attach_set|__ss_vrr : VRR: (cur_mode|\(cur)|ss_brightness_dcs : (tx bl cmd|\[DISPLAY_\d\] level)'
  r'|set_normal_br_values : .*gm2_wrdisbv|vrr_show|ss_acl_on : gradual|ss_acl_off : ACL off)'),
 ('Input Booster TV No Exist', r'Input Booster\]  (Press|Release) Timeout Func :::: \d+\'s TV No Exist'),
 ('QSEECOM loaded apps', r'QSEECOM: qseecom_update_info: loaded apps'),
 ('camera: CAM_INFO de rotina',
  r'CAM_INFO: CAM-(SENSOR: (cam_sensor_driver_cmd: \d+ CAM_(ACQUIRE|START|STOP|RELEASE)_DEV Success|cam_sensor_match_id|cam_sensor_wait_stream_o(n|ff): \d+ \[CNT_DBG\] (0x|retry))'
  r'|CSIPHY: (cam_csiphy_core_cfg: \d+ phy |cam_cmd_buf_parser: \d+ security mode)'
  r'|ISP: (cam_ife_mgr_(acquire|release)_hw|cam_isp_blob_core_cfg_update|cam_vfe_bus_ver3_init_hw|cam_vfe_top_ver3_init_hw|cam_vfe_camif_ver3_resource_start'
  r'|__cam_isp_ctx_flush_req)|CRM: cam_req_mgr_(process_flush_req|link_control: \d+ link state in activate)'
  r'|ICP: cam_icp_mgr_flush_info_dump)'),
 ('camera: links do cam-sensor, msm_cvp, ssrm',
  r'qcom,cam-sensor\d: (Linked as a consumer|Dropping the link)|msm_cvp: info: (Opening|Closed) cvp instance|ssrm_camera_info buf'),
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
