# KernelSU-Next no kernel próprio (v4.13)

A partir da v4.13, o kernel NetHunter 4.19.113 traz o **KernelSU-Next** builtin, para trocar o
root do S20 (SM-G780G, G780GXXSBEXG1, One UI 5.1) do Magisk para o KernelSU sem sair deste
kernel. Os kernels de terceiros do r8q com KernelSU (família not_kernel, 4.19.325) não bootam
neste firmware: devolvem `uname` falso (5.10.241) só ao root, e o netd e o netbpfload do
Android 13 discordam sobre o `inet_release`. E o TODO #6 já descartou subir esta árvore para o
4.19.325.

**Nada foi gravado no aparelho.** O flash e as duas fases abaixo são decisão do usuário.

## Por que o KernelSU-Next (decisão do usuário, 2026-11-03)

- É o fork com mais gente usando e mantendo (4,7 mil estrelas, release a cada poucas semanas) e
  mantém uma linha **non-GKI** de verdade, a branch `legacy`: a `dev` (v3.4.x) é só GKI 2.0/1.0,
  e a `legacy` recebe os backports para 3.4–5.4 (último commit em 2026-10-26).
- Hook **manual**: chamadas explícitas no fonte, verificáveis no build e sem patch de texto do
  kernel em runtime nem kprobes.
- O ReZygisk 1.0.0 reconhece o manager (`com.rifsxd.ksunext` está na lista dele) e a variante
  (ioctl `KSU_IOCTL_GET_HOOK_MODE`, específico do Next).
- **SUSFS fica para uma versão futura.** Ele mexe em structs do VFS (`struct inode`, `mount`
  etc.), o que muda o layout e os CRCs do MODVERSIONS e obriga a recompilar todos os `.ko`.

## Versão: driver 33294 = manager v3.4.0

| | |
|---|---|
| Submódulo | `KernelSU-Next/` → `github.com/KernelSU-Next/KernelSU-Next`, **tag `v3.4.0-legacy`** (`8af3d4fe`, 2026-09-25) |
| Driver | `KSU_VERSION` = 30000 + 3005 commits + 289 = **33294**, uapi **4** (o build imprime `-- KernelSU-Next version: 33294`) |
| Manager | **`KernelSU_Next_v3.4.0_33294-release.apk`** (release v3.4.0, 2026-09-21), pacote `com.rifsxd.ksunext`, versionCode 33294, uapi 4; md5 `c89d54e2959eecd5a2063bbd4da05bc7` |
| Assinatura | v2, cert de 0x3e6 B, SHA-256 `79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7`: é o par `KSU_NEXT_MANAGER_SIZE`/`HASH` que o driver aceita (conferido com `apksigner`) |

Por que a tag e não a ponta da `legacy`: é a única release non-GKI, e o par exato com o manager
importa, porque o `ksud` (que vem dentro do APK) confere a uapi (`ensure_uapi_version_matched`)
e pula os estágios se ela não bater. A ponta da `legacy` (`b933b1f7`, driver 33318) já está na
uapi **6**, à frente de qualquer manager publicado (o v3.4.2 é uapi 5).

### Patch local sobre a tag: deadlock do `pkg_observer` (decisão do usuário, 2026-11-03)

Na tag, o `track_throne()` roda **dentro** do callback do fsnotify em `/data/system`, ainda sob o
`down_write()` que o rename pegou no `i_rwsem` do diretório. Abrir o `packages.list` com o
dcache frio pega o mesmo rwsem: o processo trava no próprio lock segurando o
`throne_tracker_mutex`, e installd/system_server enfileiram atrás (travamento ao instalar ou
atualizar app). O upstream corrigiu isso depois da tag, em `d652a89d` + `a56b9199`.

`patches/kernelsu-next/0001-pkg_observer-defer-track_throne.patch` porta só a parte do
`kernel/manager/pkg_observer.c`: o `track_throne()` vai para `task_work` (roda antes de a
syscall voltar ao userspace, fora do lock), e o evento só conta com `FS_CREATE|FS_MOVED_TO`.
Antes, todo open/close do `packages.list` disparava um rescan de `/data/app`. Ficam de fora a
vigia de `/data/adb` (depende do `cd739c78`) e os outros arquivos do `a56b9199` (sulog,
event_queue, apk_sign, throne_tracker), que são correções independentes. O arquivo resultante
é idêntico ao `pkg_observer.c` da ponta da `legacy`, exceto pela vigia de `/data/adb`
(conferido com `diff`). Não mexe em uapi nem em versão.

