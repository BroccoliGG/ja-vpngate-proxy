#!/usr/bin/env bash

VPNGATE_URL=http://www.vpngate.net/api/iphone/

# minimum link speed, in bps (VPNGate reports Speed in bps). 200Mbps
MIN_SPEED=${MIN_SPEED:-200000000}

# which OpenVPN protocol to accept: udp, tcp, or any
PROTO=${PROTO:-any}

function global_ip {
  curl -s inet-ip.info
}

# vpn connect func
function connect {
  while :; do
    echo start
    found=0
    while read line; do
      conf=$(echo "$line" | cut -d ',' -f 15 | tr -d '\r' | base64 -d)
      # tcp/udp is not a CSV column, it only exists inside the decoded config
      if [ "$PROTO" != "any" ] &&
         [ "$(echo "$conf" | tr -d '\r' | awk '$1=="proto"{print $2; exit}')" != "$PROTO" ]; then
        continue
      fi
      found=1
      openvpn <(echo "$conf") ;
    # CountryShort(7th) must be JP, exclude public-vpn- hosts by HostName(1st),
    # keep only servers at or above MIN_SPEED (Speed is the 5th field),
    # then sort by Score (3rd field) in descending order so the best server comes first
    done < <(curl -s $VPNGATE_URL |
      awk -F ',' -v min="$MIN_SPEED" 'NF>=15 && $7=="JP" && $1 !~ /public-vpn-/ && $5+0 >= min' |
      sort -t ',' -k3,3nr )
    echo end
    # nothing matched: wait before refetching so we do not hammer the API
    if [ "$found" -eq 0 ]; then
      echo "no server matched (proto=$PROTO, min speed=${MIN_SPEED}bps), retrying in 60s"
      sleep 60
    fi
  done
}

BEFORE_IP="$(global_ip)"

# start proxy
privoxy <(grep -v listen-address /etc/privoxy/config ; echo listen-address  0.0.0.0:8118) &

# connect vpn
connect &

# vpn check
while :; do
  sleep 5
  AFTER_IP=$(global_ip)
  result=$?
  echo "before=$BEFORE_IP after=$AFTER_IP"
  if [ $result -ne 0 ]; then
    pkill openvpn
  elif [ "$BEFORE_IP" = "$AFTER_IP" ]; then
    pkill openvpn
  else 
    sleep 55
  fi
done