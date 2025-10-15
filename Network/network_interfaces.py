#!/usr/bin/env python3
import os
import re
import subprocess
import glob
from pathlib import Path

# ANSI colors - using provided color codes
RED = "\033[38;5;208m"     # Warning/Error
GREEN = "\033[38;5;118m"   # 10G+ Network
YELLOW = "\033[38;5;3m"    # 1G Network
BLUE = "\033[38;5;105m"    # VLANs
CYAN = "\033[38;5;33m"     # Bridge
RESET = "\033[0m"
BOLD = "\033[1m"

def run_command(command):
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(command, shell=True, check=True, 
                               text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"
        
def get_interfaces():
    """Get a list of network interfaces."""
    interfaces = []
    if os.path.exists("/sys/class/net/"):
        interfaces = os.listdir("/sys/class/net/")
    else:
        output = run_command("ip link show")
        interfaces = re.findall(r'\d+: (\w+):', output)
    return interfaces
    
def is_vlan_interface(interface):
    """Check if interface is a VLAN interface."""
    # VLAN interfaces often have a dot or 'vlan' in the name
    if '.' in interface or 'vlan' in interface.lower():
        return True
        
    # Check if it's explicitly tagged as a VLAN
    output = run_command(f"ip -d link show {interface}")
    if "vlan" in output.lower():
        return True
        
    return False
    
def is_bridge_interface(interface):
    """Check if interface is a bridge."""
    if interface.startswith("br"):
        return True
        
    # Check if it's explicitly a bridge
    output = run_command(f"ip -d link show {interface}")
    if "bridge" in output.lower():
        return True
        
    # Try another method
    bridge_path = f"/sys/class/net/{interface}/bridge"
    if os.path.exists(bridge_path):
        return True
        
    return False
    
def get_interface_type(interface, with_color=False):
    """Determine the interface type based on naming conventions or driver info."""
    if interface.startswith("wl"):
        return "Wireless"
    elif is_bridge_interface(interface):
        return f"{CYAN}Bridge{RESET}" if with_color else "Bridge"
    elif is_vlan_interface(interface):
        return f"{BLUE}VLAN{RESET}" if with_color else "VLAN"
    elif interface.startswith("en") or interface.startswith("eth"):
        speed = get_link_speed(interface, raw=True)
        if speed >= 10000:
            return f"{GREEN}Ethernet (10G+){RESET}" if with_color else "Ethernet (10G+)"
        else:
            return f"{YELLOW}Ethernet (1G){RESET}" if with_color else "Ethernet (1G)"
    elif interface.startswith("lo"):
        return "Loopback"
    elif interface.startswith("docker") or interface.startswith("veth"):
        return "Docker/Container"
    elif interface.startswith("v") or "virt" in interface:
        # Check if it's a VLAN first
        if is_vlan_interface(interface):
            return f"{BLUE}VLAN{RESET}" if with_color else "VLAN"
        return "Virtual"
        
    # Try to get more specific info from driver
    driver_path = f"/sys/class/net/{interface}/device/driver"
    if os.path.exists(driver_path):
        driver = os.path.basename(os.readlink(driver_path))
        if any(wl in driver for wl in ["wireless", "wifi", "80211"]):
            return "Wireless"
            
    return "Unknown"
    
def get_ip_addresses(interface):
    """Get IP addresses for an interface."""
    output = run_command(f"ip addr show {interface}")
    ipv4 = re.findall(r'inet (\d+\.\d+\.\d+\.\d+)', output)
    ipv6 = re.findall(r'inet6 ([0-9a-f:]+)', output)
    return {"IPv4": ipv4, "IPv6": ipv6}
    
def get_mac_address(interface):
    """Get MAC address for an interface."""
    mac_path = f"/sys/class/net/{interface}/address"
    if os.path.exists(mac_path):
        with open(mac_path, 'r') as f:
            return f.read().strip()
    else:
        output = run_command(f"ip link show {interface}")
        mac_match = re.search(r'link/\w+ ([0-9a-f:]+)', output)
        if mac_match:
            return mac_match.group(1)
    return "Not available"
    
def get_link_speed(interface, raw=False):
    """Get link speed for an interface."""
    speed_path = f"/sys/class/net/{interface}/speed"
    if os.path.exists(speed_path):
        try:
            with open(speed_path, 'r') as f:
                speed = f.read().strip()
                if speed.isdigit():
                    if raw:
                        return int(speed)
                    return f"{speed} Mbps"
                else:
                    if raw:
                        return 0
                    return "Unknown"
        except:
            pass
    
    # Try with ethtool if available
    output = run_command(f"ethtool {interface} 2>/dev/null | grep 'Speed:'")
    if output and not output.startswith("Error"):
        speed_match = re.search(r'Speed: (.+)', output)
        if speed_match:
            speed_str = speed_match.group(1)
            # Convert to numeric if needed
            if raw:
                if "Gb" in speed_str:
                    return int(float(speed_str.replace("Gb/s", "").strip()) * 1000)
                elif "Mb" in speed_str:
                    return int(float(speed_str.replace("Mb/s", "").strip()))
                else:
                    return 0
            return speed_match.group(1)
            
    if raw:
        return 0
    return "Not available"
    
def get_interface_status(interface, with_color=False):
    """Get status (UP/DOWN) for an interface."""
    state_path = f"/sys/class/net/{interface}/operstate"
    if os.path.exists(state_path):
        with open(state_path, 'r') as f:
            status = f.read().strip().upper()
    else:
        output = run_command(f"ip link show {interface}")
        if "UP" in output:
            status = "UP"
        else:
            status = "DOWN"
            
    if with_color:
        if status == "UP":
            return f"{GREEN}{status}{RESET}"
        elif status == "DOWN":
            return f"{RED}{status}{RESET}"
        else:
            return f"{YELLOW}{status}{RESET}"
    return status
        
def get_driver_info(interface):
    """Get driver information for an interface."""
    driver_path = f"/sys/class/net/{interface}/device/driver/module"
    if os.path.exists(driver_path):
        module_name = os.path.basename(os.readlink(driver_path))
        return module_name
        
    # Alternative approach
    driver_path = f"/sys/class/net/{interface}/device/driver"
    if os.path.exists(driver_path):
        return os.path.basename(os.readlink(driver_path))
        
    return "Not available"
    
def get_interface_color(interface, itype):
    """Get color for interface header based on type."""
    if is_bridge_interface(interface):
        return CYAN
    elif is_vlan_interface(interface):
        return BLUE
    elif "Ethernet" in itype:
        if "(10G+)" in itype:
            return GREEN
        else:
            return YELLOW
    return ""  # Default, no color
    
def main():
    print(f"{BOLD}Network Interfaces Information{RESET}\n" + "="*30)
    print("Interface Type Legend:")
    print(f"  {YELLOW}Ethernet (1G){RESET}: 1 Gigabit Ethernet interfaces")
    print(f"  {GREEN}Ethernet (10G+){RESET}: 10+ Gigabit Ethernet interfaces")
    print(f"  {BLUE}VLAN{RESET}: Virtual LAN interfaces")
    print(f"  {CYAN}Bridge{RESET}: Network bridge interfaces")
    
    try:
        interfaces = get_interfaces()
        
        if not interfaces:
            print("No network interfaces found.")
            return
            
        for interface in sorted(interfaces):
            try:
                # Interface Type (without color for logic)
                itype = get_interface_type(interface, with_color=False)
                
                # Get color for header
                color = get_interface_color(interface, itype)
                
                # Print colored header
                print(f"\n{color}{BOLD}{interface} {'='*(25-len(interface))}{RESET}")
                
                # Interface Type (with color)
                itype_display = get_interface_type(interface, with_color=True)
                print(f"  Type:       {itype_display}")
                
                # Status (with color)
                status = get_interface_status(interface, with_color=True)
                print(f"  Status:     {status}")
                
                # MAC Address
                mac = get_mac_address(interface)
                print(f"  MAC:        {mac}")
                
                # IP Addresses
                ip_addresses = get_ip_addresses(interface)
                print(f"  IPv4:       {', '.join(ip_addresses['IPv4']) if ip_addresses['IPv4'] else 'None'}")
                print(f"  IPv6:       {', '.join(ip_addresses['IPv6'][:1]) if ip_addresses['IPv6'] else 'None'}")
                if len(ip_addresses['IPv6']) > 1:
                    print(f"               ({len(ip_addresses['IPv6'])-1} more IPv6 addresses not shown)")
                
                # Link Speed
                speed = get_link_speed(interface)
                print(f"  Link Speed: {speed}")
                
                # Driver Info
                driver = get_driver_info(interface)
                print(f"  Driver:     {driver}")
                
            except Exception as e:
                print(f"  {RED}Error gathering information for {interface}: {str(e)}{RESET}")
            
    except Exception as e:
        print(f"{RED}Error: {str(e)}{RESET}")
        
if __name__ == "__main__":
    main()

