#!/bin/bash

#
# version: 20200903
# https://github.com/ethbian/iptables4ethereum2
#

############################# variables ###########################
# iptables path
IPT='/usr/sbin/iptables'
# log level, for 7 use "*.=debug" in the rsyslogd.conf file
LOG_LEVEL=7
# log rate limit per second
LOG_RATE_LIMIT=2

# geth port
GETH_TCP_PORT=30303
# geth per IP limit
GETH_PER_IP=3
# geth total peers (geth maxpeers/light.maxpeers options)
GETH_TOTAL=75

# beacon tcp port, 9000 for lighthouse, 13000 for prysm
BEACON_TCP_PORT=9000
# beacon per IP limit
BEACON_PER_IP=3
# geth total peers (geth maxpeers/light.maxpeers options)
BEACON_TOTAL=50

# ssh port
SSH_TCP_PORT=22
# ssh per IP limit
SSH_PER_IP=3
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
$IPT -F
$IPT -X

# default policies
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# LOG and DROP in one chain
$IPT -t mangle -N LOG_DROP_BOGUS
$IPT -t mangle -A LOG_DROP_BOGUS -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables BOGUS " --log-level $LOG_LEVEL
$IPT -t mangle -A LOG_DROP_BOGUS -j DROP

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
$IPT -t mangle -A PREROUTING -p tcp ! --syn -m state --state NEW -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables NEW without SYN " --log-level $LOG_LEVEL
$IPT -t mangle -A PREROUTING -p tcp ! --syn -m state --state NEW -j DROP
$IPT -t mangle -A PREROUTING -f -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables FRAGMENTED " --log-level $LOG_LEVEL
$IPT -t mangle -A PREROUTING -f -j DROP
$IPT -t mangle -A PREROUTING -m conntrack --ctstate INVALID -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "iptables INVALID packet " --log-level $LOG_LEVEL --log-ip-options
$IPT -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP

# loopback & already established are fine
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# allowing ssh (LAN access, not forwared on router; use random port number, fail2ban, vpn...)
$IPT -A INPUT -p tcp --syn --dport $SSH_TCP_PORT -m connlimit --connlimit-above $SSH_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "ssh IP flood " --log-level $LOG_LEVEL
$IPT -A INPUT -p tcp --syn --dport $SSH_TCP_PORT -m connlimit --connlimit-above $SSH_PER_IP -j DROP
$IPT -A INPUT -p tcp --dport $SSH_TCP_PORT -j ACCEPT

# allowing & limiting geth
# per IP
$IPT -A INPUT -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth IP flood " --log-level $LOG_LEVEL
$IPT -A INPUT -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_PER_IP -j DROP
# total connections
$IPT -A INPUT -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "geth FLOOD " --log-level $LOG_LEVEL
$IPT -A INPUT -p tcp --syn --dport $GETH_TCP_PORT -m connlimit --connlimit-above $GETH_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A INPUT -p tcp --dport $GETH_TCP_PORT -j ACCEPT

# allowing & limiting beacon (lighthouse, prysm and so on)
# per IP
$IPT -A INPUT -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon IP flood " --log-level $LOG_LEVEL
$IPT -A INPUT -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_PER_IP -j DROP
# total connections
$IPT -A INPUT -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -m limit --limit $LOG_RATE_LIMIT/second -j LOG --log-prefix "beacon FLOOD " --log-level $LOG_LEVEL
$IPT -A INPUT -p tcp --syn --dport $BEACON_TCP_PORT -m connlimit --connlimit-above $BEACON_TOTAL --connlimit-mask 0 -j REJECT
$IPT -A INPUT -p tcp --dport $BEACON_TCP_PORT -j ACCEPT
