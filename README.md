# iptables4ethereum2
Firewall rules for ethereum 2.0 staking 

## introduction
I've been playing with ethereum 2.0 staking software for a while and  
these are firewall(iptables/nftables) rules that I found working well with it.  
They were uploaded after my eth node ran smoothly (validating and proposing blocks)  
for a couple of days without probems.  

## hardware & software
- [raspbian (Raspberry Pi OS Lite)](https://www.raspberrypi.org/downloads/raspberry-pi-os/) running on Raspberry Pi 4 (4GB RAM).  
- official [geth binary](https://geth.ethereum.org/downloads/)
- official [lighthouse](https://github.com/sigp/lighthouse/releases) and [prysm](https://github.com/prysmaticlabs/prysm/releases) binaries  

## network topology
iptables/nftables rules are provided per network configuration:

|directory|framework|description|
|---------|---------|-----------|
|router + eth2node |iptables|eth node is connected directly to router (with port forwarding)|
|vps + vpn + eth2node |iptables|eth node is connected to vps via vpn (with port forwarding)|
|nftables_router+eth2node|nftables|eth node is connected directly to router (with port forwarding)|

## todo
- [x] iptables: router + eth2node
- [x] iptables: vps + vpn + eth2node
- [x] nftables: router + eth2node
- [ ] nftables: vps + vpn + eth2node (delayed)

## last but not least
...pull requests are more than welcome 
