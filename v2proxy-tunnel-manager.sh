#!/bin/bash
# V2PROXY TUNNEL MANAGER v2.0
# Author: Arash Mohebbati | GRE4, GRE6, 6to4+GRE | Ubuntu Only

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
  echo -e "${YELLOW}💻 GitHub:${NC} https://github.com/arashmohebbati"
  echo -e "${YELLOW}🚀 Telegram:${NC} https://t.me/v2proxy"
  echo -e "${GREEN}+===============================================================================+${NC}"
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
      6TO4GRE)
        if [[ $NAME == 6to4tun* ]]; then
          ip tunnel add $NAME mode sit remote $REMOTE local $LOCAL
          ip -6 addr add $IPADDR/64 dev $NAME
          ip link set $NAME mtu $MTU up
        else
          ip -6 tunnel add $NAME mode ip6gre local $LOCAL remote $REMOTE
          ip addr add $IPADDR/30 dev $NAME
          ip link set $NAME mtu $MTU up
        fi
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
    echo "6) Server 6"
    echo "7) Server 7"
    echo "8) Server 8"
    echo "9) Server 9"
    echo "10) Server 10"
    echo "11) Server 11"
    echo "12) Server 12"
    echo "13) Server 13"
    echo "14) Server 14"
    echo "15) Server 15"
    echo "16) Server 16"
    echo "17) Server 17"
    echo "18) Server 18"
    echo "19) Server 19"
    echo "20) Server 20"
    echo "0) Back"
    read -p "Select: " SRV
    [[ "$SRV" == "0" ]] && return
    [[ "$SRV" =~ ^([1-9]|1[0-9]|20)$ ]] && break
  done

  NAME=$(generate_name $TYPE $SRV)
  TUN_IP=$(get_ip_range $TYPE $SRV)

  if [ "$TYPE" == "GRE4" ]; then
    echo -e "${YELLOW}IPv4 IRAN (MikroTik):${NC}"; read LOCAL
    echo -e "${YELLOW}IPv4 KHAREJ (This Server):${NC}"; read REMOTE
    DEFAULT_MTU=1420
  elif [ "$TYPE" == "GRE6" ]; then
    echo -e "${YELLOW}IPv6 IRAN (MikroTik):${NC}"; read LOCAL
    echo -e "${YELLOW}IPv6 KHAREJ (This Server):${NC}"; read REMOTE
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

