#!/bin/bash
# V2PROXY TUNNEL MANAGER v2.1
# Author: Arash Mohebbati | GRE4, GRE6 | Ubuntu Only

CONFIG_FILE="tunnels.conf"
SYSTEMD_SERVICE="/etc/systemd/system/v2proxy-tunnel.service"

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"

banner() {
  clear
  echo -e "${GREEN}"
  echo "░██    ░██  ░██████  ░█████████  ░█████████    ░██████   ░██    ░██ ░██     ░██ "
  echo "░██    ░██ ░██   ░██ ░██     ░██ ░██     ░██  ░██   ░██   ░██  ░██   ░██   ░██  "
  echo "░██    ░██       ░██ ░██     ░██ ░██     ░██ ░██     ░██   ░██░██     ░██ ░██   "
  echo "░██    ░██   ░█████  ░█████████  ░█████████  ░██     ░██    ░███       ░████    "
  echo " ░██  ░██   ░██      ░██         ░██   ░██   ░██     ░██   ░██░██       ░██     "
  echo "  ░██░██   ░██       ░██         ░██    ░██   ░██   ░██   ░██  ░██      ░██     "
  echo "   ░███    ░████████ ░██         ░██     ░██   ░██████   ░██    ░██     ░██     "
  echo "                    		    												"
  echo -e "${YELLOW}GitHub:${NC} https://github.com/arashmohebbati"
  echo -e "${YELLOW}Telegram:${NC} https://t.me/v2proxy"
  echo -e "${GREEN}+=============================================================+${NC}"
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
  fi
}

save_systemd() {
cat > $SYSTEMD_SERVICE <<EOF
[Unit]
Description=V2PROXY TUNNEL Auto-Start
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash $PWD/$0 --autostart
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable v2proxy-tunnel.service
  echo -e "${GREEN}[OK] Systemd service installed and enabled.${NC}"
}

generate_name() {
  local TYPE=$1
  local SRV=$2
  local COUNT=$(grep "^${TYPE}.*_srv${SRV}" "$CONFIG_FILE" | wc -l)
  case $TYPE in
    GRE4) echo "gre$((COUNT+1))_srv${SRV}" ;;
    GRE6) echo "GRE6Tun$((COUNT+1))_srv${SRV}" ;;
  esac
}

get_ip_range() {
  local TYPE=$1
  local SRV=$2
  case $TYPE in
    GRE4)
      BASE=$((SRV*10))
      COUNT=$(grep "^GRE4.*_srv${SRV}" "$CONFIG_FILE" | wc -l)
      echo "172.100.${BASE}.$((COUNT+2))"
      ;;
    GRE6)
      BASE=$((SRV*10+55))
      COUNT=$(grep "^GRE6.*_srv${SRV}" "$CONFIG_FILE" | wc -l)
      echo "192.168.${BASE}.$((COUNT+2))"
      ;;
  esac
}

mikrotik_help() {
  NAME=$1; LOCAL=$2; REMOTE=$3; MTU=$4; TUN_IP=$5
  echo -e "\n${YELLOW}--- MikroTik Config Example ---${NC}"
  if [[ $NAME == gre* ]]; then
    echo "/interface gre add name=$NAME local-address=$LOCAL remote-address=$REMOTE mtu=$MTU"
    echo "/ip address add address=${TUN_IP%.*}.1/30 interface=$NAME"
    echo "/ip firewall nat add chain=srcnat action=masquerade"
    echo "/ip firewall nat add chain=dstnat protocol=tcp dst-port=!8291 action=dst-nat to-addresses=$TUN_IP"
  else
    echo "/interface gre6 add name=$NAME local=$LOCAL remote=$REMOTE mtu=$MTU"
    echo "/ip address add address=${TUN_IP%.*}.1/30 interface=$NAME"
    echo "/ip firewall nat add chain=srcnat action=masquerade"
    echo "/ip firewall nat add chain=dstnat protocol=tcp dst-port=!8291 action=dst-nat to-addresses=$TUN_IP"
  fi
}

autostart() {
  [ ! -f "$CONFIG_FILE" ] && exit 0
  while IFS="|" read -r NAME TYPE LOCAL REMOTE MTU IPADDR; do
    case $TYPE in
      GRE4)
        ip tunnel add $NAME mode gre local $REMOTE remote $LOCAL ttl 255
        ip link set $NAME mtu $MTU up
        ip addr add $IPADDR/30 dev $NAME
        nohup ping -c 5 ${IPADDR%.*}.1 >/dev/null 2>&1 &
        ;;
      GRE6)
        ip -6 tunnel add $NAME mode ip6gre local $REMOTE remote $LOCAL
        ip link set $NAME mtu $MTU up
        ip addr add $IPADDR/30 dev $NAME
        nohup ping -c 5 ${IPADDR%.*}.1 >/dev/null 2>&1 &
        ;;
    esac
  done < $CONFIG_FILE
}

