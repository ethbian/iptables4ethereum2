# Change Log

All notable changes to this project will be documented in this file.

## 2020-10-19

vps+vpn+eth2node:
- [added] external interface for limiting rules
- [changed] DROP instead of REJECT when limiting connections  
  
nftables_router+eth2node:
- [changed] SYN not NEW fixed

## 2020-10-14

vps+vpn+eth2node:
- [changed] fixed udp FORWARD rules

## 2020-10-13

vps+vpn+eth2node:
- [added] missing FORWARD rules
- [changed] rules order

## 2020-09-20

- initial release: nftables_router+eth2node

## 2020-09-13

- initial release: vps+vpn+eth2node

## 2020-09-10

router+eth2node:
- [added] portscan detection

## 2020-09-04

router+eth2node:
- [added] UDP rules
- [added] LOG_DROP_INVALID, LOG_DROP_FRAGMENTED chains

## 2020-09-03

router+eth2node:
- [added] IPv6 disabled (sysctl.conf)  
- [added] LOG rate limiting
- [added] LOG_DROP_BOGUS chain

## 2020-09-02

- initial release: router+eth2node
