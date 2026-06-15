#!/usr/bin/env python3
import time
import os
import json
import subprocess
import sys
import signal

def sigterm_handler(signum, frame):
    sys.exit(0)

# Register clean SIGTERM handler
signal.signal(signal.SIGTERM, sigterm_handler)

def get_cpu_ticks():
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        parts = line.split()
        values = [float(x) for x in parts[1:9]] # user, nice, system, idle, iowait, irq, softirq, steal
        idle = values[3] + values[4] # idle + iowait
        total = sum(values)
        return idle, total
    except Exception:
        return 0.0, 0.0

def get_ram_usage():
    try:
        meminfo = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    meminfo[parts[0].strip()] = int(parts[1].split()[0])
        
        total = meminfo.get('MemTotal', 0) / 1024.0 / 1024.0 # GB
        available = meminfo.get('MemAvailable', 0) / 1024.0 / 1024.0 # GB
        used = total - available
        percent = (used / total * 100.0) if total > 0 else 0.0
        return used, total, percent
    except Exception:
        return 0.0, 0.0, 0.0

def get_disk_usage():
    try:
        st = os.statvfs('/')
        total = (st.f_blocks * st.f_frsize) / (1024.0**3) # GB
        free = (st.f_bavail * st.f_frsize) / (1024.0**3) # GB
        used = total - free
        percent = (used / total * 100.0) if total > 0 else 0.0
        return used, total, percent
    except Exception:
        return 0.0, 0.0, 0.0

def get_net_bytes():
    rx = 0
    tx = 0
    try:
        with open('/proc/net/dev', 'r') as f:
            lines = f.readlines()
        for line in lines[2:]:
            parts = line.split()
            if len(parts) >= 10:
                iface = parts[0].strip(':')
                # Ignore loopback, docker, virtual interfaces
                if not (iface.startswith('lo') or iface.startswith('docker') or iface.startswith('veth') or iface.startswith('br-') or iface.startswith('any')):
                    rx += int(parts[1])
                    tx += int(parts[9])
    except Exception:
        pass
    return rx, tx

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        hours = int(uptime_seconds // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        if hours > 0:
            return f"{hours}h {minutes}m"
        return f"{minutes}m"
    except Exception:
        return "N/A"

def get_sys_info():
    try:
        kernel = os.uname().release
        hostname = os.uname().nodename
        return kernel, hostname
    except Exception:
        return "N/A", "N/A"

def get_cpu_temp():
    # Look for TCPU or x86_pkg_temp
    for zone in os.listdir('/sys/class/thermal'):
        if zone.startswith('thermal_zone'):
            try:
                with open(f'/sys/class/thermal/{zone}/type', 'r') as f:
                    ztype = f.read().strip()
                if ztype in ('x86_pkg_temp', 'TCPU'):
                    with open(f'/sys/class/thermal/{zone}/temp', 'r') as f:
                        temp = int(f.read().strip()) / 1000.0
                    return round(temp)
            except Exception:
                pass
    # Fallback to thermal_zone0
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp = int(f.read().strip()) / 1000.0
        return round(temp)
    except Exception:
        return 0

def get_top_processes():
    try:
        out = subprocess.check_output(['ps', '-ao', 'comm,%cpu,%mem', '--sort=-%cpu'], text=True)
        lines = out.strip().split('\n')[1:5] # Take top 4 processes
        procs = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 3:
                name = " ".join(parts[:-2])
                cpu = float(parts[-2])
                mem = float(parts[-1])
                procs.append({'name': name, 'cpu': cpu, 'mem': mem})
        return procs
    except Exception:
        return []

def main():
    once = "--once" in sys.argv or "-o" in sys.argv
    
    # First tick baseline
    idle1, total1 = get_cpu_ticks()
    rx1, tx1 = get_net_bytes()
    
    # Sleep short duration for immediate reading
    time.sleep(0.15)
    idle2, total2 = get_cpu_ticks()
    rx2, tx2 = get_net_bytes()
    
    # Calculations
    cpu = (1.0 - (idle2 - idle1) / (total2 - total1)) * 100.0 if (total2 - total1) > 0 else 0.0
    rx_speed = (rx2 - rx1) / 0.15 / 1024.0 # KiB/s
    tx_speed = (tx2 - tx1) / 0.15 / 1024.0 # KiB/s
    
    used_mem, total_mem, mem_pct = get_ram_usage()
    used_disk, total_disk, disk_pct = get_disk_usage()
    temp = get_cpu_temp()
    procs = get_top_processes()
    uptime = get_uptime()
    kernel, hostname = get_sys_info()
    
    data = {
        'cpu': round(cpu, 1),
        'temp': temp,
        'ram_used': round(used_mem, 2),
        'ram_total': round(total_mem, 2),
        'ram_percent': round(mem_pct, 1),
        'disk_used': round(used_disk, 1),
        'disk_total': round(total_disk, 1),
        'disk_percent': round(disk_pct, 1),
        'net_down': round(rx_speed, 1),
        'net_up': round(tx_speed, 1),
        'uptime': uptime,
        'kernel': kernel,
        'hostname': hostname,
        'top_procs': procs
    }
    print(json.dumps(data))
    sys.stdout.flush()
    
    if once:
        return
        
    # Set baselines for loop
    idle1, total1 = idle2, total2
    rx1, tx1 = rx2, tx2
    
    # Loop indefinitely
    while True:
        try:
            time.sleep(2.0)
            idle2, total2 = get_cpu_ticks()
            rx2, tx2 = get_net_bytes()
            
            total_delta = total2 - total1
            cpu = (1.0 - (idle2 - idle1) / total_delta) * 100.0 if total_delta > 0 else 0.0
            rx_speed = (rx2 - rx1) / 2.0 / 1024.0 # KiB/s
            tx_speed = (tx2 - tx1) / 2.0 / 1024.0 # KiB/s
            
            idle1, total1 = idle2, total2
            rx1, tx1 = rx2, tx2
            
            used_mem, total_mem, mem_pct = get_ram_usage()
            used_disk, total_disk, disk_pct = get_disk_usage()
            temp = get_cpu_temp()
            procs = get_top_processes()
            uptime = get_uptime()
            kernel, hostname = get_sys_info()
            
            data = {
                'cpu': round(cpu, 1),
                'temp': temp,
                'ram_used': round(used_mem, 2),
                'ram_total': round(total_mem, 2),
                'ram_percent': round(mem_pct, 1),
                'disk_used': round(used_disk, 1),
                'disk_total': round(total_disk, 1),
                'disk_percent': round(disk_pct, 1),
                'net_down': round(rx_speed, 1),
                'net_up': round(tx_speed, 1),
                'uptime': uptime,
                'kernel': kernel,
                'hostname': hostname,
                'top_procs': procs
            }
            print(json.dumps(data))
            sys.stdout.flush()
        except (KeyboardInterrupt, SystemExit):
            break
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            time.sleep(2.0)

if __name__ == '__main__':
    main()