create_tunnel() {
  local TYPE=$1
  while true; do
    echo -e "${YELLOW}Select Server:${NC}"
    echo "1) Server 1"
    echo "2) Server 2"
    echo "3) Server 3"
    echo "4) Server 4"
    echo "5) Server 5"
    echo "0) Back"
    read -p "Select: " SRV
    [[ "$SRV" == "0" ]] && return
    [[ "$SRV" =~ ^[1-5]$ ]] && break
  done

  NAME=$(generate_name $TYPE $SRV)
  TUN_IP=$(get_ip_range $TYPE $SRV)

  if [ "$TYPE" == "GRE4" ]; then
    echo -e "${YELLOW}IPv4 IRAN:${NC}"; read LOCAL
    echo -e "${YELLOW}IPv4 KHAREJ:${NC}"; read REMOTE
    DEFAULT_MTU=1420
  elif [ "$TYPE" == "GRE6" ]; then
    echo -e "${YELLOW}IPv6 IRAN:${NC}"; read LOCAL
    echo -e "${YELLOW}IPv6 KHAREJ:${NC}"; read REMOTE
    DEFAULT_MTU=1400
  fi

  echo -e "${YELLOW}MTU (default $DEFAULT_MTU):${NC}"; read MTU
  [ -z "$MTU" ] && MTU=$DEFAULT_MTU

  case $TYPE in
    GRE4)
      ip tunnel add $NAME mode gre local $REMOTE remote $LOCAL ttl 255
      ip link set $NAME mtu $MTU up
      ip addr add $TUN_IP/30 dev $NAME
      nohup ping ${TUN_IP%.*}.1 &
      ;;
    GRE6)
      ip -6 tunnel add $NAME mode ip6gre local $REMOTE remote $LOCAL
      ip link set $NAME mtu $MTU up
      ip addr add $TUN_IP/30 dev $NAME
      nohup ping ${TUN_IP%.*}.1 &
      ;;
  esac

  echo "$NAME|$TYPE|$LOCAL|$REMOTE|$MTU|$TUN_IP" >> $CONFIG_FILE
  echo -e "${GREEN}[OK] Tunnel $NAME created.${NC}"
  mikrotik_help $NAME $LOCAL $REMOTE $MTU $TUN_IP
}

list_tunnels() {
  echo -e "${YELLOW}Active tunnels:${NC}"
  i=1
  mapfile -t TUN_LIST < <((ip tunnel show; ip -6 tunnel show) | grep -E "_srv[0-9]+")
  for t in "${TUN_LIST[@]}"; do
    echo "$i) ${t%%:*}"
    ((i++))
  done
}

delete_tunnel() {
  list_tunnels
  echo -e "${YELLOW}Enter Tunnel Number to delete:${NC}"
  read NUM
  mapfile -t TUN_NAMES < <((ip tunnel show; ip -6 tunnel show) | grep -E "_srv[0-9]+" | awk '{print $1}')
  NAME=${TUN_NAMES[$((NUM-1))]}
  if [ -n "$NAME" ]; then
    ip tunnel del $NAME 2>/dev/null || ip -6 tunnel del $NAME
    sed -i "/^$NAME|/d" $CONFIG_FILE
    echo -e "${GREEN}[OK] Tunnel $NAME deleted.${NC}"
  else
    echo -e "${RED}Invalid number.${NC}"
  fi
}

menu() {
  while true; do
    banner
    echo -e "${YELLOW}1) Create GRE Tunnel (IPv4)\n2) Create GRE Tunnel (IPv6)\n3) Show Active Tunnels\n4) Delete Tunnel\nq) Exit${NC}"
    read -p "Select: " opt
    case $opt in
      1) create_tunnel GRE4 ;;
      2) create_tunnel GRE6 ;;
      3) list_tunnels ;;
      4) delete_tunnel ;;
      q) exit 0 ;;
      *) echo "Invalid option." ;;
    esac
    read -p "Press Enter to continue..."
  done
}

if [ "$1" == "--autostart" ]; then
  autostart
else
  check_root
  [ ! -f "$CONFIG_FILE" ] && touch $CONFIG_FILE
  save_systemd
  menu
fi
