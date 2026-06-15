#!/usr/bin/env python3
import sys
import json
import os
import time
from datetime import datetime, timedelta

DATA_FILE = os.path.expanduser('~/.config/quickshell/kuroiko_bar/uptime_history.json')

def load_history():
    if not os.path.exists(DATA_FILE):
        return {}
    try:
        with open(DATA_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def save_history(history):
    try:
        with open(DATA_FILE, 'w') as f:
            json.dump(history, f, indent=2)
    except Exception:
        pass

def get_system_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            return float(f.readline().split()[0])
    except Exception:
        return 0.0

def distribute_duration(start_time, end_time, history):
    if start_time >= end_time:
        return
    current_time = end_time
    while current_time > start_time:
        dt = datetime.fromtimestamp(current_time)
        day_start_dt = dt.replace(hour=0, minute=0, second=0, microsecond=0)
        day_start = day_start_dt.timestamp()
        
        chunk_start = max(start_time, day_start)
        duration = current_time - chunk_start
        
        if duration > 0:
            day_str = day_start_dt.strftime('%Y-%m-%d')
            if day_str != "_state":
                history[day_str] = history.get(day_str, 0.0) + duration
                
        current_time = chunk_start

def update_uptime():
    history = load_history()
    uptime_seconds = get_system_uptime()
    if uptime_seconds <= 0:
        return history

    now = time.time()
    boot_time = now - uptime_seconds
    
    state = history.get("_state", {})
    last_boot_time = state.get("last_boot_time", 0.0)
    last_uptime = state.get("last_uptime", 0.0)
    
    # Check if we are in the same boot session
    uptime_diff = uptime_seconds - last_uptime
    is_same_session = False
    if uptime_diff >= 0:
        if abs(boot_time - last_boot_time) < 15.0 or uptime_diff < 300.0:
            is_same_session = True
            
    if is_same_session:
        start_time = boot_time + last_uptime
        end_time = boot_time + uptime_seconds
        distribute_duration(start_time, end_time, history)
    else:
        distribute_duration(boot_time, now, history)
        
    history["_state"] = {
        "last_boot_time": boot_time,
        "last_uptime": uptime_seconds
    }
    save_history(history)
    return history

def get_level(seconds):
    if seconds <= 0:
        return 0
    elif seconds < 3600:       # < 1h (level 1)
        return 1
    elif seconds < 10800:      # < 3h (level 2)
        return 2
    elif seconds < 21600:      # < 6h (level 3)
        return 3
    else:                      # >= 6h (level 4)
        return 4

def generate_contributions():
    history = update_uptime()
    
    today = datetime.now()
    # Find the nearest Saturday to end the grid (end of the current week)
    days_to_saturday = 6 if today.weekday() == 6 else 5 - today.weekday()
    end_date = today + timedelta(days=days_to_saturday)
    
    # 35 weeks = 245 days. The start date will be end_date - 244 days (which will be a Sunday).
    start_date = end_date - timedelta(days=244)
    
    result = []
    current_date = start_date
    while current_date <= end_date:
        date_str = current_date.strftime('%Y-%m-%d')
        seconds = history.get(date_str, 0.0)
        
        # If this is in the future relative to today, set level to -1 (unreached day)
        if current_date.date() > today.date():
            level = -1
        else:
            level = get_level(seconds)
            
        result.append({
            "date": date_str,
            "seconds": int(seconds),
            "level": level
        })
        current_date += timedelta(days=1)
        
    return result

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        # Daemon mode: run in loop and update uptime every 60s
        while True:
            try:
                update_uptime()
            except Exception:
                pass
            time.sleep(60)
    else:
        # Default: output contributions array
        try:
            print(json.dumps(generate_contributions()))
        except Exception as e:
            print(json.dumps([{"date": "error", "seconds": 0, "level": -1}]))

if __name__ == '__main__':
    main()
