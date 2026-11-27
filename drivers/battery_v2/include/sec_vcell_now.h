/*
 * sec_vcell_now.h
 * Ponte entre o sec_battery (no /sys/class/power_supply/battery/vcell_now) e
 * o VCELL do fuel gauge MAX77705 (kernel NetHunter r8q, v4.22).
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.
 */
#ifndef __SEC_VCELL_NOW_H
#define __SEC_VCELL_NOW_H __FILE__

#include <linux/errno.h>

#if IS_BUILTIN(CONFIG_FUELGAUGE_MAX77705)
/* Leitura fresca do registrador VCELL, em uV (passo de 78,125 uV, sem
 * arredondar a mV). Uma transacao i2c, sem retry, sem kmsg e sem mexer em
 * nenhum estado do fuel gauge. 0 ou -EIO (falha de i2c) / -ENODEV (sem
 * fuel gauge).
 */
int max77705_fg_get_vcell_uv(int *uv);
#else
static inline int max77705_fg_get_vcell_uv(int *uv)
{
	*uv = 0;
	return -ENODEV;
}
#endif

#endif /* __SEC_VCELL_NOW_H */
