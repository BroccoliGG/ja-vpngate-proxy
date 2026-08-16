#!/usr/bin/env bash

VPNGATE_URL=http://www.vpngate.net/api/iphone/

# minimum link speed, in bps (VPNGate reports Speed in bps). 200Mbps
MIN_SPEED=${MIN_SPEED:-200000000}

function global_ip {
  curl -s inet-ip.info
}

# vpn connect func
function connect {
  while :; do
    echo start
    found=0
    while read line; do
      found=1
      line=$(echo $line | cut -d ',' -f 15)
      line=$(echo $line | tr -d '\r')
      openvpn <(echo "$line" | base64 -d) ;
    # keep only servers faster than MIN_SPEED (Speed is the 5th field),
    # then sort by Score (3rd field) in descending order so the best server comes first
    done < <(curl -s $VPNGATE_URL | grep ,Japan,JP, | grep -v public-vpn- | awk -F ',' -v min="$MIN_SPEED" '$5+0 > min' | sort -t ',' -k3,3nr )
    echo end
    # nothing matched: wait before refetching so we do not hammer the API
    if [ "$found" -eq 0 ]; then
      echo "no server faster than ${MIN_SPEED}bps, retrying in 60s"
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