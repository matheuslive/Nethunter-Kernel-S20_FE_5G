# Build

`./build.sh` (cabeçalho do script: variáveis, `--companion-only`, `clean`). Saída em `out/`
(objdir) e `build/r8q/` (entregáveis). Release antiga: `tools/repro-release.sh <versão>`.

## Toolchain

Desde 2026-11-27 o toolchain **não fica no repo**: mora numa pasta única, somente leitura,
compartilhada por todos os checkouts e worktrees (antes o `toolchain/` versionado, 1,3 GB e
823 arquivos, era copiado em cada worktree).

```
$TOOLCHAINS                       padrão ~/Android/toolchains (variável de ambiente vence)
├── llvm-arm-toolchain-ship-10.0  clang 10.0.6 (Snapdragon LLVM ARM, "for Android NDK")
├── aarch64-linux-android-4.9     GCC 4.9 do AOSP: só o binutils 2.27 (as, ld, ar, strip...)
└── SHA256SUMS                    sha256 de cada arquivo (773; os 50 symlinks são relativos)
```

Quem usa: `build.sh`, `tools/repro-release.sh`, `tools/build-nomount.sh` e o legado
`build_kernel.sh`, todos por `tools/toolchain.sh` (define `BUILD_CROSS_COMPILE` e
`KERNEL_LLVM_BIN`, confere que os binários existem e executam). O `Makefile` de topo tem o
mesmo padrão (`TOOLCHAINS ?= $(HOME)/Android/toolchains`) para `make` direto e para com erro
claro se o clang faltar; o `build.sh` passa `REAL_CC`/`CFP_CC`/`CROSS_COMPILE` na linha do make
de qualquer forma.

### Origem

Os dois vieram no commit `b8861308e` ("Add toolchain", 2023-09-14) do repo de origem
(`toolchain/llvm-arm-toolchain-ship/10.0` e `toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9`,
o layout do `build_kernel.sh` da Samsung) e não mudaram até saírem do repo. O clang 10 linka
`libtinfo.so.5`: no host precisa do pacote `libtinfo5:amd64` (sem ele o build morre no
defconfig com um enganoso `init/Kconfig:17: syntax error`).

### Recriar a pasta

O histórico do git continua com os arquivos (não foi reescrito):

```sh
T=~/Android/toolchains
mkdir -p "$T.tmp" && git archive b8861308e toolchain/ | tar -x -C "$T.tmp"
mkdir -p "$T"
mv "$T.tmp/toolchain/llvm-arm-toolchain-ship/10.0"                        "$T/llvm-arm-toolchain-ship-10.0"
mv "$T.tmp/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9"     "$T/aarch64-linux-android-4.9"
rm -r ~/Android/toolchains.tmp
(cd "$T" && find llvm-arm-toolchain-ship-10.0 aarch64-linux-android-4.9 -type f -print0 \
   | sort -z | xargs -0 sha256sum > SHA256SUMS)
chmod -R a-w "$T"
```

`git archive` preserva o bit de execução e os symlinks. Conferido em 2026-11-27: o resultado
bate arquivo a arquivo com o `toolchain/` do checkout (sha256 do `clang-10`:
`b655c4e67fe33204…`).

### Release antiga

Checkout de release anterior à remoção ainda tem o `toolchain/` versionado. O
`tools/repro-release.sh` usa o externo mesmo assim, e antes do build confere por sha256
(`SHA256SUMS`) que o `toolchain/` daquele checkout é o mesmo binário; se divergir, para.

### ccache

`tools/toolchain.sh` exporta `CCACHE_COMPILERCHECK=string:<sha256 do clang>` (chave por
conteúdo, calculada uma vez por build) e `CCACHE_BASEDIR=<checkout>`. Com o base_dir no
checkout, os caminhos de dentro dele viram relativos ao objdir e os do toolchain ficam
absolutos: o mesmo objeto tem a mesma chave em qualquer checkout ou worktree. (Com o
`base_dir` global, `~/Android`, os `-isystem`/`--gcc-toolchain` do toolchain virariam
`../../toolchains` no checkout principal e `../../../toolchains` numa worktree.)
