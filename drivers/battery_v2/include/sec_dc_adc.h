/*
 * sec_dc_adc.h
 * Ponte entre o sec_battery (no /sys/class/power_supply/battery/dc_adc) e o
 * ADC do direct charger PCA9468 (kernel NetHunter r8q, v4.21).
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.
 */
#ifndef __SEC_DC_ADC_H
#define __SEC_DC_ADC_H __FILE__

#include <linux/string.h>

/* Um retrato do ADC do PCA9468, com as conversoes do pca9468_read_adc(). */
struct sec_dc_adc {
	int vin;	/* mV */
	int iin;	/* mA, com o adc_comp_gain e piso 0 */
	int vbat;	/* mV */
	int vout;	/* mV */
	int ichg;	/* mA */
	int dietemp;	/* 0,1 C, com o clamp DIETEMP_MIN/MAX */
	int ichg_set;	/* mA, ultimo ICHG programado pelo driver */
	int iin_set;	/* mA, ultimo IIN programado pelo driver */
	int vfloat;	/* mV, ultima V_FLOAT programada pelo driver */
	int active;	/* 1 = direct charging ativo e ADC valido */
};

#if IS_BUILTIN(CONFIG_CHARGER_PCA9468)
/* Nunca falha nem imprime: sem chip, sem DC ou com erro de i2c, os campos
 * do ADC ficam 0 e active = 0 (os setpoints sao o estado do driver, 0 sem
 * chip). Nao mexe no adc_val[] nem em nenhum estado do driver.
 */
void pca9468_get_dc_adc(struct sec_dc_adc *out);
#else
static inline void pca9468_get_dc_adc(struct sec_dc_adc *out)
{
	memset(out, 0, sizeof(*out));
}
#endif

#endif /* __SEC_DC_ADC_H */