Como é aplicado: o `tools/ksu-patches.sh` aplica `patches/kernelsu-next/*.patch` no working
tree do submódulo, de forma idempotente (aplicado é pulado; patch que não aplica nem reverte é
fatal). O `build.sh` e o `tools/repro-release.sh` o chamam antes do `make`. O commit do
submódulo continua o da tag, então a versão (`rev-list --count` + 289) segue **33294**, e o
`git status` do kernel mostra o submódulo com "modified content": é esperado. O hook LSM
`inode_rename` continua chamando o `track_throne()` direto, como na ponta da `legacy` (só depois
do boot e só quando o `system` renomeia o `packages.list`).

Outros commits da `legacy` depois da tag, para um bump futuro (quando sair a próxima release
`-legacy` com manager):
- `0550f9eb`: quatro defeitos de mutação de policy do SELinux; `465490a2`: dormir com o
  `policy_rwlock` de escrita.
- `7eac8a17`/`cd739c78`: no caminho de syscall, `su` cai em `sh` enquanto não houver `ksud`.
  Não afeta o hook manual deste kernel (o caminho manual só reescreve para o ksud depois de
  conferir o allowlist, que na fase 1 está vazio).

## Integração

Submódulo + symlink `drivers/kernelsu` → `../KernelSU-Next/kernel`, `obj-$(CONFIG_KSU)` em
`drivers/Makefile` e `source "drivers/kernelsu/Kconfig"` em `drivers/Kconfig`. Antes de buildar
num clone novo: `git submodule update --init KernelSU-Next`. O clone tem de ser **completo**: a
versão sai de `git rev-list --count` (um clone raso daria outro número; em caso de dúvida,
`KSU_VERSION_OVERRIDE=33294` no make).

Config (fim do `wirus_defconfig`; conferir sempre no `out/.config`): `CONFIG_KSU=y`,
`CONFIG_KSU_MANUAL_HOOK=y` (precisa ser explícito: com `KPROBES=y` o default seria o modo
kprobes, que o Kconfig diz não servir abaixo do 5.10), `KSU_DEBUG`, `DISABLE_MANAGER`,
`DISABLE_POLICY` e `ALLOWLIST_WORKAROUND` desligados.

### Hooks manuais

| Arquivo | Função | Chamada |
|---|---|---|
| `fs/exec.c` | `do_execveat_common` | `ksu_handle_execveat` enquanto `ksu_execveat_hook` (ksud/init), depois `ksu_handle_execveat_sucompat` (cobre execve, execveat e o compat de 32 bits) |
| `fs/open.c` | `do_faccessat` | `ksu_handle_faccessat` |
| `fs/stat.c` | `vfs_statx` | `ksu_handle_stat` |
| `fs/stat.c` | `newfstat` | `ksu_handle_newfstat_ret` (corrige o `st_size` do init.rc que o init lê) |
| `fs/read_write.c` | `ksys_read` | `ksu_handle_sys_read` enquanto `ksu_vfs_read_hook` (injeção do rc do ksud) |
| `drivers/input/input.c` | `input_handle_event` | `ksu_handle_input_handle_event` enquanto `ksu_input_hook` (safe mode: volume− 3× no boot) |
| `kernel/reboot.c` | `reboot` | `ksu_handle_sys_reboot` (supercall: entrega o fd do driver; não reinicia nada) |

`task_fix_setuid`, `inode_rename` (rastreio do manager pelo `packages.list`) e `inode_permission`
vão pelo LSM (`security_add_hooks` no `__init`). devpts não tem hook nesta versão (a chamada
está comentada no próprio driver).

### O Kbuild do KSU-Next reescreve o fonte do kernel: aqui não

O `kernel/Kbuild` da tag aplica `sed -i` no fonte do kernel **durante o build**, quando não acha
certas funções. Com `-j`, isso rodaria em paralelo com a compilação dos mesmos arquivos. Por
isso as condições já estão satisfeitas no fonte (a árvore fica limpa depois do build: conferido
no `git status`):
- `fs/namespace.c`/`fs/internal.h`: `can_umount()`/`path_umount()` do 5.9 (umount de módulos
  por app), escritos à mão no lugar do sed, com o ramo `CONFIG_KDP_NS` da Samsung.
- `include/linux/seccomp.h`: `atomic_t filter_count` (o KSU zera ao tirar o seccomp do processo
  com root). Fica nos **4 bytes de padding** entre `int mode` e `filter` (o `sizeof` continua 16
  no arm64, e o `_Static_assert` no `kernel/seccomp.c` garante isso) e **fora do genksyms**
  (`#ifndef __GENKSYMS__`). Assim nem o layout do `task_struct` nem os CRCs mudam. O sed do
  upstream poria o campo no mesmo lugar, mas mudaria o CRC de tudo o que alcança o
  `task_struct`.
