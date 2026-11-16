# zram com lz4/zstd e zswap (v4.17)

Até a v4.15 o kernel só tinha `CRYPTO_LZO`/`CRYPTO_DEFLATE`: o
`/sys/block/zram0/comp_algorithm` listava só `lzo [lzo-rle]` e não havia zswap.
A v4.17 liga, no `wirus_defconfig`:

| símbolo | por quê |
|---|---|
| `CRYPTO_LZ4`, `CRYPTO_LZ4HC` | backends `lz4`/`lz4hc` do zram (lista em `drivers/block/zram/zcomp.c`, condicionada por `IS_ENABLED`) |
| `CRYPTO_ZSTD` | backend `zstd` do zram (puxa `ZSTD_COMPRESS`; o `ZSTD_DECOMPRESS` já existia pelo squashfs) |
| `FRONTSWAP` + `ZSWAP` | o zswap é um backend do frontswap; no 4.19 ele exige os dois |
| `ZBUD` | zpool **default** do zswap no 4.19 (`ZSWAP_ZPOOL_DEFAULT "zbud"`); sem ele o pool inicial falha |

Nada muda sozinho no boot:
- o zram0 continua com o default `lzo-rle` (`default_compressor` do `zram_drv.c`);
- o zswap nasce **desligado** (`zswap_enabled = false` no 4.19, sem Kconfig de
  default), com compressor `lzo` e zpool `zbud`.

## Usar

zram — o algoritmo só pode ser trocado com o device resetado (sem swap ativo):

```sh
cat /sys/block/zram0/comp_algorithm          # lzo [lzo-rle] lz4 lz4hc zstd
swapoff /dev/block/zram0
echo 1    > /sys/block/zram0/reset
echo zstd > /sys/block/zram0/comp_algorithm  # ou lz4
echo 3G   > /sys/block/zram0/disksize
mkswap /dev/block/zram0 && swapon -p 32758 /dev/block/zram0
```

O `swapoff` de um zram cheio força a volta de tudo para a RAM: fazer com
memória livre (ou logo no boot, antes de encher).

zswap — parâmetros em `/sys/module/zswap/parameters/` (graváveis em runtime):

```sh
echo zstd     > /sys/module/zswap/parameters/compressor   # lzo, lz4, lz4hc, zstd, deflate
echo zsmalloc > /sys/module/zswap/parameters/zpool        # zbud (2:1 máx.) ou zsmalloc
echo 20       > /sys/module/zswap/parameters/max_pool_percent
echo Y        > /sys/module/zswap/parameters/enabled
grep -r . /sys/kernel/debug/zswap/                         # estatísticas (debugfs)
```

O zswap só serve com um swap **de disco** (arquivo ou partição) por baixo: ele
intercepta as páginas a caminho desse swap. Sobre o zram é compressão em dobro;
o uso típico é desligar o zram (ou baixá-lo) e pôr um swapfile em `/data` com o
zswap na frente. No 4.19 o zpool `zsmalloc` não implementa o shrink: com o pool
cheio o zswap recusa páginas novas (vão direto para o disco) em vez de evictar
as antigas, como faz o `zbud`.

## Compatibilidade de módulos (0 CRCs mudados)

O `FRONTSWAP` acrescenta `frontswap_map`/`frontswap_pages` ao
`struct swap_info_struct`. No lugar original (meio da struct) isso mudava o
layout e, pelo genksyms, **954 CRCs** do MODVERSIONS: nenhum `.ko` da v4.15
carregaria, inclusive o `nomount.ko` (11 dos 60 imports mudavam), e o
`post-fs-data.sh` do nomount desativa o metamódulo quando o `.ko` não carrega.

Por isso os dois campos foram para o fim da struct (antes do `avail_lists[0]`,
que tem de ser o último) e ficam fora do genksyms (`#ifndef __GENKSYMS__`).
Só o kernel aloca e lê a struct (`alloc_swap_info`), então nenhum módulo vê a
diferença. Resultado contra a v4.15:

```
tools/symvers-crc-check.sh build/r8q/v4.15/Module.symvers build/r8q/v4.17/Module.symvers
>> iguais: 14143, novos: 22, divergentes/ausentes: 0
```

Os 22 novos são exports de LZ4/LZ4HC e do frontswap. O `nomount.ko` da v4.15
e o companion da v4.15 carregam na v4.17, e vice-versa: rollback de kernel não
exige trocar módulo nenhum.
