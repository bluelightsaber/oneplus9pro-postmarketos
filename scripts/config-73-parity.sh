#!/bin/bash
# Restores in build-7.3-fb/.config every option that was y/m on 6.7 and got lost (same value), except
# debug/choice/intentionally-removed ones, and adds what Docker/Tailscale/zram need. Then olddefconfig.
set -uo pipefail
export LC_ALL=C PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos/src; S=$P/linux; C=$P/build-7.3-fb/.config
SKIP="USB_ETH USB_ETH_RNDIS U_SERIAL_CONSOLE ATH11K_DEBUG ATH12K_DEBUG DMADEVICES_DEBUG DMADEVICES_VDEBUG MODULE_DEBUG REGULATOR_DEBUG SPI_DEBUG ARM64_VA_BITS_48 ARM64_PA_BITS_48 HZ_1000 INIT_STACK_NONE MODULE_FORCE_LOAD MODULE_FORCE_UNLOAD UEVENT_HELPER"
grep -E "^CONFIG_[A-Z0-9_]+=(y|m)" $P/build-6.7/.config | sort -u > /tmp/v67
grep -E "^CONFIG_[A-Z0-9_]+=(y|m)" $C | cut -d= -f1 | sort -u > /tmp/c73
ARGS=""
while IFS== read -r s v; do
  n=${s#CONFIG_}; grep -qx "$s" /tmp/c73 && continue
  case " $SKIP " in *" $n "*) continue;; esac
  grep -rqE "^\s*(menu)?config $n\s*$" $S --include="Kconfig*" || continue
  [ "$v" = y ] && ARGS="$ARGS -e $n" || ARGS="$ARGS -m $n"
done < /tmp/v67
# Docker / Tailscale / zram
for n in ZRAM ZSMALLOC CRYPTO_LZ4 CRYPTO_ZSTD TUN VETH BRIDGE BRIDGE_NETFILTER OVERLAY_FS MACVLAN IPVLAN VXLAN DUMMY \
         NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_MATCH_CONNTRACK NETFILTER_XT_MATCH_IPVS NETFILTER_XT_MARK NETFILTER_XT_MATCH_COMMENT \
         NFT_COMPAT NFT_FIB_INET NFT_FIB_IPV4 NFT_FIB_IPV6 NF_TABLES_BRIDGE IP_NF_RAW IP6_NF_RAW IP_VS NF_CONNTRACK_NETLINK; do
  ARGS="$ARGS -m $n"; done
for n in NAMESPACES NET_NS PID_NS IPC_NS UTS_NS USER_NS CGROUPS MEMCG CPUSETS CGROUP_CPUACCT CGROUP_DEVICE CGROUP_FREEZER CGROUP_PIDS CGROUP_SCHED \
         CGROUP_BPF BLK_CGROUP CFS_BANDWIDTH POSIX_MQUEUE KEYS SECCOMP SECCOMP_FILTER; do ARGS="$ARGS -e $n"; done
echo "options: $(echo $ARGS | wc -w)"
K="make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC=\"ccache aarch64-alpine-linux-musl-gcc\" O=../build-7.3-fb"
cp $C /tmp/config-73fb-before
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-fb/.config $ARGS && $K olddefconfig >/dev/null" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!" || true
grep -E "^CONFIG_[A-Z0-9_]+=(y|m)" $C | cut -d= -f1 | sort -u > /tmp/c73b
echo "still missing vs 6.7 after parity:"; comm -23 <(cut -d= -f1 /tmp/v67 | sort -u) /tmp/c73b | while read s; do n=${s#CONFIG_}; grep -rqE "^\s*(menu)?config $n\s*$" $S --include="Kconfig*" && echo -n "$n "; done; echo
grep -E "^CONFIG_(NF_TABLES|ZRAM|TUN|VETH|BRIDGE|OVERLAY_FS|USB_F_NCM|PHY_QCOM_USB_SNPS_FEMTO_V2|DRM)=" $C | tr "\n" " " || true; echo
echo PARITY-DONE
# second pass: legacy iptables tables (now behind NETFILTER_XTABLES_LEGACY / IP_NF_IPTABLES_LEGACY)
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && ./scripts/config --file ../build-7.3-fb/.config -e NETFILTER_XTABLES_LEGACY -m IP_NF_IPTABLES_LEGACY -m IP6_NF_IPTABLES_LEGACY -m IP_NF_FILTER -m IP_NF_MANGLE -m IP_NF_NAT -m IP_NF_TARGET_MASQUERADE -m IP6_NF_FILTER -m IP6_NF_MANGLE -m IP6_NF_NAT -m IP6_NF_TARGET_MASQUERADE && $K olddefconfig >/dev/null" 2>&1 | grep -vE "^\[.*\] %|NOTE:|DONE!|WARNING" || true
grep -E "^CONFIG_(IP_NF_FILTER|IP_NF_NAT|IP6_NF_NAT|NETFILTER_XTABLES_LEGACY)=" $C | tr "\n" " " || true; echo; echo PARITY2-DONE
