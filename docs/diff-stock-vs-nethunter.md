# Diferenças de config: kernel stock vs Nethunter (r8q / S20 FE 5G)

Comparação **automática** entre o `.config` do kernel de fábrica rodando
no aparelho e o `.config` gerado pelo build local do Nethunter.

| | |
|---|---|
| **Stock** | `4.19.113-27223811` (via `/proc/config.gz` do device, por SSH) |
| **Nethunter** | `4.19.113-Nethunter_WirusMOD_r8q_v4.1` (`out/.config`, `wirus_defconfig`) |
| Opções de config no stock | 2202 habilitadas (5814 totais) |
| Opções de config no Nethunter | 2423 habilitadas (6347 totais) |
| Opções que divergem | 313 |

> Legenda: `y` embutido · `m` módulo · `—` desligado/ausente · número/string = valor literal.

## Resumo em uma frase

O Nethunter é o **mesmo kernel 4.19.113** do stock com a **segurança KNOX
desligada** (pré-requisito de root/mods), **namespaces + cgroups + módulos sem
assinatura** ligados, e **drivers de adaptador WiFi USB** (para dongle externo)
compilados. Não atualiza a versão LTS.

## ⚠️ O monitor mode NÃO aparece neste diff

O `FEATURE_MONITOR_MODE_SUPPORT` do `wlan0` interno (QCA6390) **não é uma opção
Kconfig do kernel** — é config interna do sub-build do driver
`drivers/net/wireless/qualcomm/qca6390/qcacld-3.0` (`configs/default_defconfig`),
que não vai para o `/proc/config.gz`. Por isso ele não está em nenhuma tabela
abaixo. Verificado à parte: o profile `default` habilita monitor mode nos dois
kernels; a diferença real vs. o stock é que a Samsung provavelmente compila o
driver com `FEATURE_MONITOR_MODE_SUPPORT := n`. As opções WiFi que **aparecem**
no diff abaixo (`ATH9K_HTC`, `CARL9170`, `RTL8XXXU`…) são para **dongle USB
externo**, não para o rádio interno.

## Segurança Samsung / KNOX (desligada no Nethunter)

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `CFP` | y | — |
| `CFP_JOPP` | y | — |
| `CFP_JOPP_MAGIC` | 0x00be7bad | — |
| `CFP_ROPP` | y | — |
| `CFP_ROPP_SYSREGKEY` | y | — |
| `FIVE` | y | — |
| `FIVE_CERT_USER` | "x509_five_user.der" | — |
| `FIVE_DEFAULT_HASH` | "sha1" | — |
| `FIVE_DEFAULT_HASH_SHA1` | y | — |
| `FIVE_TRUSTED_KEYRING` | y | — |
| `KDP_CRED` | y | — |
| `KDP_DMAP` | y | — |
| `KDP_NS` | y | — |
| `KNOX_NCM` | y | — |
| `PROCA` | y | — |
| `PROCA_S_OS` | y | — |
| `SECURITY_DEFEX` | y | — |
| `UH` | y | — |
| `UH_LKM_BLOCK` | y | — |
| `UH_RKP` | y | — |

## Root / namespaces / containers

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `CGROUP_DEVICE` | — | y |
| `CGROUP_NET_CLASSID` | — | y |
| `CGROUP_NET_PRIO` | — | y |
| `CGROUP_PERF` | — | y |
| `CGROUP_PIDS` | — | y |
| `IPC_NS` | — | y |
| `NET_CLS_CGROUP` | — | y |
| `PID_NS` | — | y |
| `PROC_MAGISK_HIDE_MOUNT` | — | y |
| `USER_NS` | — | y |

## Módulos carregáveis

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `MODULE_FORCE_UNLOAD` | y | — |
| `MODULE_SIG` | y | — |
| `MODULE_SIG_ALL` | y | — |
| `MODULE_SIG_FORCE` | y | — |
| `MODULE_SIG_HASH` | "sha512" | — |
| `MODULE_SIG_KEY` | "certs/signing_key.pem" | — |
| `MODULE_SIG_SHA512` | y | — |
| `SEC_DEBUG_MODULE_INFO` | y | — |

