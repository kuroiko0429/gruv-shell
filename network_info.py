#!/usr/bin/env python3
import sys
import time
import subprocess
import json

def get_active_wifi_interface():
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"], capture_output=True, text=True, check=True)
        for line in res.stdout.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 3 and parts[1] == "wifi" and parts[2] == "connected":
                return parts[0]
    except Exception:
        pass
    return "wlan0"

def get_bytes(interface):
    try:
        with open("/proc/net/dev", "r") as f:
            lines = f.readlines()
        for line in lines:
            if interface in line:
                parts = line.split()
                # rx_bytes is the 2nd element, tx_bytes is the 10th
                rx = int(parts[1])
                tx = int(parts[9])
                return rx, tx
    except Exception:
        pass
    return 0, 0

def format_speed(bytes_per_sec):
    if bytes_per_sec < 1024:
        return f"{bytes_per_sec} B/s"
    elif bytes_per_sec < 1024 * 1024:
        return f"{bytes_per_sec / 1024:.1f} KB/s"
    else:
        return f"{bytes_per_sec / (1024 * 1024):.1f} MB/s"

def monitor_speed():
    interface = get_active_wifi_interface()
    last_rx, last_tx = get_bytes(interface)
    
    while True:
        time.sleep(1.0)
        interface = get_active_wifi_interface()
        rx, tx = get_bytes(interface)
        
        rx_diff = rx - last_rx
        tx_diff = tx - last_tx
        
        if rx_diff < 0: rx_diff = 0
        if tx_diff < 0: tx_diff = 0
        
        last_rx, last_tx = rx, tx
        
        info = {
            "rx_speed": format_speed(rx_diff),
            "tx_speed": format_speed(tx_diff)
        }
        print(json.dumps(info))
        sys.stdout.flush()

def get_wifi_list():
    try:
        subprocess.run(["nmcli", "device", "wifi", "rescan"], capture_output=True, timeout=5)
    except Exception:
        pass
        
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "device", "wifi", "list"], capture_output=True, text=True, check=True)
    except Exception as e:
        return []

    networks = []
    seen_ssids = set()
    
    for line in res.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        
        # Parse nmcli output keeping escaped colons '\:' in mind
        parts = []
        current = []
        escaped = False
        for char in line:
            if escaped:
                current.append(char)
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == ':':
                parts.append("".join(current))
                current = []
            else:
                current.append(char)
        parts.append("".join(current))

        if len(parts) < 4:
            continue
            
        ssid = parts[0]
        signal = parts[1]
        security = parts[2]
        active = parts[3] == "yes"
        
        if not ssid:
            continue
            
        if ssid in seen_ssids:
            continue
        seen_ssids.add(ssid)
        
        networks.append({
            "ssid": ssid,
            "signal": int(signal) if signal.isdigit() else 0,
            "security": security if security else "OPEN",
            "active": active
        })

    # Sort by signal strength descending
    networks = sorted(networks, key=lambda x: x["signal"], reverse=True)
    return networks

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "--list":
            print(json.dumps(get_wifi_list()))
        elif sys.argv[1] == "--speed":
            monitor_speed()
    else:
        # Default show both once
        interface = get_active_wifi_interface()
        print(json.dumps({
            "interface": interface,
            "list": get_wifi_list()
        }))
