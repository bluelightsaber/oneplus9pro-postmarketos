#!/bin/bash
# Aplica la serie for-upstream sobre mainline, parche a parche, y registra el resultado.
set -uo pipefail
P=/srv/oneplus9pro-pmos; cd $P/src/linux
git config user.name >/dev/null || git config user.name "Claude (asistente)"
git config user.email >/dev/null || git config user.email "noreply@anthropic.com"
git checkout -q -B lemonadep-7.3
for p in $P/patches/for-upstream/*.patch; do
  n=$(basename $p)
  if git am -q --3way "$p" 2>/tmp/am.err; then echo "OK      $n"
  elif git apply -R --check "$p" 2>/dev/null; then git am --abort 2>/dev/null; echo "YA-UPSTR $n"
  else git am --abort 2>/dev/null; echo "CONFLICT $n: $(head -2 /tmp/am.err | tr "\n" " ")"; fi
done
git log --oneline -8
echo APPLY-DONE
