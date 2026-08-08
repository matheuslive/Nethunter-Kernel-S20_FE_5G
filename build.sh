#!/bin/bash
#
# Build do kernel Nethunter para o Galaxy S20 FE 5G (r8q / SM-G781x).
#
# Tudo que e gerado fica dentro do repo (ver .gitignore):
#   out/              objdir do kbuild (~6 GB)
#   out/AnyKernel3/   copia de trabalho do template AnyKernel3/ (recriada a cada build)
#   build/<variant>/  entregaveis: zip flashavel, dtb.img, dtbo.img e os modulos
#
# Uso:
#   ./build.sh          build incremental + empacota o zip
#   ./build.sh clean    apaga o objdir (forca build do zero na proxima vez)
#
set -euo pipefail

DIR=$(readlink -f "$(dirname "$0")")
cd "$DIR"

DEFCONFIG_NAME=wirus_defconfig
CHIPSET_NAME=kona
VARIANT=r8q
ARCH=arm64
VERSION=NetHunter_matheuslive_${VARIANT}_v4.3
JOBS=$(nproc)

OUT=$DIR/out
DIST=$DIR/build/$VARIANT
AK3=$OUT/AnyKernel3
MAG=$OUT/magisk
BAT=$OUT/magisk-battery
STAGE=$OUT/moddep
DTS_DIR=$OUT/arch/$ARCH/boot/dts

# Versao dos modulos Magisk (versionCode tem que ser inteiro).
MOD_VERSION=v4.3
MOD_VERSIONCODE=43

# Toolchain versionado no proprio repo. O GCC 4.9 entra so como binutils
# (as, ld, ar...) via CROSS_COMPILE; quem compila e o clang do REAL_CC.
# O Makefile deste kernel define CC = python scripts/gcc-wrapper.py $(REAL_CC),
# e atribuicao em Makefile vence variavel de ambiente -- por isso exportar
# CC/LD/AR/LLVM=1 aqui nao teria efeito nenhum, tem que ser via linha de comando.
BUILD_CROSS_COMPILE=$DIR/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
KERNEL_LLVM_BIN=$DIR/toolchain/llvm-arm-toolchain-ship/10.0/bin/clang
CLANG_TRIPLE=aarch64-linux-gnu-
STRIP=${BUILD_CROSS_COMPILE}strip

# ccache quando disponivel: o gcc-wrapper.py da QCOM so faz Popen(argv[1:]),
# entao "ccache clang" no REAL_CC passa reto e cacheia normalmente.
#
# ATENCAO: isto so vale com CONFIG_DEBUG_INFO desligado. Com "-g" o ccache
# separa preprocessamento de compilacao e os labels locais de DWARF ficam
# orfaos, e o link morre em
#   rtl8812au/core/rtw_recv.o:(.debug_info+0x...): undefined reference to `.Linfo_string6102'
if command -v ccache >/dev/null 2>&1 &&
   ! grep -q '^CONFIG_DEBUG_INFO=y' "$DIR/arch/$ARCH/configs/$DEFCONFIG_NAME"; then
	REAL_CC="ccache $KERNEL_LLVM_BIN"
else
	REAL_CC="$KERNEL_LLVM_BIN"
fi

MAKE_ARGS=(
	-C "$DIR"
	O="$OUT"
	ARCH="$ARCH"
	CROSS_COMPILE="$BUILD_CROSS_COMPILE"
	REAL_CC="$REAL_CC"
	CFP_CC="$KERNEL_LLVM_BIN"
	CLANG_TRIPLE="$CLANG_TRIPLE"
	DTC_EXT="$DIR/tools/dtc"
	CONFIG_BUILD_ARM64_DT_OVERLAY=y
	LOCALVERSION="-$VERSION"
)

if [ "${1:-}" = "clean" ]; then
	echo ">> apagando $OUT"
	rm -rf "$OUT"
	exit 0
fi

# Os submodules em drivers/net/can sao obj-y: sem eles o build quebra no link.
if [ -f .gitmodules ] && [ -z "$(ls -A drivers/net/can/can-isotp 2>/dev/null)" ]; then
	echo ">> inicializando submodules"
	git submodule update --init --recursive
fi

# Compila o kernel
mkdir -p "$OUT"
make "${MAKE_ARGS[@]}" "$DEFCONFIG_NAME"
make -j"$JOBS" "${MAKE_ARGS[@]}"

if [ ! -e "$OUT/arch/$ARCH/boot/Image.gz-dtb" ]; then
	echo "!! Image.gz-dtb nao foi gerada" >&2
	exit 1
