// SPDX-License-Identifier: GPL-2.0
/*
 * *** SHELVED / NAO COMPILAR ***
 * Este approach BOOTLOOPA no Galaxy S20 FE (r8q). Gravado no kernel v4.16
 * (2026-11-06) causou bootloop; o aparelho foi recuperado por re-flash do
 * boot v4.15. O patch esta tecnicamente correto, mas o device o rejeita --
 * causa provavel (NAO confirmada; o pstore nao guardou o panic): a escrita
 * in-place no saved_command_line e/ou na prop bootargs do /chosen cai em
 * memoria protegida pelo RKP/KDP da Samsung (reset em violacao). Removido do
 * init/Makefile (obj-y); mantido so como referencia. Ver
 * docs/bootstate-spoof.md. NAO re-adicionar ao build sem contornar o RKP/KDP.
 */
/*
 * bootstate_spoof.c - oculta o estado real do bootloader das fontes que o
 * kernel expoe ao userspace via /proc.
 *
 * O bootloader passa, no cmdline (DT chosen/bootargs), os tokens
 *   androidboot.verifiedbootstate=orange   (bootloader destravado)
 *   androidboot.warranty_bit=1             (knox/warranty queimado)
 * que vazam para /proc/cmdline e /proc/device-tree/chosen/bootargs. Este
 * patch reescreve, no boot, esses dois tokens para o estado "travado"
 * (green / 0) nas DUAS memorias que alimentam esses arquivos:
 *
 *   - saved_command_line    -> impresso por fs/proc/cmdline.c
 *   - prop "bootargs" do no /chosen do device tree -> alimenta
 *     /proc/device-tree/chosen/bootargs
 *
 * A substituicao e IN-PLACE e de MESMO COMPRIMENTO (nunca realoca):
 *   "verifiedbootstate=orange" -> "verifiedbootstate=green " (6 -> "green "+sp)
 *   "warranty_bit=1"           -> "warranty_bit=0"
 * O espaco extra antes do proximo token e inofensivo para qualquer parser.
 *
 * ORDEM (critico - senao vira bootloop):
 * drivers/md/dm-android-verity.c le "androidboot.verifiedbootstate=" por
 * __setup (cedo, no parse_args do start_kernel) para um buffer estatico, e
 * em is_unlocked() compara com "orange": se NAO for "orange" liga o dm-verity
 * em enforcing, o que quebra o boot num /system modificado. Varios
 * security/samsung/{five,defex,kdp} e sec_debug_pwdt tambem leem via
 * __setup, cedo. Por isso a troca TEM de ser num late_initcall, que roda
 * MUITO depois de todos os __setup/initcalls (e antes do init do userspace):
 * nesse ponto o dm-android-verity ja leu o "orange" real para o buffer dele
 * (verity permanece off) e a decisao in-kernel de verity NAO usa
 * saved_command_line nem a prop do DT. Reescreve-los tarde so muda o que /proc
 * expoe. NUNCA usar early_param/__setup/core_initcall aqui.
 */

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/string.h>
#include <linux/of.h>

/* Substitui, in-place, a 1a ocorrencia do token completo "find" por "repl".
 * Exige strlen(find) == strlen(repl) (mesmo comprimento, nunca realoca).
 * "buf" e NUL-terminada (saved_command_line e a prop bootargs do DT sao). */
static void __init replace_token(char *buf, const char *find, const char *repl)
{
	char *p;

	if (!buf)
		return;

	p = strstr(buf, find);
	if (p)
		memcpy(p, repl, strlen(find));
}

static void __init spoof_buf(char *buf)
{
	replace_token(buf, "verifiedbootstate=orange", "verifiedbootstate=green ");
	replace_token(buf, "warranty_bit=1",           "warranty_bit=0");
}

static int __init bootstate_spoof_init(void)
{
	struct device_node *np;

	/* Fonte 1: /proc/cmdline */
	spoof_buf(saved_command_line);

	/* Fonte 2: /proc/device-tree/chosen/bootargs */
	np = of_find_node_by_path("/chosen");
	if (np) {
		int len;
		struct property *prop = of_find_property(np, "bootargs", &len);

		if (prop && prop->value)
			spoof_buf((char *)prop->value);
		of_node_put(np);
	}

	return 0;
}
late_initcall(bootstate_spoof_init);
