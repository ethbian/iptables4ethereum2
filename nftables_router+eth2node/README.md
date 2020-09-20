# iptables4ethereum2: router + eth2 node (nftables)
nftables rules for ethereum 2.0 staking

## network topology
```
internet ------ router ------ eth2node
```

Ports being forwarded on router:  
- 30303 tcp/udp (geth)  
- 9000 tcp/udp (lighthouse) or 13000 tcp/12000 udp (prysm)  

## linux
The script can be executed on any linux distro with nftables.  
Debian or Centos based distributions however have their own
iptables wrappers (ufw or firewalld) -  
those need to be disabled/removed first to avoid making a fuss.
  
All dropped connections are logged with debug level.  
Just update your /etc/rsyslogd.conf file with
```
*.=debug                        -/var/log/nftables.log
```
and restart rsyslog to see what's going on.  

IPv6 is disabled (using sysctl).  
  
Default policies: input: DROP, forward: DROP, output: ACCEPT

To see what's going on:
```
nft list ruleset

nft list meter ip filter geth-tcp-single
nft list set ip filter badguys2drop
nft list counter ip filter new_not_syn

```
