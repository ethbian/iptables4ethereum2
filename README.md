# iptables4ethereum2
Firewall rules for ethereum 2.0 staking 

## introduction
I've been playing with ethereum 2.0 staking software for a while and  
these are firewall(iptables) rules that I found working well with it.  
They were uploaded after my eth node ran smoothly (validating and proposing blocks)  
for a couple of days without probems.  

## hardware & software
- [raspbian (Raspberry Pi OS Lite)](https://www.raspberrypi.org/downloads/raspberry-pi-os/) running on Raspberry Pi 4 (4GB RAM).  
- official [geth binary](https://geth.ethereum.org/downloads/)
- official [lighthouse](https://github.com/sigp/lighthouse/releases) and [prysm](https://github.com/prysmaticlabs/prysm/releases) binaries  

## network topology
iptables rules are provided per network configuration:

|directory|description|
|---------|-----------|
|router + eth2node |eth node is connected directly to router (with port forwarding)|

## todo
vpn + eth2node configuration

## last but not least
...pull requests are more than welcome 