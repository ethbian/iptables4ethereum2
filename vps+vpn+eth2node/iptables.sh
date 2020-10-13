#!/usr/bin/env bash

#
# vps+vpn+eth2node, version: 20200913
# https://github.com/ethbian/iptables4ethereum2
#

############################# variables ###########################
# iptables path
IPT='/usr/sbin/iptables'
# log level, for 7 use "*.=debug" in the rsyslogd.conf file
LOG_LEVEL=7
# log rate limit per second
LOG_RATE_LIMIT=2

# geth ports
GETH_TCP_PORT=30303
GETH_UDP_PORT=30303
# geth per IP limit
GETH_PER_IP=3
# geth total peers (geth maxpeers/light.maxpeers options)
GETH_TOTAL=75

# beacon ports, 9000 for lighthouse, 13000tcp/12000udp for prysm
BEACON_TCP_PORT=9000
BEACON_UDP_PORT=9000
# beacon per IP limit
BEACON_PER_IP=3
# geth total peers (geth maxpeers/light.maxpeers options)
BEACON_TOTAL=50

# vpn interface
VPN_INT='tun0'
# external VPN interface
EXT_INT='venet0'
# eth node IP
ETH_IP='10.8.0.10'
# vpn network
VPN_NET='10.8.0.0/8'

# portscan traps (unused tcp services, should be forwarded by router)
# 1: ftp
PSCAN_TRAP1=21
# 2: telnet
PSCAN_TRAP2=23
# 3: samba
PSCAN_TRAP3=139
# portscan when 2 connections for the last 24 hours (86400 seconds)
PSCAN_COUNT=2
PSCAN_SECONDS=86400

###################################################################

if [ "$EUID" -ne 0 ]; then
  echo 'Script needs to executed by root or via sudo.'
  exit 1
fi

if [ ! -x "$IPT" ]; then
  echo "$IPT does not exist. Point the variable to the iptables binary."
  exit 1
fi
###################################################################

# clear the rules
$IPT -t mangle -F
$IPT -t mangle -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -F
$IPT -X

# default policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# services running locally on the vps/vpn server
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -i $VPN_INT -j ACCEPT

# nat / forwarding
$IPT -t nat -A POSTROUTING -s $VPN_NET -o $EXT_INT -j MASQUERADE
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

$IPT -A FORWARD -i $VPN_INT -j ACCEPT
$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# LOG and DROP in one chain
$IPT -t mangle -N LOG_DROP_BOGUS
$IPT -t mangle -A LOG_DROP_BOGUS -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables BOGUS " --log-level $LOG_LEVEL
$IPT -t mangle -A LOG_DROP_BOGUS -j DROP

$IPT -t mangle -N LOG_DROP_INVALID
$IPT -t mangle -A LOG_DROP_INVALID -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables INVALID " --log-level $LOG_LEVEL --log-ip-options
$IPT -t mangle -A LOG_DROP_INVALID -j DROP

$IPT -t mangle -N LOG_DROP_FRAGMENTED
$IPT -t mangle -A LOG_DROP_FRAGMENTED -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables FRAGMENTED " --log-level $LOG_LEVEL
$IPT -t mangle -A LOG_DROP_FRAGMENTED -j DROP

# well known bogus packets
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG_DROP_BOGUS

# invalid & fragmented packets
$IPT -t mangle -A PREROUTING -p tcp ! --syn -m state --state NEW -j LOG_DROP_BOGUS
$IPT -t mangle -A PREROUTING -f -j LOG_DROP_FRAGMENTED
$IPT -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j LOG_DROP_INVALID

# portscan
$IPT -A INPUT -p tcp -m recent --name portscan --rcheck --seconds $PSCAN_SECONDS --hitcount $PSCAN_COUNT -j DROP
$IPT -A INPUT -p tcp -m multiport --dport $PSCAN_TRAP1,$PSCAN_TRAP2,$PSCAN_TRAP3 -m recent --name portscan --set -j REJECT

# port forwarding
$IPT -t nat -A PREROUTING -i $EXT_INT -p tcp -m tcp --dport $GETH_TCP_PORT -j DNAT --to-destination $ETH_IP:$GETH_TCP_PORT
$IPT -t nat -A PREROUTING -i $EXT_INT -p udp -m udp --dport $GETH_UDP_PORT -j DNAT --to-destination $ETH_IP:$GETH_UDP_PORT
$IPT -t nat -A PREROUTING -i $EXT_INT -p tcp -m tcp --dport $BEACON_TCP_PORT -j DNAT --to-destination $ETH_IP:$BEACON_TCP_PORT
$IPT -t nat -A PREROUTING -i $EXT_INT -p udp -m udp --dport $BEACON_UDP_PORT -j DNAT --to-destination $ETH_IP:$BEACON_UDP_PORT

# allowing & limiting (per IP and total) geth
$IPT -t mangle -A FORWARD -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth TCP IP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_PER_IP -j DROP
$IPT -t mangle -A FORWARD -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth TCP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A FORWARD -i $EXT_INT -p tcp --dport $GETH_TCP_PORT -j ACCEPT

$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $GETH_UDP_PORT -m connlimit --connlimit-above $GETH_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth UDP IP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $GETH_UDP_PORT -m connlimit --connlimit-above $GETH_PER_IP -j DROP
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $GETH_UDP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth UDP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $GETH_UDP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A FORWARD -i $EXT_INT -p tcp --dport $GETH_UDP_PORT -j ACCEPT

# allowing & limiting (per IP and total) beacon (lighthouse, prysm and so on)
$IPT -t mangle -A FORWARD -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon TCP IP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -j DROP
$IPT -t mangle -A FORWARD -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon TCP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A FORWARD -i $EXT_INT -p tcp --dport $BEACON_TCP_PORT -j ACCEPT

$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $BEACON_UDP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon UDP IP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $BEACON_UDP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -j DROP
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $BEACON_UDP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon UDP flood " --log-level $LOG_LEVEL
$IPT -t mangle -A FORWARD -p udp -m state --state NEW --dport $BEACON_UDP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A FORWARD -i $EXT_INT -p tcp --dport $BEACON_UDP_PORT -j ACCEPT

# extra services you're running on the server (vps)
# ssh, change the defult port
$IPT -A INPUT -p tcp --dport 22 -j ACCEPT
# vpn, change the default port
$IPT -A INPUT -p tcp --dport 1194 -j ACCEPT