fi

# Imagens de device tree
mkdir -p "$DIST/modules"
cat "$DTS_DIR"/vendor/qcom/*.dtb > "$DIST/dtb.img"
mapfile -t DTBO_FILES < <(find "$DTS_DIR/samsung/" -name "${CHIPSET_NAME}-sec-${VARIANT}-*-r*.dtbo")
"$DIR/tools/mkdtimg" create "$DIST/dtbo.img" --page_size=4096 "${DTBO_FILES[@]}"

# Coleta os modulos ANTES de mexer em $OUT/AnyKernel3|magisk|moddep (os tres
# moram dentro do $OUT; um find posterior acharia as copias que acabamos de por
# la -- e num build incremental elas sobrevivem da rodada anterior).
mapfile -t MODULES < <(find "$OUT" \( -path "$AK3" -o -path "$MAG" -o -path "$BAT" -o -path "$STAGE" \) -prune -o -name '*.ko' -print)
rm -f "$DIST/modules"/*.ko
if [ ${#MODULES[@]} -gt 0 ]; then
	cp -f "${MODULES[@]}" "$DIST/modules/"
	# CONFIG_DEBUG_INFO=y deixa ~95% de cada .ko em DWARF, que so serve pra
	# debug no host. Os .ko daqui pra frente saem stripped (can327.ko: 495K -> 26K).
	"$STRIP" --strip-debug "$DIST/modules"/*.ko
	mapfile -t MODULES < <(find "$DIST/modules" -name '*.ko')
fi

# --- 1. Zip flashavel KERNEL-ONLY (nao toca particao; ver packaging/) --------
# So o zImage + o anykernel enxuto. Sem system/, vendor/, ramdisk-patch/,
# patch.d/, modules/, ak_patches/ -- essas eram as "NetHunter additions" que
# escreviam em particao read-only. O que ia nelas vai no modulo Magisk abaixo.
rm -rf "$AK3"
cp -a "$DIR/AnyKernel3" "$AK3"
rm -rf "$AK3"/system "$AK3"/vendor "$AK3"/ramdisk-patch "$AK3"/patch.d \
       "$AK3"/modules "$AK3"/ak_patches "$AK3"/.git
cp -f "$DIR/packaging/anykernel-kernelonly.sh" "$AK3/anykernel.sh"
cp -f "$OUT/arch/$ARCH/boot/Image.gz-dtb" "$AK3/zImage"

rm -f "$DIST/$VERSION.zip"
(cd "$AK3" && zip -qr9 "$DIST/$VERSION.zip" ./* -x README.md '*placeholder')

# --- 2. Modulo Magisk companion (.ko + hid-keyboard + init HID) --------------
rm -rf "$MAG"
cp -a "$DIR/packaging/magisk" "$MAG"
rm -f "$MAG/overlay.d/sbin/.gitkeep"
sed -i -e "s/@VERSION@/$MOD_VERSION/" -e "s/@VERSIONCODE@/$MOD_VERSIONCODE/" "$MAG/module.prop"

# .ko via magic mount + indices do depmod.
#
# Os drivers de dongle WiFi sao =m (built-in eles custavam ~7 MB de kernel
# residente mesmo sem dongle nenhum plugado). Quem carrega e o helper
# system/bin/usbwifi, que chama "modprobe -d /system/lib/modules": o modprobe
# do toolbox do Android le modules.dep/modules.alias do diretorio passado no -d.
#
# O depmod exige a arvore <base>/lib/modules/<release>/, entao montamos uma
# staging e levamos so os indices para o diretorio flat do companion.
mkdir -p "$MAG/system/lib/modules"
if [ ${#MODULES[@]} -gt 0 ]; then
	cp -f "${MODULES[@]}" "$MAG/system/lib/modules/"

	KREL=$(cat "$OUT/include/config/kernel.release")
	rm -rf "$STAGE"
	mkdir -p "$STAGE/lib/modules/$KREL"
	cp -f "${MODULES[@]}" "$STAGE/lib/modules/$KREL/"
	# Vazios de proposito: aqui os .ko estao flat, entao o modules.order do
	# kbuild (paths kernel/drivers/...) nao casaria. O depmod so usa esses dois
	# para desempatar alias duplicado; sem eles ele avisa a cada build.
	: > "$STAGE/lib/modules/$KREL/modules.order"
	: > "$STAGE/lib/modules/$KREL/modules.builtin"
	: > "$STAGE/lib/modules/$KREL/modules.builtin.modinfo"
	/sbin/depmod -b "$STAGE" "$KREL"
	cp -f "$STAGE/lib/modules/$KREL"/modules.dep \
	      "$STAGE/lib/modules/$KREL"/modules.alias \
	      "$STAGE/lib/modules/$KREL"/modules.symbols \
	      "$MAG/system/lib/modules/"
fi

# Firmware dos dongles -> /vendor/firmware (magic mount).
#
# O kernel so procura em /lib/firmware*, que nem existe no Android; quem salva
# e o fallback do user helper (CONFIG_FW_LOADER_USER_HELPER_FALLBACK=y): o
# kernel emite uevent e o ueventd procura nos firmware_directories dele
# (/etc/firmware/ /odm/firmware/ /vendor/firmware/ /firmware/image/). Nenhum
# dos drivers de dongle usa request_firmware_direct(), que puraria esse
# caminho, entao /vendor/firmware serve. NAO mexer em firmware_class.path: ele
# aponta para /vendor/firmware_mnt/image e outros subsistemas dependem disso.
#
# Vai em $MODPATH/vendor/, nao em $MODPATH/system/vendor/: neste device
# /system/vendor e um SYMLINK para /vendor, e o magic mount nao o atravessa --
# medido no device em 2026-08-08, nenhum dos 8 firmwares tinha chegado em
# /vendor/firmware/. Modulo com /vendor separado usa a raiz do modulo.
mkdir -p "$MAG/vendor/firmware"
cp -a "$DIR/packaging/firmware/." "$MAG/vendor/firmware/"
rm -f "$MAG/vendor/firmware/README.md"   # doc do repo, nao vai pro device

# Avisa se algum modulo declara firmware que nao esta empacotado -- sem isto,
# habilitar um driver novo faria o firmware sumir em silencio. Os ausentes ja
# analisados ficam nesta lista para o aviso so falar de novidade; o porque de
# cada um esta em packaging/firmware/README.md.
FW_KNOWN_MISSING=(
	fw.ram.bin                           # nome da API 1 do ath6kl; o driver usa fw-N.bin
	ath6k/AR6004/hw1.3/fw.ram.bin        # idem
	ath6k/AR6004/hw1.0/bdata.bin         # revisao inexistente no linux-firmware
	ath6k/AR6004/hw1.0/bdata.DB132.bin   # idem
	ath6k/AR6004/hw1.1/bdata.bin         # idem
	ath6k/AR6004/hw1.1/bdata.DB132.bin   # idem
	rtlwifi/rtl8723bu_bt.bin             # lado BT do 8723BU; o WiFi sobe sem
)
if command -v /sbin/modinfo >/dev/null 2>&1; then
	for ko in "${MODULES[@]}"; do
		/sbin/modinfo -F firmware "$ko" 2>/dev/null
	done | sort -u | while read -r fw; do
		[ -f "$MAG/vendor/firmware/$fw" ] && continue
		case " ${FW_KNOWN_MISSING[*]} " in *" $fw "*) continue ;; esac
		echo "!! firmware declarado e ausente: $fw" >&2
	done
fi

# hid-keyboard e descriptors HID (fontes do template AnyKernel3)
mkdir -p "$MAG/system/bin" "$MAG/system/etc/nethunter"
cp -f "$DIR/AnyKernel3/system/xbin/hid-keyboard" "$MAG/system/bin/"
cp -f "$DIR/AnyKernel3/ramdisk-patch"/*-descriptor.bin "$MAG/system/etc/nethunter/"

# init.nethunter.rc: importado no boot via overlay.d. Reaponta os descriptors
# de / (onde o ramdisk-patch os punha) para /system/etc/nethunter (magic mount).
sed -e 's#copy /\([a-z]*-descriptor.bin\)#copy /system/etc/nethunter/\1#' \
    "$DIR/AnyKernel3/ramdisk-patch/init.nethunter.rc" > "$MAG/overlay.d/sbin/init.nethunter.rc"

rm -f "$DIST/nethunter-companion-$VARIANT.zip"
(cd "$MAG" && zip -qr9 "$DIST/nethunter-companion-$VARIANT.zip" ./*)

# --- 3. Modulo Magisk de bateria (battctl + tuning no boot) ------------------
#
# Independente do companion: nao tem .ko dentro, entao nao depende do vermagic
# e o limite de carga funciona ate em kernel stock. Os batt_tune_* e que exigem
# CONFIG_ENG_BATTERY_CONCEPT=y (v4.3+).
rm -rf "$BAT"
cp -a "$DIR/packaging/magisk-battery" "$BAT"
sed -i -e "s/@VERSION@/$MOD_VERSION/" -e "s/@VERSIONCODE@/$MOD_VERSIONCODE/" "$BAT/module.prop"

rm -f "$DIST/nethunter-battery-$VARIANT.zip"
(cd "$BAT" && zip -qr9 "$DIST/nethunter-battery-$VARIANT.zip" ./*)

ZIPS=(
	"$DIST/$VERSION.zip"
	"$DIST/nethunter-companion-$VARIANT.zip"
	"$DIST/nethunter-battery-$VARIANT.zip"
)

# --- 4. Publica os zips: raiz do repo (symlink) e SD externo do S20 ----------
#
# O recovery so enxerga o SD externo, e a raiz do repo e onde se procura o
# artefato mais recente sem navegar na arvore. Nos dois lugares fica SO a build
# mais recente de cada zip: as anteriores sao podadas, para nao ter que escolher
# entre versoes na hora de flashar. O historico mora em build/<variant>/, que
# nao e tocado.
#
# O que a poda considera "build antiga": qualquer zip de kernel do variant
# (pega tambem os de terceiros, como o Nethunter_WirusMOD -- dai a classe
# [Nn]et[Hh]unter, que os dois estilos de maiuscula usam) e os dois zips de
# modulo, exceto os que acabamos de gerar.
#
# PRUNE fica SEM aspas nos dois "for" abaixo de proposito: e a expansao sem
# aspas que sofre globbing. Entre aspas (ou vindo de "${array[@]/#/...}") o
# padrao chegaria literal no rm.
KEEP=$(printf '|%s' "${ZIPS[@]##*/}")   # "|a.zip|b.zip|c.zip"
KEEP="$KEEP|"
PRUNE="[Nn]et[Hh]unter*_${VARIANT}_v*.zip nethunter-companion-${VARIANT}.zip nethunter-battery-${VARIANT}.zip"