create_tunnel_six_to_four_gre() {
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

  echo -e "${YELLOW}IPv4 IRAN (MikroTik):${NC}"; read IRAN_IPv4
  echo -e "${YELLOW}IPv4 KHAREJ (This Server):${NC}"; read KHAREJ_IPv4

  local SUFFIX=("e1f" "e2f" "e3f" "e4f" "e5f")
  local BASE_IP=("100.100.10" "100.100.20" "100.100.30" "100.100.40" "100.100.50")

  local i=$SRV
  local SIXTO4="6to4tun_Remote${i}"
  local GRE6="GRE6Tun_Remote${i}"
  local IPV6_LOCAL="fdc2:58d9:3185:${SUFFIX[$((i-1))]}::2"   # خارج
  local IPV6_REMOTE="fdc2:58d9:3185:${SUFFIX[$((i-1))]}::1"  # ایران
  local GRE_IP="${BASE_IP[$((i-1))]}.1"                      # خارج
  local GRE_REMOTE="${BASE_IP[$((i-1))]}.2"                  # ایران

  echo -e "${GREEN}[+] Creating 6to4 Tunnel for Server ${i}...${NC}"
  ip tunnel add $SIXTO4 mode sit remote $IRAN_IPv4 local $KHAREJ_IPv4
  ip -6 addr add $IPV6_LOCAL/64 dev $SIXTO4
  ip link set $SIXTO4 mtu 1420
  ip link set $SIXTO4 up

  echo -e "${GREEN}[+] Creating GRE over 6to4 for Server ${i}...${NC}"
  ip -6 tunnel add $GRE6 mode ip6gre remote $IPV6_REMOTE local $IPV6_LOCAL
  ip addr add $GRE_IP/30 dev $GRE6
  ip link set $GRE6 mtu 1436
  ip link set $GRE6 up
  nohup ping $GRE_REMOTE >/dev/null 2>&1 &

  echo "$SIXTO4|6TO4GRE|$KHAREJ_IPv4|$IRAN_IPv4|1420|$IPV6_LOCAL" >> $CONFIG_FILE
  echo "$GRE6|6TO4GRE|$IPV6_LOCAL|$IPV6_REMOTE|1436|$GRE_IP" >> $CONFIG_FILE
  echo -e "${GREEN}[OK] 6to4 + GRE Tunnel for Server ${i} created.${NC}"

  echo -e "\n${YELLOW}--- MikroTik Config Example (Server $i) ---${NC}"
  echo "/interface 6to4 add name=$SIXTO4 local-address=$IRAN_IPv4 remote-address=$KHAREJ_IPv4 mtu=1420"
  echo "/ipv6 address add address=${IPV6_REMOTE}/64 interface=$SIXTO4"
  echo "/interface gre6 add name=$GRE6 local-address=$IPV6_REMOTE remote-address=$IPV6_LOCAL mtu=1436"
  echo "/ip address add address=${GRE_REMOTE}/30 interface=$GRE6"
  echo "/ip firewall nat add chain=srcnat action=masquerade"
  echo "/ip firewall nat add chain=dstnat protocol=tcp dst-port=!8291 action=dst-nat to-addresses=$GRE_IP"
  echo -e "${GREEN}+----------------------------------------------------------+${NC}\n"
}

list_tunnels() {
  echo -e "${YELLOW}Active tunnels:${NC}"
  i=1
  mapfile -t TUN_LIST < <((ip tunnel show; ip -6 tunnel show) | grep -E "_srv[0-9]+|6to4tun_|GRE6Tun_")
  for t in "${TUN_LIST[@]}"; do
    echo "$i) ${t%%:*}"
    ((i++))
  done
}

delete_tunnel() {
  list_tunnels
  echo -e "${YELLOW}Enter Tunnel Number to delete:${NC}"
  read NUM
  mapfile -t TUN_NAMES < <((ip tunnel show; ip -6 tunnel show) | grep -E "_srv[0-9]+|6to4tun_|GRE6Tun_" | awk '{print $1}')
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
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║      V2PROXY TUNNEL MANAGER v2.0       ║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║ 1) ➕ GRE Tunnel (IPv4)                ║${NC}"
    echo -e "${YELLOW}║ 2) ➕ GRE Tunnel (IPv6)                ║${NC}"
    echo -e "${YELLOW}║ 3) 🔄 6to4 + GRE Local                 ║${NC}"
    echo -e "${YELLOW}║ 4) 🛡️  IPIP Tunnel (Coming soon)        ║${NC}"
    echo -e "${YELLOW}║ 5) 🔗 WireGuard (Coming soon)          ║${NC}"
    echo -e "${YELLOW}║ 6) 📜 List Tunnels                     ║${NC}"
    echo -e "${YELLOW}║ 7) ❌ Delete Tunnel                    ║${NC}"
    echo -e "${YELLOW}║ q) 🚪 Exit                             ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    read -p "Select: " opt
    case $opt in
      1) create_tunnel GRE4 ;;
      2) create_tunnel GRE6 ;;
      3) create_tunnel_six_to_four_gre ;;
      4) echo -e "${RED}IPIP&IPIPv6 will be available soon.${NC}" ;;
      5) echo -e "${RED}WireGuard will be available soon.${NC}" ;;
      6) list_tunnels ;;
      7) delete_tunnel ;;
      q) exit 0 ;;
      *) echo -e "${RED}Invalid option.${NC}" ;;
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