## WiFi / mac80211 / cfg80211

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `ATH10K` | — | y |
| `ATH10K_CE` | — | y |
| `ATH10K_USB` | — | y |
| `ATH6KL` | — | y |
| `ATH6KL_USB` | — | y |
| `ATH9K` | — | y |
| `ATH9K_BTCOEX_SUPPORT` | — | y |
| `ATH9K_COMMON` | — | y |
| `ATH9K_HTC` | — | y |
| `ATH9K_HW` | — | y |
| `ATH9K_PCI` | — | y |
| `ATH9K_PCOEM` | — | y |
| `ATH9K_RFKILL` | — | y |
| `ATH_COMMON` | — | y |
| `BT_HCIBTUSB_RTL` | — | y |
| `BT_RTL` | — | y |
| `CARL9170` | — | y |
| `CARL9170_LEDS` | — | y |
| `CARL9170_WPC` | — | y |
| `CFG80211_WEXT` | — | y |
| `DVB_RTL2830` | — | y |
| `DVB_RTL2832` | — | y |
| `DVB_RTL2832_SDR` | — | y |
| `MAC80211` | — | y |
| `MAC80211_HAS_RC` | — | y |
| `MAC80211_LEDS` | — | y |
| `MAC80211_MESH` | — | y |
| `MAC80211_RC_DEFAULT` | — | "minstrel_ht" |
| `MAC80211_RC_DEFAULT_MINSTREL` | — | y |
| `MAC80211_RC_MINSTREL` | — | y |
| `MAC80211_RC_MINSTREL_HT` | — | y |
| `MT7601U` | — | y |
| `MT76_CORE` | — | y |
| `MT76_LEDS` | — | y |
| `MT76_USB` | — | y |
| `MT76x0U` | — | y |
| `MT76x2U` | — | y |
| `MT76x2_COMMON` | — | y |
| `RT2500USB` | — | y |
| `RT2800USB` | — | y |
| `RT2800USB_RT33XX` | — | y |
| `RT2800USB_RT3573` | — | y |
| `RT2800USB_RT35XX` | — | y |
| `RT2800USB_RT53XX` | — | y |
| `RT2800USB_RT55XX` | — | y |
| `RT2800USB_UNKNOWN` | — | y |
| `RT2800_LIB` | — | y |
| `RT2X00` | — | y |
| `RT2X00_LIB` | — | y |
| `RT2X00_LIB_CRYPTO` | — | y |
| `RT2X00_LIB_FIRMWARE` | — | y |
| `RT2X00_LIB_LEDS` | — | y |
| `RT2X00_LIB_USB` | — | y |
| `RTL8187` | — | y |
| `RTL8187_LEDS` | — | y |
| `RTL8188EU` | — | y |
| `RTL8192CU` | — | y |
| `RTL8192C_COMMON` | — | y |
| `RTL8822BU` | — | y |
| `RTL8XXXU` | — | y |
| `RTL8XXXU_UNTESTED` | — | y |
| `RTLWIFI` | — | y |
| `RTLWIFI_USB` | — | y |
| `RTL_CARDS` | — | y |
| `SECURITY_PATH` | — | y |
| `USB_NET_RNDIS_WLAN` | — | y |
| `ZD1211RW` | — | y |

## USB gadget / HID / networking

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `BRIDGE_NETFILTER` | — | y |
| `IP_NF_TARGET_TTL` | — | y |
| `NETFILTER_XT_MATCH_ADDRTYPE` | — | y |
| `NETFILTER_XT_MATCH_IPVS` | — | y |
| `NETFILTER_XT_TARGET_HL` | — | y |
| `USB_CONFIGFS_ECM` | — | y |
| `USB_CONFIGFS_ECM_SUBSET` | — | y |
| `USB_CONFIGFS_EEM` | — | y |
| `USB_CONFIGFS_OBEX` | — | y |
| `USB_CONFIGFS_SERIAL` | — | y |
| `USB_NET_RNDIS_HOST` | — | y |

## SELinux / auditoria

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `INTEGRITY_AUDIT` | y | — |
| `NFS_V4_SECURITY_LABEL` | — | y |
| `SECURITY_APPARMOR` | — | y |
| `SECURITY_APPARMOR_BOOTPARAM_VALUE` | — | 1 |
| `SECURITY_APPARMOR_HASH` | — | y |
| `SECURITY_APPARMOR_HASH_DEFAULT` | — | y |
| `SECURITY_SELINUX_ALWAYS_ENFORCE` | — | y |

## Versão / identificação do kernel

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `LOCALVERSION_AUTO` | y | — |

## Outras diferenças (189)

Sub-opções variadas (drivers, debug, tuning) que não caem nas categorias acima.

<details><summary>Expandir lista completa</summary>

