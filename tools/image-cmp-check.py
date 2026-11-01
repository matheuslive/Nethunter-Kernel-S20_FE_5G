#!/usr/bin/env python3
"""Confere se os bytes diferentes entre duas Images do kernel sao so os esperados.

Uso:
  tools/image-cmp-check.py <vmlinux> <cmp.txt>

- <cmp.txt>: saida de `cmp -l release.Image repro.Image` (offset 1-based em
  decimal, byte da 1a e da 2a em octal).
- <vmlinux>: o ELF que gerou a Image recompilada (out/vmlinux). As regioes
  esperadas sao achadas nele, nao por offset fixo: offset na Image = VMA - _text.

Regioes aceitas (a release e a reproducao diferem nelas a cada build):
  1. o descriptor de 20 B da nota NT_GNU_BUILD_ID (secao .notes);
  2. dentro do simbolo g_wlan_driver_version (qcacld, o Kbuild dele usa `date`),
     so bytes em que os DOIS lados sao digitos ASCII.
Qualquer outro byte diferente sai com 1 e lista os bytes (objeto corrompido,
fonte diferente, build de outro caminho). Saida 0 = so as regioes esperadas.
"""
import struct
import sys

WLAN_SYM = "g_wlan_driver_version"


def elf_info(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        sys.exit(f"!! {path}: nao e ELF64 little-endian")
    shoff, = struct.unpack_from("<Q", data, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x3A)
    secs = []
    for i in range(shnum):
        name, typ, _fl, addr, off, size, link, _info, _al, entsize = \
            struct.unpack_from("<IIQQQQIIQQ", data, shoff + i * shentsize)
        secs.append(dict(name=name, type=typ, addr=addr, off=off, size=size,
                         link=link, entsize=entsize))
    shstr = secs[shstrndx]

    def cstr(base, idx):
        end = data.index(b"\0", base + idx)
        return data[base + idx:end].decode("latin-1")

    for s in secs:
        s["name"] = cstr(shstr["off"], s["name"])
    syms = {}
    for s in secs:
        if s["type"] != 2:  # SHT_SYMTAB
            continue
        strtab = secs[s["link"]]
        for j in range(s["size"] // 24):
            st_name, _inf, _oth, _shn, val, sz = \
                struct.unpack_from("<IBBHQQ", data, s["off"] + j * 24)
            if st_name:
                n = cstr(strtab["off"], st_name)
                if n in ("_text", WLAN_SYM):
                    syms[n] = (val, sz)
    return data, {s["name"]: s for s in secs}, syms


def build_id_region(data, notes):
    """(vma, len) do descriptor da nota GNU tipo 3, andando nota a nota."""
    p, end = notes["off"], notes["off"] + notes["size"]
    while p + 12 <= end:
        namesz, descsz, typ = struct.unpack_from("<III", data, p)
        name_off = p + 12
        desc_off = name_off + ((namesz + 3) & ~3)
        nxt = desc_off + ((descsz + 3) & ~3)
        if nxt > end:
            break  # nota corrompida/fora do padrao (o readelf tambem reclama)
        if typ == 3 and data[name_off:name_off + namesz] == b"GNU\0":
            return notes["addr"] + (desc_off - notes["off"]), descsz
        p = nxt
    sys.exit("!! NT_GNU_BUILD_ID nao achado na .notes")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    vmlinux, cmpfile = sys.argv[1:]
    data, secs, syms = elf_info(vmlinux)
    for need in ("_text", WLAN_SYM):
        if need not in syms:
            sys.exit(f"!! simbolo {need} ausente em {vmlinux}")
    if ".notes" not in secs:
        sys.exit(f"!! secao .notes ausente em {vmlinux}")
    text = syms["_text"][0]
    bid_vma, bid_len = build_id_region(data, secs[".notes"])
    bid = (bid_vma - text, bid_vma - text + bid_len)
    wv, wl = syms[WLAN_SYM]
    wlan = (wv - text, wv - text + wl)

    n_bid = n_wlan = 0
    bad = []
    with open(cmpfile) as f:
        for line in f:
            parts = line.split()
            if len(parts) != 3:
                bad.append(f"linha inesperada: {line.rstrip()}")
                continue
            off = int(parts[0]) - 1          # cmp -l e 1-based
            a, b = int(parts[1], 8), int(parts[2], 8)
            if bid[0] <= off < bid[1]:
                n_bid += 1
            elif wlan[0] <= off < wlan[1] and 0x30 <= a <= 0x39 and 0x30 <= b <= 0x39:
                n_wlan += 1
            else:
                bad.append(f"offset {off} (0x{off:x}, vma 0x{off + text:x}): "
                           f"0x{a:02x} -> 0x{b:02x}")
    print(f">> build-id (0x{bid[0]:x}+{bid_len}): {n_bid} B; "
          f"{WLAN_SYM} (0x{wlan[0]:x}+{wl}): {n_wlan} B")
    if bad:
        print(f"!! {len(bad)} bytes diferentes FORA das regioes esperadas:")
        for x in bad[:40]:
            print("   " + x)
        if len(bad) > 40:
            print(f"   ... (+{len(bad) - 40})")
        sys.exit(1)
    print(">> nenhum byte diferente fora das regioes esperadas")


if __name__ == "__main__":
    main()
