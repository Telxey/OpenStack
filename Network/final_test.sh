#!/binbash

# Check IPv6 address
ip -6 addr show

ip addr show

# Test connectivity
ping6 -c 5 cloudflare.com   # Cloudflare DNS


ping6 -c 5 quad9.net  # Quad9 DNS


exit