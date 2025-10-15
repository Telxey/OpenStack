#!/usr/bin/env python3
import os, re, subprocess, json

# Colors
RED, GREEN, YELLOW, BLUE, CYAN = "\033[38;5;208m", "\033[38;5;118m", "\033[38;5;3m", "\033[38;5;105m", "\033[38;5;33m"
RESET, BOLD = "\033[0m", "\033[1m"

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.stdout.strip()
    except: return ""

def get_os_drive():
    output = run_cmd("df -h /")
    for line in output.splitlines()[1:]:
        if " /" in line: return line.split()[0]
    return None

def is_os_drive(device):
    os_drive = get_os_drive()
    if not os_drive: return False
    if device == os_drive: return True
    
    if os_drive.startswith("/dev/mapper/"):
        # Check partitions
        parts = run_cmd(f"lsblk -n -o NAME {device} | grep -v '^{os.path.basename(device)}$'")
        for part in parts.splitlines():
            if not part.strip(): continue
            # Check if partition is PV for OS
            pv_check = run_cmd(f"sudo pvs --noheadings -o vg_name /dev/{part.strip()} 2>/dev/null").strip()
            if pv_check and (pv_check == "ubuntu-vg" or pv_check == "ubuntu--vg"): return True
            
        # Check for boot partitions
        mount_points = run_cmd(f"lsblk -n -o MOUNTPOINT {device}")
        if "/boot" in mount_points or "/boot/efi" in mount_points: return True
    return False

def get_health(device):
    data = {}
    if "nvme" in device:
        # NVMe health
        output = run_cmd(f"sudo nvme smart-log {device} 2>/dev/null")
        # Extract basic health info
        for line in output.splitlines():
            if "critical_warning" in line:
                val = line.split(":")[-1].strip()
                data["health"] = "PASSED" if val == "0" else "FAILED"
            elif "temperature" in line and "°C" in line:
                val = line.split(":")[-1].strip().split()[0]
                if val.isdigit(): data["temp"] = f"{val}°C"
            elif "percentage_used" in line:
                val = line.split(":")[-1].strip()
                data["wear"] = val
            elif "available_spare" in line and "threshold" not in line:
                val = line.split(":")[-1].strip()
                data["spare"] = val
            elif "Data Units Written" in line and "(" in line:
                val = line.split("(")[-1].split(")")[0]
                data["written"] = val
            elif "power_on_hours" in line:
                val = line.split(":")[-1].strip()
                if val.isdigit():
                    hours = int(val)
                    days = hours // 24
                    data["power_on"] = f"{days} days ({hours} hours)"
            elif "media_errors" in line:
                val = line.split(":")[-1].strip()
                data["errors"] = val
    else:
        # SATA health
        output = run_cmd(f"sudo smartctl -H {device} 2>/dev/null")
        if "PASSED" in output: data["health"] = "PASSED"
        elif "FAILED" in output: data["health"] = "FAILED"
        
        # Get attributes
        output = run_cmd(f"sudo smartctl -A {device} 2>/dev/null")
        for line in output.splitlines():
            if "Temperature" in line:
                match = re.search(r'(\d+)(?:\s*Celsius|\s*°C|\s*C)', line)
                if match: data["temp"] = f"{match.group(1)}°C"
            elif "Power_On_Hours" in line:
                match = re.search(r'\d+\s+Power_On_Hours.*?(\d+)', line)
                if match:
                    hours = int(match.group(1))
                    days = hours // 24
                    data["power_on"] = f"{days} days ({hours} hours)"
            elif "Reallocated_Sector" in line:
                match = re.search(r'\d+\s+Reallocated_Sector.*?(\d+)', line)
                if match: data["reallocated"] = match.group(1)
            elif "Media_Wearout" in line or "Wear_Leveling" in line:
                match = re.search(r'\d+\s+(Media_Wearout|Wear_Leveling).*?(\d+)', line)
                if match: data["wear"] = f"{match.group(2)}%"
    return data

def find_control_plane(drives):
    """Find best Control Plane drive: not OS, < 900GB, NVMe preferred"""
    os_drives = [d for d in drives if is_os_drive(d)]
    candidates = []
    
    for drive in drives:
        if drive in os_drives: continue
        size = run_cmd(f"lsblk -d -n -o SIZE {drive}").strip()
        # Convert to GB
        size_num = float(re.sub(r'[^0-9.]', '', size))
        if size.endswith('T'): size_gb = size_num * 1024
        else: size_gb = size_num
        
        # Add score for type (NVMe preferred)
        type_score = 10 if 'nvme' in drive else 0
        # Add score for smaller size
        size_score = 5 if size_gb < 900 else 0
        
        candidates.append((drive, size_gb, type_score + size_score))
    
    # Sort by score (higher is better), then by size (smaller is better)
    if candidates:
        candidates.sort(key=lambda x: (-x[2], x[1]))
        return candidates[0][0]
    return None

