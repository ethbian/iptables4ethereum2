# iptables4ethereum2: router + eth2 node
iptables rules for ethereum 2.0 staking

## network topology
```
internet ------ router ------ eth2node
```

Ports being forwarded on router:  
- 30303 tcp/udp (geth)  
- 9000 tcp/udp (lighthouse) or 13000 tcp/12000 udp (prysm)  

## linux
The script can be executed on any linux distro with iptables.  
Debian or Centos based distributions however have their own
iptables wrappers (ufw or firewalld) -  
those need to be disabled/removed first to avoid making a fuss.
  
All dropped connections are logged with level 7 (syslog debug).  
Just update your /etc/rsyslogd.conf file with
```
*.=debug                        -/var/log/iptables.log
```
and restart rsyslog to see what's going on.  

IPv6 is disabled (using sysctl).  
  
Default policies: input: DROP, forward: DROP, output: ACCEPT

To see what's going on:
```
iptables -L -n -v
iptables -L -n -v -t mangle
```

Portscan traps:
```
cat /proc/net/xt_recent/portscan
```