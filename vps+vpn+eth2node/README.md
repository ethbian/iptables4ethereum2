# iptables4ethereum2: vps + vpn + eth2 node
iptables rules for ethereum 2.0 staking

## network topology
```
internet ------ vps --- (vpn) --- eth2node
```

Ports being forwarded on vps (via vpn):  
- 30303 tcp/udp (geth)  
- 9000 tcp/udp (lighthouse) or 13000 tcp/12000 udp (prysm)  

## why vps + vpn?  
virtual private server + openvpn:  
(+) internet connection speed (protects your connection from flooding, bogus/invalid packets and so on)  
(+) static IP address (so you don't need one, you can change your ISP on the fly)  
(+) your real IP address is hidden (possible $5 wrench attack)  
(-) longer latency  
(-) additional point of failure  

## linux

The script can be executed on any linux distro with iptables.  
Debian or Centos based distributions however have their own
iptables wrappers (ufw or firewalld) -   
those need to be disabled/removed first to avoid making a fuss.
  
OpenVPN server is installed on your vps and the client on your eth node.  
Once running - disconnect your router/modem for a moment to make sure  
vpn connection comes back up automatically.  
  
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
iptables -L -n -v -t nat
iptables -L -n -v -t mangle
```

Portscan traps:
```
cat /proc/net/xt_recent/portscan
```

Show natted connections (being forwared and so on): 
```
netstat-nat -n
conntrack -L -n
```
netstat-nat (older kernels) or conntrack (newer kernels) needs to be installed.