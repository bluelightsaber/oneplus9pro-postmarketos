#!/bin/bash
# Configura y compila mainline (lemonadep-7.3) para el OnePlus 9 Pro dentro del chroot nativo.
# Base: config del kernel 6.7 de pmOS (sm8350), adaptada con olddefconfig. Idempotente.
set -euo pipefail
# evitar dos compilaciones a la vez en el mismo O=
exec 9>/tmp/kernel-build.lock; flock -n 9 || { echo "ya hay una compilacion en marcha"; exit 1; }
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
B=$P/src/build-7.3
pmbootstrap chroot -- apk add -q ccache flex bison bc perl openssl-dev elfutils-dev linux-headers python3 dtc gmp-dev mpc1-dev mpfr-dev >/dev/null 2>&1
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
if [ ! -f $B/.config.pmos-base ]; then
  sudo cp $P/pmbootstrap-work/cache_git/pmaports/device/archived/linux-postmarketos-qcom-sm8350/config-postmarketos-qcom-sm8350.aarch64 $B/.config
  sudo cp $B/.config $B/.config.pmos-base
fi
K="make ARCH=arm64 CROSS_COMPILE=aarch64-alpine-linux-musl- CC=\"ccache aarch64-alpine-linux-musl-gcc\" O=../build-7.3"
pmbootstrap chroot -- sh -c "cd /home/pmos/src/linux && $K olddefconfig >/dev/null && \
 ./scripts/config --file ../build-7.3/.config -d USB_ETH -d USB_ETH_RNDIS -e CGROUP_BPF -m BRIDGE_NETFILTER -e BRIDGE -e NETFILTER_ADVANCED -m NETFILTER_XT_MATCH_ADDRTYPE -m NETFILTER_XT_MATCH_CONNTRACK -m IP_VS -e CGROUP_PIDS -e MEMCG -e USER_NS -e OVERLAY_FS -e LOCALVERSION_AUTO --set-str LOCALVERSION -lemonadep && \
 $K olddefconfig >/dev/null && grep -E \"^CONFIG_(USB_ETH|CGROUP_BPF|BRIDGE_NETFILTER|QCOM_Q6V5_PAS|USB_DWC3|SCSI_UFS_QCOM|FB_SIMPLE|SYSFB_SIMPLEFB|DRM_SIMPLEDRM)=\" ../build-7.3/.config; \
 echo \"== build \$(date +%T)\"; time $K -j8 Image dtbs > ../build-7.3/build.log 2>&1; echo rc=\$?; tail -5 ../build-7.3/build.log; ls -la ../build-7.3/arch/arm64/boot/Image" 2>&1 | grep -vE "^\[.*\] %|NOTE|DONE!"
echo BUILD-DONE
