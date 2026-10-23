#!/bin/bash
# Descarga mainline y la serie for-upstream de sm8350-mainline (via git). Idempotente.
set -euo pipefail
P=/srv/oneplus9pro-pmos
mkdir -p $P/src $P/patches
cd $P/src
if [ ! -d sm8350-fork/.git ]; then
  git init -q sm8350-fork
  git -C sm8350-fork fetch -q --depth=8 https://gitlab.com/sm8350-mainline/linux.git for-upstream
fi
git -C sm8350-fork format-patch -q -7 FETCH_HEAD -o $P/patches/for-upstream/ 2>/dev/null || git -C sm8350-fork format-patch -q -7 $(git -C sm8350-fork rev-parse FETCH_HEAD) -o $P/patches/for-upstream/
ls $P/patches/for-upstream/
if [ ! -d linux/.git ]; then
  echo "== clonando mainline ($(date +%T))"
  git clone -q --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
fi
cd linux && git log -1 --format="%h %cd %s" --date=short && make -s kernelversion
echo FETCH-DONE
