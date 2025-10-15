#!/binbash

echo 'Router Advertisement: Enable IPv6 router advertisements on your external bridge or interface:'

sudo sysctl -w net.ipv6.conf.br-extvm.accept_ra=2
sudo sysctl -w net.ipv6.conf.br-extvm.forwarding=1

echo 'Make this persistent by adding to /etc/sysctl.conf:'

net.ipv6.conf.br-extvm.accept_ra=2
net.ipv6.conf.br-extvm.forwarding=1

echo 'Firewall Configuration:'
echo 'Info If you using a firewall, ensure it allows traffic to your VMs:'

# Allow traffic to VM IPv6 subnet
sudo ip6tables -A FORWARD -d 2600:1700:5adb:7009::/64 -j ACCEPT
sudo ip6tables -A FORWARD -s 2600:1700:5adb:7009::/64 -j ACCEPT



