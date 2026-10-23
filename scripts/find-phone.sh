#!/bin/bash
# Busca el móvil en la LAN (por defecto 192.168.1.0/24) comparando la clave de host SSH con la conocida.
# Uso: find-phone.sh [prefijo]   -> imprime la IP encontrada
NET=${1:-192.168.1}
KNOWN=$(ssh-keygen -F 172.16.42.1 -f $HOME/.ssh/known_hosts_phone | awk '/ssh-ed25519/{print $3}')
[ -n "$KNOWN" ] || { echo "no tengo la clave del móvil"; exit 1; }
for i in $(seq 1 254); do
  ( ip=$NET.$i
    timeout 1 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null || exit 0
    k=$(ssh-keyscan -T 2 -t ed25519 $ip 2>/dev/null | awk '{print $3}')
    [ "$k" = "$KNOWN" ] && echo "$ip"
  ) &
  (( i % 64 == 0 )) && wait
done
wait