(
	cd "$DIR"
	shopt -s nullglob
	for f in $PRUNE; do
		case "$KEEP" in *"|$f|"*) continue ;; esac
		rm -f "$f" && echo ">> podado da raiz: $f"
	done
)
# Symlinks (ignorados pelo git); os da rodada anterior saem antes.
find "$DIR" -maxdepth 1 -name '*.zip' -type l -delete
for z in "${ZIPS[@]}"; do
	ln -sfn "${z#"$DIR"/}" "$DIR/$(basename "$z")"
done

# Copia para o SD e best-effort: se o celular nao responder, o build nao falha.
# O nome do ponto de montagem e o UUID do cartao, entao e descoberto na hora --
# trocar de cartao muda o caminho.
SD_HOST=${SD_HOST:-root@s20}
if SD_DIR=$(timeout 15 ssh -o ConnectTimeout=8 -o BatchMode=yes "$SD_HOST" \
		'ls -d /storage/????-???? 2>/dev/null | head -1' 2>/dev/null) &&
   [ -n "$SD_DIR" ]; then
	if timeout 300 scp -q "${ZIPS[@]}" "$SD_HOST:$SD_DIR/" 2>/dev/null; then
		echo ">> SD do S20 : $SD_HOST:$SD_DIR (${#ZIPS[@]} zips)"
		# Poda do SD com os mesmos criterios da raiz.
		timeout 60 ssh -o ConnectTimeout=8 -o BatchMode=yes "$SD_HOST" \
			"cd '$SD_DIR' 2>/dev/null || exit 0
			 for f in $PRUNE; do
				[ -e \"\$f\" ] || continue
				case '$KEEP' in *\"|\$f|\"*) continue ;; esac
				rm -f -- \"\$f\" && echo '>> podado do SD: '\"\$f\"
			 done" 2>/dev/null || true
	else
		echo "!! copia para $SD_HOST:$SD_DIR falhou -- copie na mao" >&2
	fi
else
	echo "!! S20 fora de alcance ($SD_HOST): zips nao foram para o SD" >&2
fi

echo
echo ">> $(cat "$OUT/include/config/kernel.release")"
echo ">> kernel   : $DIST/$VERSION.zip ($(du -h "$DIST/$VERSION.zip" | cut -f1))"
echo ">> companion: $DIST/nethunter-companion-$VARIANT.zip ($(du -h "$DIST/nethunter-companion-$VARIANT.zip" | cut -f1))"
echo ">> bateria  : $DIST/nethunter-battery-$VARIANT.zip ($(du -h "$DIST/nethunter-battery-$VARIANT.zip" | cut -f1))"
echo ">> modulos  : $(ls "$DIST/modules" | tr '\n' ' ')"
