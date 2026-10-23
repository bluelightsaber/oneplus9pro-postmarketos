#!/bin/bash
# Prepara el árbol exacto del kernel 6.7 de producción (sm8350-mainline @ffb1b0db) con la config
# de pmOS, para compilar módulos adicionales compatibles con el kernel que ya está corriendo.
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
P=/srv/oneplus9pro-pmos; N=$P/pmbootstrap-work/chroot_native/home/pmos/src
COMMIT=ffb1b0db511df03829fa0c9682f2412c0db7f717
cd $P/src
if [ ! -d linux-6.7/.git ]; then
  git init -q linux-6.7
  git -C linux-6.7 fetch -q --depth 1 https://gitlab.com/sm8350-mainline/linux.git $COMMIT
  git -C linux-6.7 checkout -q FETCH_HEAD
fi
git -C linux-6.7 log -1 --format="%h %cd %s" --date=short
sudo mkdir -p $N; mountpoint -q $N || sudo mount --bind $P/src $N
mkdir -p build-6.7
cp $P/pmbootstrap-work/cache_git/pmaports/device/archived/linux-postmarketos-qcom-sm8350/config-postmarketos-qcom-sm8350.aarch64 build-6.7/.config
grep -E "^CONFIG_(MODVERSIONS|LOCALVERSION|MODULE_SIG|AUXILIARY_BUS|QCOM_PDR_HELPERS|RPMSG|QCOM_SPMI_ADC5)=" build-6.7/.config || true
echo K67-PREP-DONE