def main():
    print(f"{BOLD}OpenStack Storage Device Health & Information{RESET}\n" + "="*45)
    print("Storage Tier Classification:")
    print(f"  {RED}{BOLD}OS Drive{RESET}: Operating System installation - DO NOT REMOVE!")
    print(f"  {GREEN}{BOLD}Control Plane{RESET}: OpenStack control services (separate from OS)")
    print(f"  {YELLOW}{BOLD}Tier 1 (NVMe){RESET}: High performance storage for critical workloads")
    print(f"  {BLUE}{BOLD}Tier 2 (SSD){RESET}: Medium performance storage for general workloads")
    print(f"  {CYAN}{BOLD}Tier 3 (HDD){RESET}: Capacity-optimized storage for bulk data")
    
    # Get OS drive
    os_drive = get_os_drive()
    print(f"\nOS drive identified as: {os_drive}")
    
    # Get all drives
    output = run_cmd("lsblk -d -n -o NAME,TYPE | grep disk")
    drives = []
    for line in output.splitlines():
        if line.strip() and not line.split()[0].startswith("loop"):
            drives.append(f"/dev/{line.split()[0]}")
    
    if not drives:
        print("No drives found!")
        return
        
    # Find control plane drive
    cp_drive = find_control_plane(drives)
    if cp_drive:
        print(f"Control Plane drive selected: {cp_drive}")
    
    # Process each drive
    for drive in drives:
        # Get info
        name = drive.replace("/dev/", "")
        model = run_cmd(f"lsblk -d -n -o MODEL {drive}").strip()
        size = run_cmd(f"lsblk -d -n -o SIZE {drive}").strip()
        is_os = is_os_drive(drive)
        is_cp = (drive == cp_drive)
        
        # Get health data
        data = get_health(drive)
        
        # Determine tier
        if is_os:
            tier = f"{RED}{BOLD}OS Drive{RESET}"
            header_marker = f" {RED}{BOLD}[OS DRIVE - DO NOT REMOVE!]{RESET}"
        elif is_cp:
            tier = f"{GREEN}{BOLD}Control Plane{RESET}"
            header_marker = f" {GREEN}{BOLD}[CONTROL PLANE]{RESET}"
        elif 'nvme' in drive:
            tier = f"{YELLOW}{BOLD}Tier 1 (NVMe){RESET}"
            header_marker = ""
        elif 'ssd' in model.lower():
            tier = f"{BLUE}{BOLD}Tier 2 (SSD){RESET}"
            header_marker = ""
        else:
            tier = f"{CYAN}{BOLD}Tier 3 (HDD){RESET}"
            header_marker = ""
        
        # Print header
        print(f"\n{BOLD}{name} {'='*(25-len(name))}{RESET}{header_marker}")
        print(f"  Model:       {model}")
        print(f"  Size:        {size}")
        print(f"  OpenStack:   {tier}")
        
        # Health status
        health = data.get("health", "Unknown")
        health_color = GREEN if health == "PASSED" else RED if health == "FAILED" else YELLOW
        print(f"  Health:      {health_color}{health}{RESET}")
        
        # Temperature
        if "temp" in data: print(f"  Temperature: {data['temp']}")
        
        # Drive specific info
        if "nvme" in drive:
            if "wear" in data:
                wear = data["wear"]
                wear_val = int(wear.rstrip("%")) if wear.endswith("%") else 0
                wear_color = GREEN if wear_val < 50 else (YELLOW if wear_val < 80 else RED)
                print(f"  Wear Level:  {wear_color}{wear}{RESET}")
            if "spare" in data: print(f"  Spare:       {data['spare']}")
            if "written" in data: print(f"  Data Written:{data['written']}")
            if "errors" in data:
                errors = data["errors"]
                err_color = GREEN if errors == "0" else RED
                print(f"  Media Errors:{err_color} {errors}{RESET}")
        else:
            if "wear" in data:
                wear = data["wear"]
                wear_val = int(wear.rstrip("%")) if wear.endswith("%") else 0
                wear_color = GREEN if wear_val < 50 else (YELLOW if wear_val < 80 else RED)
                print(f"  Wear Level:  {wear_color}{wear}{RESET}")
            if "reallocated" in data:
                sectors = data["reallocated"]
                sec_color = GREEN if sectors == "0" else RED
                print(f"  Reallocated: {sec_color}{sectors} sectors{RESET}")
        
        # Power on time
        if "power_on" in data: print(f"  Power On:    {data['power_on']}")
        
        # Partition info
        print("  Partitions:")
        parts = run_cmd(f"lsblk -n -o NAME,SIZE,MOUNTPOINT,FSTYPE {drive} | grep -v ^{os.path.basename(drive)}$")
        if parts.strip():
            for part_line in parts.splitlines():
                if not part_line.strip(): continue
                p_parts = part_line.split()
                if len(p_parts) >= 2:
                    part_name, part_size = p_parts[0], p_parts[1]
                    info = f"    {part_name} ({part_size})"
                    
                    # Mount point
                    mount_idx = part_line.find("/")
                    if mount_idx > 0:
                        mount = part_line[mount_idx:].split()[0]
                        info += f" → {mount}"
                        if mount in ["/", "/boot", "/boot/efi"]: info += f" {RED}[OS]{RESET}"
                    elif len(p_parts) >= 4 and p_parts[3]:
                        info += f" ({p_parts[3]})"
                        if p_parts[3] == "LVM2_member":
                            vg = run_cmd(f"sudo pvs --noheadings -o vg_name /dev/{part_name} 2>/dev/null").strip()
                            if vg and (vg == "ubuntu-vg" or vg == "ubuntu--vg"):
                                info += f" {RED}[OS-LVM]{RESET}"
                    print(info)
        else:
            print("    None")

if __name__ == "__main__":
    main()

