#!/bin/bash
# Advanced firewall rules for OpenStack with IPv6

# IPv6 forwarding rules
ip6tables -A FORWARD -i br-int -o br-ext -j ACCEPT
ip6tables -A FORWARD -i br-ext -o br-int -m state --state RELATED,ESTABLISHED -j ACCEPT

# NAT64 specific rules
ip6tables -A FORWARD -s 2600:1700:5adb::/48 -j ACCEPT
ip6tables -A FORWARD -d 64:ff9b::/96 -j ACCEPT

# Protect against IPv6 neighbor solicitation attacks
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j ACCEPT
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j ACCEPT
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type router-solicitation -m hl --hl-eq 255 -j ACCEPT
ip6tables -A INPUT -p ipv6-icmp --icmpv6-type router-advertisement -m hl --hl-eq 255 -j ACCEPT

# Save rules
netfilter-persistent save