#!/bin/bash
# Grava o kernel de um zip AnyKernel no S20 com o Android LIGADO (sem recovery),
# pelo magiskboot (binario avulso no aparelho; ver MB abaixo), sobre a imagem de
# boot atual:
#   - backup do boot atual (fica no aparelho e em build/r8q/boot-<atual>-<data>.img);
#   - split do zImage (Image.gz-dtb) do zip, hexpatch skip_initramfs -> want_initramfs
#     (faz o kernel usar o ramdisk da particao boot, stock ou Magisk; validado na
#     v4.15 com ramdisk stock);
#   - troca so o kernel; ramdisk, cmdline, dtb e kernel_dtb ficam os do boot atual;
#   - grava so se a particao nao mudou desde o backup e confere o md5 relendo-a.
# Nao reinicia o aparelho. Gravar so com aprovacao explicita do usuario.
#
# Uso: tools/flash-booted.sh <zip> [--write]
#   sem --write: so prepara e confere a imagem nova (nada e gravado).
#
# MB: caminho do magiskboot NO APARELHO. Sem MB no ambiente, usa o primeiro que
# existir entre /data/adb/tools/magiskboot, /data/adb/ksu/bin/magiskboot e
# /data/adb/magisk/magiskboot (este so existe com o Magisk instalado).
set -euo pipefail

ZIP=${1:?uso: $0 <zip> [--write]}
WRITE=${2:-}
HOST=${S20_HOST:-root@s20}
MB=${MB:-}
DIR=$(cd "$(dirname "$0")/.." && pwd)
WD=/data/local/tmp/flash-booted
LOCAL=$DIR/tmp/flash-booted
STAMP=$(date +%F)

mkdir -p "$LOCAL"
unzip -o -q "$ZIP" zImage -d "$LOCAL"
ssh "$HOST" "rm -rf $WD; mkdir -p $WD"
scp -q "$LOCAL/zImage" "$HOST:$WD/"

ssh "$HOST" 'sh -s' <<EOF
set -e
cd $WD
MB='$MB'
if [ -z "\$MB" ]; then
	for c in /data/adb/tools/magiskboot /data/adb/ksu/bin/magiskboot \
		/data/adb/magisk/magiskboot; do
		[ -x "\$c" ] && { MB=\$c; break; }
	done
fi
[ -n "\$MB" ] && [ -x "\$MB" ] || {
	echo "magiskboot nao encontrado no aparelho (defina MB=<caminho>)"; exit 1; }
echo "magiskboot: \$MB"
B=\$(readlink -f /dev/block/by-name/boot)
dd if=\$B of=boot-cur.img bs=4M 2>/dev/null
md5sum boot-cur.img | cut -d' ' -f1 > boot-cur.md5
mkdir u s chk
(cd u && \$MB unpack -h ../boot-cur.img >/dev/null 2>&1)
(cd s && \$MB split ../zImage >/dev/null 2>&1)
\$MB hexpatch s/kernel 736B69705F696E697472616D667300 \
	77616E745F696E697472616D667300 >/dev/null 2>&1 || true
grep -q want_initramfs s/kernel || { echo "hexpatch falhou"; exit 1; }
cmp -s s/kernel_dtb u/kernel_dtb || echo "aviso: kernel_dtb do zip difere do atual (mantido o atual)"
grep -ao 'matheuslive_r8q_v[0-9.]*' u/kernel | head -1 > cur.ver || true
cp s/kernel u/kernel
(cd u && \$MB repack ../boot-cur.img ../boot-new.img >/dev/null 2>&1)
(cd chk && \$MB unpack ../boot-new.img >/dev/null 2>&1)
cmp chk/kernel s/kernel && cmp chk/ramdisk.cpio u/ramdisk.cpio && cmp chk/dtb u/dtb
md5sum boot-new.img | cut -d' ' -f1 > boot-new.md5
echo "atual: \$(cat boot-cur.md5)  nova: \$(cat boot-new.md5)"
EOF

# versao pelo kernel que ESTA na particao (pode diferir do que esta rodando)
# (lida antes do cp s/kernel u/kernel; depois dele o u/kernel ja e o novo)
CUR=$(ssh "$HOST" "cat $WD/cur.ver" | sed 's/.*_//')
scp -q "$HOST:$WD/boot-cur.img" "$DIR/build/r8q/boot-${CUR:-atual}-$STAMP.img"
echo ">> backup: build/r8q/boot-${CUR:-atual}-$STAMP.img"

[ "$WRITE" = --write ] || { echo ">> preparado, nada gravado (use --write)"; exit 0; }

ssh "$HOST" 'sh -s' <<EOF
set -e
cd $WD
B=\$(readlink -f /dev/block/by-name/boot)
[ "\$(md5sum < \$B | cut -d' ' -f1)" = "\$(cat boot-cur.md5)" ] ||
	{ echo "particao mudou desde o backup, abortando"; exit 1; }
dd if=boot-new.img of=\$B bs=4M conv=fsync 2>/dev/null
sync; echo 3 > /proc/sys/vm/drop_caches
R=\$(md5sum < \$B | cut -d' ' -f1)
[ "\$R" = "\$(cat boot-new.md5)" ] && echo ">> gravado e relido: \$R" ||
	{ echo "!! md5 relido \$R difere da imagem nova"; exit 1; }
EOF