- `lib/string.c`/`include/linux/string.h`: `strscpy_pad()` do 5.2 (`458a3bf82df4`). O
  `kernel_compat.h` do KSU-Next supõe que todo kernel ≥ 4.14.222 o tem (backport das LTS), e o
  4.19.113 da Samsung não tem. É um símbolo exportado novo, e não muda nenhum CRC.
- `security/selinux/include/objsec.h`: acessores `selinux_inode()`/`selinux_cred()` (do 5.1),
  que só devolvem o ponteiro. `hooks.c`, `selinuxfs.c` e `xfrm.c` ficaram **intocados**, exceto
  por um comentário que contém as strings procuradas pelo Kbuild. Sem ele, o sed reescreveria
  dezenas de acessos no SELinux da Samsung.

Checagens de Samsung do driver: `SAMSUNG_UH_DRIVER_EXIST` é definido (o `kernel/cred.c` cita
`CONFIG_KDP_CRED`), e o `#error` dele só dispara com `CONFIG_UH`/`KDP`/`RKP`, que estão todos
desligados aqui (como `DEFEX`). `SECURITY_SELINUX_ALWAYS_ENFORCE=y` não atrapalha: o KSU muda a
policy, não o modo.

## ABI dos `.ko`

Com `MODVERSIONS=y`, o `same_magic()` do `kernel/module.c` ignora a primeira palavra do vermagic
(a release `4.19.113-…_v4.13`): o que decide se um `.ko` carrega são os **CRCs**. A v4.13 não
muda nenhum CRC de símbolo da v4.12; o resultado do join está em [Checagens do build](#checagens-do-build).

- **Companion** (`nethunter_companion_r8q`, 36 `.ko`): o `build.sh` o recompila junto
  (v4.13). O da v4.12 também carregaria, pelos CRCs, mas sai junto por consistência.
- **nomount.ko** (`tools/build-nomount.sh v4.13`, [docs/nomount.md](nomount.md)): os CRCs
  também carregam, mas quem compara `uname -r` com o vermagic do `.ko` antes do `insmod` tem de
  receber o `.ko` da v4.13 (gerado; ver Checagens).

## Plano de migração em duas fases

A mecânica: o AnyKernel troca só a Image e preserva o ramdisk (o Magisk
continua lá), e o *Complete Uninstall* do Magisk restaura o boot de backup dele, **com o kernel
antigo**. Por isso o kernel é regravado depois da desinstalação.

### Fase 1: v4.13 com o Magisk intacto, sem manager

1. Backup do boot atual (v4.12 + Magisk): o `tools/flash-booted.sh` faz isso sozinho, ou pelo
   recovery. Rollback = gravar o `NetHunter_matheuslive_r8q_v4.12.zip` (em `ZIP/` no S20) ou o
   backup.
2. Gravar o `NetHunter_matheuslive_r8q_v4.13.zip` e o `nethunter-companion-r8q-v4.13.zip`.
3. **Não instalar o manager nem nenhum metamódulo.** Sem `/data/adb/ksud`, o KSU não dá root a
   ninguém, mas **não fica inerte**: no second stage do init ele aplica as regras dele na policy
   (por cima da que o magiskinit já patchou), injeta no init.rc as linhas `exec … /data/adb/ksud
   post-fs-data|services|boot-completed` (que falham por arquivo ausente) e mantém os hooks e o
   LSM ativos. É essa convivência que a fase 1 testa. O sucompat não intercepta nada: o
   allowlist está vazio, e o root do Magisk (domínio `magisk`) não é o domínio do KSU (`ksu`).
4. Conferir:
   - `uname -r` = `4.19.113-NetHunter_matheuslive_r8q_v4.13`; `sys.boot_completed=1`.
   - `dmesg | grep -i kernelsu`: o banner e `KernelSU-Next: Hook mode: Manual` no log do build.
   - Magisk e módulos como antes: `magisk -c`, a lista de módulos, Zygisk/ReZygisk. O
     `rezygiskd` deve logar **"Magisk root implementation found"**, não "Multiple": ele acha o
     KSU pelo `reboot()`, mas sem `/data/adb/ksu/bin/ksud` o descarta.
   - Companion: `lsmod` com ath9k_htc e usbip.
5. Rollback se não bootar: recovery → zip da v4.12 (ou o backup do boot). Vale o mesmo roteiro de
   diagnóstico de bootloop de agosto (`/proc/last_kmsg` sobrevive ao reboot neste kernel).

### Fase 2: trocar o root

6. Antes: salvar a lista de apps com root e a DenyList (`magisk.db` não migra). Ex.: como root, `magisk --sqlite "SELECT * FROM policies"` e `magisk --denylist ls` para
   arquivo.
7. Magisk app → Desinstalar → **Desinstalação completa**. Reboot (volta o kernel do backup do
   Magisk). ⚠️ Ele só restaura o boot se achar `/data/magisk_backup_<sha1>` casando com a imagem
   que patchou, e depois de vários reflashes por AnyKernel/`tools/flash-booted.sh` isso pode não
   existir mais: conferir `ls /data/magisk_backup_*` antes. Alternativa sem passar por um kernel
   antigo: montar com o `magiskboot` um boot = ramdisk stock (do firmware G780GXXSBEXG1) + Image
   da v4.13 e gravá-lo direto (mesmo padrão do `flash-booted.sh`), e depois tirar o
   `/data/adb/magisk*` e o app do Magisk.
8. Recovery → `NetHunter_matheuslive_r8q_v4.13.zip` de novo, agora sobre um ramdisk sem Magisk.
   Reboot.
9. Instalar o `KernelSU_Next_v3.4.0_33294-release.apk` (deve mostrar "Funcionando", versão
   33294, modo de hook manual). Não usar outro manager: o driver só aceita a assinatura acima.
10. Instalar o **metamódulo** pelo manager e reiniciar (abaixo). Antes disso, nenhum módulo
    monta: no KSU-Next 3.4 o `ksud` **não monta nada sozinho**. A montagem é só o
    `metamount.sh` do metamódulo, que roda depois dos `post-fs-data.sh` dos módulos.
11. Reconfigurar: root por app pelo manager e a antiga DenyList como App Profile "umount
    modules" por app.

### Metamódulo

O KSU-Next v3.4.0 **precisa de metamódulo** para montar os módulos: o `ksud` não monta nada
sozinho, e a montagem é só o `metamount.sh` do metamódulo, que roda depois dos
`post-fs-data.sh` dos módulos.

- **Recomendado: o nomount upstream v2.2.0** (`github.com/maxsteeel/nomount`, `module/`), que
  já é um metamódulo do KSU (`metamodule=true`, `metamount.sh`, `metainstall.sh`) e carrega o
  `.ko` por `ksud insmod`. O `customize.sh` dele procura `nomount-android*-4.19.ko` pelo nome de
  GKI, que este kernel não tem, então o `.ko` da v4.13 entra já como `lkm/nomount.ko`. Um
  nomount adaptado ao Magisk (`insmod` no post-fs-data + `skip_mount` para o magic mount pular)
  perde o sentido sob o KSU, porque não há magic mount.
- Fallback: `meta-overlayfs` (o metamódulo oficial; `CONFIG_OVERLAY_FS=y` está aqui).
- Para depois: nomount builtin (`CONFIG_NOMOUNT=y`), que dispensa o `insmod`.

## Módulos públicos que mudam de comportamento sob o KernelSU-Next

| Módulo | Sob KernelSU-Next |
|---|---|
| ReZygisk v1.0.0 | **ok.** `which magisk` só escolhe o caminho; acha o KSU pelo fd do `reboot()` e reconhece `com.rifsxd.ksunext` e a variante Next. O `sepolicy.rule` já traz as regras para o domínio `ksu`. Módulos Zygisk seguem por ele |
| zygisk-detach | **degrada:** o `magisk --denylist` do `post-fs-data.sh` falha (sem efeito colateral); o resto funciona |
| PlayIntegrityFix | **revisar:** usa `/data/adb/magisk/util_functions`, `/data/adb/magisk/busybox` e `magisk --denylist`; o `resetprop` vem do ksud. Atualizar para a versão do PIF que suporta KSU |
| nomount (upstream) | vira o **metamódulo** (acima) |

Regras gerais para os demais:
- `post-fs-data.d/`, `post-mount.d/` e `service.d/` em `/data/adb` rodam igual no KSU
  (`exec_common_scripts`).
- O `ksud` cria `/data/adb/ksu/bin/resetprop` (link para ele mesmo) e põe `/data/adb/ksu/bin`
  no PATH dos scripts de módulo; o busybox é `/data/adb/ksu/bin/busybox`.
- O domínio SELinux do root é **`ksu`** (`u:r:ksu:s0`), não `magisk` nem `su`: regra de
  `sepolicy.rule` ou `ksud sepolicy patch` que cite `magisk` precisa da variante `ksu`.
- `.replace` não existe (nenhum módulo daqui usava). Módulo não instala pelo recovery, só pelo
  manager ou por `ksud module install`.
- O `ksud` **pula os estágios** se ainda achar o Magisk (`utils::has_magisk()`). Daí a ordem
  da fase 2: nunca instalar o manager com o Magisk no ramdisk.
- O `overlay.d/` do companion (rc do gadget HID, experimental) não é processado sem
  magiskinit.

## Checagens do build

Build de 2026-11-03 (`-j6`, `Linux version 4.19.113-NetHunter_matheuslive_r8q_v4.13 … #1 SMP
PREEMPT`, 2º build às 17:02 com o patch do `pkg_observer`), sem nenhum warning no `drivers/kernelsu/` (o
`gcc-wrapper.py` os torna fatais):

- **Config** (`out/.config`): `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`, os outros quatro
  desligados. O log do Kbuild: `KernelSU-Next version: 33294`, `tag: v3.4.0-legacy`, `Hook
  mode: Manual`, assinatura do manager `0x3e6`/`79e59011…`.
- **Fonte intacto depois do build:** o `git diff` é o mesmo de antes (fora a correção do
  `strscpy_pad`). Nenhum `sed` do Kbuild rodou.
- **Image** (`zImage` do zip): banner com a v4.13, strings do driver (315 com `KernelSU`), a
  tag `v3.4.0-legacy` e o rc injetado (`exec u:r:ksu:s0 root -- /data/adb/ksud post-fs-data`,
  `services`, `boot-completed`). No `vmlinux`: `kernelsu_init`, os sete `ksu_handle_*` dos
  hooks, `path_umount` e `strscpy_pad`.
- **Patch na Image:** as strings novas `defer track_throne: alloc failed` e `task_work_add
  failed` estão no `zImage`; o `Module.symvers` é idêntico ao do build sem o patch.
- **CRCs** (`tools/symvers-crc-check.sh build/r8q/v4.12/Module.symvers
  build/r8q/v4.13/Module.symvers`): **14142 iguais, 0 divergentes/ausentes, 1 novo**
  (`strscpy_pad`). O `module_layout` é o mesmo `0x185d1607` desde a v4.11. O vermagic dos
  `.ko` só difere na release (`…_v4.12` × `…_v4.13`), e isso o MODVERSIONS ignora. Os `.ko`
  da v4.12 carregariam na v4.13.
- **nomount.ko da v4.13** (`KDIR=<worktree> tools/build-nomount.sh v4.13`): 60 de 60 CRCs, em
  `build/r8q/v4.13/nomount/` (o "(605)" no `modinfo` é a contagem de commits do clone novo; o
  commit é o mesmo `bf1847f`).

A Image da v4.13 foi compilada na worktree `kernelsu`, não no checkout principal. Por isso
`tools/repro-release.sh v4.13` rodado do checkout principal **não** reproduz byte a byte: os
caminhos entram via `__FILE__`, e o `image-cmp-check.py` acusa a diferença. Não é preciso:
`Module.symvers`, `vmlinux` e `.config` já estão salvos em `build/r8q/v4.13/`.

### Entregáveis

| Arquivo | md5 | Onde |
|---|---|---|
| `NetHunter_matheuslive_r8q_v4.13.zip` (22 MB) | `0ba019e5bbf3f56098c3e917382cda9d` | `build/r8q/`, raiz do SD (substitui o v4.12, que fica em `ZIP/`), `/sdcard/ZIP/`, `<SD>/ZIP/` |
| `nethunter-companion-r8q.zip` (v4.13) | `344eb7993d571d419edd7132aac57c73` | `build/r8q/`, raiz do SD; `nethunter-companion-r8q-v4.13.zip` nas duas `ZIP/` |
| `KernelSU_Next_v3.4.0_33294-release.apk` | `c89d54e2959eecd5a2063bbd4da05bc7` | as duas `ZIP/` (não instalado) |
| `nomount.ko` + `nm` da v4.13 | `build/r8q/v4.13/nomount/md5.txt` | só na workstation |

Rollback: `NetHunter_matheuslive_r8q_v4.12.zip` e `nethunter-companion-r8q-v4.12.zip` nas
duas `ZIP/`, mais os backups `boot-`, `dtbo-` e `vbmeta-nethunter-v4.12-20261103.img`
(gravados lá em 2026-11-03, 14:59).