| Opção | Stock | Nethunter |
|---|:---:|:---:|
| `88XXAU` | — | y |
| `BLK_DEV_LOOP_MIN_COUNT` | 48 | 32 |
| `BLK_DEV_THROTTLING` | — | y |
| `BOEFFLA_WL_BLOCKER` | — | y |
| `BTRFS_FS` | — | y |
| `BTRFS_FS_POSIX_ACL` | — | y |
| `BT_BCM` | — | y |
| `BT_HCIBCM203X` | — | y |
| `BT_HCIBFUSB` | — | y |
| `BT_HCIBPA10X` | — | y |
| `BT_HCIBTUSB` | — | y |
| `BT_HCIBTUSB_BCM` | — | y |
| `BT_HCIUART` | — | y |
| `BT_HCIUART_H4` | — | y |
| `BT_HCIVHCI` | — | y |
| `BT_INTEL` | — | y |
| `BT_RFCOMM` | — | y |
| `BT_RFCOMM_TTY` | — | y |
| `BUILD_ARM64_KERNEL_COMPRESSION_GZIP` | — | y |
| `BUILD_ARM64_UNCOMPRESSED_KERNEL` | y | — |
| `CAN` | — | y |
| `CAN_8DEV_USB` | — | y |
| `CAN_BCM` | — | y |
| `CAN_CALC_BITTIMING` | — | y |
| `CAN_CAN327` | — | m |
| `CAN_CC770` | — | y |
| `CAN_C_CAN` | — | y |
| `CAN_DEV` | — | y |
| `CAN_EMS_USB` | — | y |
| `CAN_ESD_USB2` | — | y |
| `CAN_GRCAN` | — | y |
| `CAN_GS_USB` | — | y |
| `CAN_GW` | — | y |
| `CAN_HI311X` | — | y |
| `CAN_IFI_CANFD` | — | y |
| `CAN_ISOTP` | — | y |
| `CAN_KVASER_USB` | — | y |
| `CAN_MCBA_USB` | — | y |
| `CAN_MCP251X` | — | y |
| `CAN_MCP25XXFD` | — | y |
| `CAN_M_CAN` | — | y |
| `CAN_PEAK_PCIEFD` | — | y |
| `CAN_PEAK_USB` | — | y |
| `CAN_RAW` | — | y |
| `CAN_SJA1000` | — | y |
| `CAN_SLCAN` | — | y |
| `CAN_SOFTING` | — | y |
| `CAN_UCAN` | — | y |
| `CAN_VCAN` | — | y |
| `CAN_VXCAN` | — | y |
| `CIFS` | — | y |
| `CIFS_ALLOW_INSECURE_LEGACY` | — | y |
| `CIFS_DFS_UPCALL` | — | y |
| `CIFS_POSIX` | — | y |
| `CIFS_UPCALL` | — | y |
| `CIFS_WEAK_PW_HASH` | — | y |
| `CIFS_XATTR` | — | y |
| `CRC_ITU_T` | — | y |
| `CRYPTO_LIB_POLY1305_RSIZE` | — | 9 |
| `CXD2880_SPI_DRV` | — | y |
| `DEV_COREDUMP` | — | y |
| `DM_BIO_PRISON` | — | y |
| `DM_PERSISTENT_DATA` | — | y |
| `DM_THIN_PROVISIONING` | — | y |
| `DNS_RESOLVER` | — | y |
| `DVB_CORE` | — | y |
| `DVB_MAX_ADAPTERS` | — | 16 |
| `DVB_NET` | — | y |
| `DVB_SI2168` | — | y |
| `DVB_ZD1301_DEMOD` | — | y |
| `EEPROM_93CX6` | — | y |
| `ENCRYPTED_KEYS` | — | y |
| `GATOR` | m | y |
| `GRACE_PERIOD` | — | y |
| `INPUT_MOUSE` | — | y |
| `INTEGRITY` | y | — |
| `INTEGRITY_ASYMMETRIC_KEYS` | y | — |
| `INTEGRITY_SIGNATURE` | y | — |
| `INTEGRITY_TRUSTED_KEYRING` | y | — |
| `IPVLAN` | — | y |
| `IP_VS` | — | y |
| `IP_VS_MH_TAB_INDEX` | — | 12 |
| `IP_VS_NFCT` | — | y |
| `IP_VS_PROTO_TCP` | — | y |
| `IP_VS_PROTO_UDP` | — | y |
| `IP_VS_RR` | — | y |
| `IP_VS_SH_TAB_BITS` | — | 8 |
| `IP_VS_TAB_BITS` | — | 12 |
| `ISO9660_FS` | — | y |
| `JOLIET` | — | y |
| `KPERFMON` | y | — |
| `LOCKD` | — | y |
| `LOCKD_V4` | — | y |
| `MACVLAN` | — | y |
| `MEDIA_DIGITAL_TV_SUPPORT` | — | y |
| `MEDIA_SDR_SUPPORT` | — | y |
| `MEDIA_SUBDRV_AUTOSELECT` | y | — |
| `MEDIA_TUNER_MSI001` | — | y |
| `MEDIA_TUNER_TDA18250` | — | m |
| `MMC_TEST` | m | y |
| `MOUSE_PS2` | — | y |
| `MOUSE_PS2_ALPS` | — | y |
| `MOUSE_PS2_BYD` | — | y |
| `MOUSE_PS2_CYPRESS` | — | y |
| `MOUSE_PS2_FOCALTECH` | — | y |
| `MOUSE_PS2_LOGIPS2PP` | — | y |
| `MOUSE_PS2_SMBUS` | — | y |
| `MOUSE_PS2_SYNAPTICS` | — | y |
| `MOUSE_PS2_SYNAPTICS_SMBUS` | — | y |
| `MOUSE_PS2_TRACKPOINT` | — | y |
| `MOUSE_SYNAPTICS_USB` | — | y |
| `NETLINK_DIAG` | — | y |
| `NET_DEVLINK` | — | y |
| `NET_EMATCH_CANID` | — | y |
| `NET_L3_MASTER_DEV` | — | y |
| `NFC_FEATURE_SN100U` | y | — |
| `NFC_PN547` | y | — |
| `NFC_PN547_ESE_SUPPORT` | y | — |
| `NFSD` | — | y |
| `NFSD_V3` | — | y |
| `NFSD_V4` | — | y |
| `NFS_COMMON` | — | y |
| `NFS_FS` | — | y |
| `NFS_USE_KERNEL_DNS` | — | y |
| `NFS_V2` | — | y |
| `NFS_V3` | — | y |
| `NFS_V4` | — | y |
| `NFS_V4_1` | — | y |
| `NFS_V4_1_IMPLEMENTATION_ID_DOMAIN` | — | "kernel.org" |
| `NFS_V4_2` | — | y |
| `NTFS_DEBUG` | y | — |
| `NTFS_RW` | — | y |
| `PNFS_BLOCK` | — | y |
| `PNFS_FILE_LAYOUT` | — | y |
| `PNFS_FLEXFILE_LAYOUT` | — | m |
| `POSIX_MQUEUE` | — | y |
| `POSIX_MQUEUE_SYSCTL` | — | y |
| `RAID6_PQ` | — | y |
| `REALTEK_AUTOPM` | — | y |
| `RPCSEC_GSS_KRB5` | — | y |
| `RT73USB` | — | y |
| `SAMSUNG_NFC` | y | — |
| `SECURITYFS` | — | y |
| `SIGNATURE` | y | — |
| `SUNRPC` | — | y |
| `SUNRPC_BACKCHANNEL` | — | y |
| `SUNRPC_GSS` | — | y |
| `SYSVIPC` | — | y |
| `SYSVIPC_COMPAT` | — | y |
| `SYSVIPC_SYSCTL` | — | y |
| `TCP_CONG_HTCP` | m | y |
| `TCP_CONG_WESTWOOD` | m | y |
| `TZIC` | — | y |
| `TZIC_USE_QSEECOM` | — | y |
| `UDF_FS` | — | y |
| `USB_ACM` | — | y |
| `USB_AIRSPY` | — | y |
| `USB_EZUSB_FX2` | — | y |
| `USB_F_ECM` | — | y |
| `USB_F_EEM` | — | y |
| `USB_F_OBEX` | — | y |
| `USB_F_SERIAL` | — | y |
| `USB_F_SUBSET` | — | y |
| `USB_GSPCA` | m | y |
| `USB_HACKRF` | — | y |
| `USB_IPHETH` | — | y |
| `USB_MSI2500` | — | y |
| `USB_SERIAL_CH341` | — | y |
| `USB_SERIAL_CONSOLE` | — | y |
| `USB_SERIAL_GENERIC` | — | y |
| `USB_SERIAL_KEYSPAN` | — | y |
| `USB_SERIAL_KEYSPAN_PDA` | — | y |
| `USB_SERIAL_MOS7720` | — | y |
| `USB_SERIAL_MOS7840` | — | y |
| `USB_STORAGE_REALTEK` | — | y |
| `USB_ZD1201` | — | y |
| `VETH` | — | y |
| `VSOCKETS` | — | y |
| `VSOCKETS_DIAG` | — | y |
| `VXLAN` | — | y |
| `WANT_DEV_COREDUMP` | — | y |
| `WIREGUARD` | — | y |
| `XOR_BLOCKS` | — | y |
| `XXHASH` | — | y |
| `ZISOFS` | — | y |
| `ZPOOL` | — | y |
| `ZSTD_COMPRESS` | — | y |
| `ZSTD_DECOMPRESS` | — | y |
| `hlcan` | — | y |

</details>

