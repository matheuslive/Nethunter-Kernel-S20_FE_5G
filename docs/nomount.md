# nomount como `.ko` para a v4.11 gravada

[nomount](https://github.com/maxsteeel/nomount) (GPL-2, maxsteeel) redireciona caminhos no
VFS sem mount: as regras ficam em RAM e o controle é por `add_key` com o tipo de chave
`nomount`. O CLI `nm` só monta o payload e chama `add_key`. Pedido da S20FE_re em 2026-11-01:
um `nomount.ko` carregável por `insmod` na Image v4.11 **já gravada**, sem gravar kernel novo.

## Como gerar

```sh
JOBS=6 tools/repro-release.sh v4.11 clean   # out/ = a release v4.11, byte a byte
tools/build-nomount.sh v4.11                # nomount.ko + nm em build/r8q/nomount/
```

- `tools/repro-release.sh` lê os carimbos `KBUILD_BUILD_USER/HOST/VERSION/TIMESTAMP` da string
  `Linux version` da Image no zip da release, compila **sem empacotar** (não manda zip para a
  raiz nem para o SD), compara a Image com a do zip (`cmp -l`) e salva `Module.symvers`,
  `vmlinux`, `.config` e `image-cmp.txt` em `build/r8q/<versão>/`. Com `clean`, apaga o `out/`
  antes, e o ccache roda com `CCACHE_RECACHE=1` (recompila tudo, nada vem do cache, por causa
  da suspeita de RAM do host). Tem de rodar no checkout principal: com `O=` o kbuild grava
  caminhos absolutos (`__FILE__`), e a comparação byte a byte depende disso.
- `tools/build-nomount.sh` clona o nomount em `tmp/nomount-src` (tag `v2.2.0` = `bf1847f`),
  aplica `tools/nomount-patches/*.patch` (hoje nenhum), compila como **módulo externo**
  (`M=`, `CONFIG_NOMOUNT=m`, sem symlink em `fs/` e sem mexer no fonte do kernel), gera o `nm`
  com o clang do NDK 26.1 e confere os CRCs de `__versions` do `.ko` contra o
  `Module.symvers` salvo.

## Resultado (2026-11-01)

- **A v2.2.0 compila na 4.19 sem patch e sem warning** (o `gcc-wrapper.py` faria warning
  virar erro). Ela usa só API exportada: 60 símbolos importados, nenhum `undefined!`.
- **Image reproduzida × Image do zip v4.11:** mesmo tamanho (55 654 412 B), 27 bytes
  diferentes, nenhum de código:
  - 20 bytes no offset 45 262 977: o GNU build-id (nota `NT_GNU_BUILD_ID`);
  - 7 bytes perto do offset 53 256 300: a data do `g_wlan_driver_version` do qcacld
    (`2026-10-24T17:38:25Z` na release, a data do build na reprodução).
- **CRCs:** os 60 símbolos importados pelo `nomount.ko` batem com o `Module.symvers` da
  v4.11 reproduzida. O vermagic e o `module_layout` (`0x185d1607`) são iguais aos do
  `usbip-core.ko` do companion v4.11.1, que já carrega no S20.
- **Assinatura:** `CONFIG_MODULE_SIG` não está ligado nesta config, então o `.ko` não precisa
  ser assinado.
- **`nm`:** estático, freestanding (syscalls e `_start` próprios), 7 KB depois do strip. O
  teste de fumaça no host passou pelo binfmt `qemu-aarch64` (registrado com
  `tonistiigi/binfmt --install arm64`): o `nm` sem argumentos imprime o guia de uso, e o
  `nm rule list` sai com 1 porque o kernel do host não tem o tipo de chave `nomount`.
- **`modinfo`:** `version: 22 (50)`. O `22` é o `NOMOUNT_BASE_VERSION`, e o `(50)` é a
  contagem de commits do clone, que o Makefile do nomount anexa.

## Cuidados

O `insmod` no aparelho fica com quem pediu, com aprovação do usuário. O módulo mexe no VFS,
e um erro nele pode derrubar o kernel. O módulo **não** entra no companion nem carrega no
boot enquanto o teste manual não passar.

## Validação no aparelho (2026-11-01)

A S20FE_re testou o módulo no S20 com a v4.11 e o teste passou. O `insmod` carregou
o módulo (`Key type nomount registered`) e o `nm version` respondeu 22 (50).
Redirecionamento, injeção, whiteout e isolamento do UID 2000 funcionaram, e o
`nm clear all` desfez tudo. Não houve Oops nem reboot. O módulo ficou carregado, sem
`rmmod`. Detalhes em `~/Android/S20FE_re/docs/findings/2026-11-01-nomount.md`.
Ele continua fora do companion até alguém pedir para carregá-lo no boot.
