#!/usr/bin/env python3
import subprocess
import json
import re

def get_battery_info():
    # Find the battery device
    try:
        dev_res = subprocess.run(["upower", "-e"], capture_output=True, text=True, check=True)
        bat_dev = None
        for line in dev_res.stdout.splitlines():
            if "battery_BAT" in line:
                bat_dev = line.strip()
                break
        if not bat_dev:
            # Fallback to a default if not found
            bat_dev = "/org/freedesktop/UPower/devices/battery_BAT1"
    except Exception:
        bat_dev = "/org/freedesktop/UPower/devices/battery_BAT1"

    try:
        res = subprocess.run(["upower", "-i", bat_dev], capture_output=True, text=True, check=True)
    except Exception as e:
        return {"error": str(e)}

    info = {
        "state": "unknown",
        "power": "0.0 W",
        "time": "unknown",
        "time_type": "unknown",
        "percentage": "0%",
        "health": "100%"
    }

    for line in res.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(":", 1)
        if len(parts) < 2:
            continue
        key = parts[0].strip()
        val = parts[1].strip()

        if key == "state":
            info["state"] = val
        elif key == "energy-rate":
            info["power"] = val
        elif key == "time to empty" or key == "time to full":
            info["time"] = val
            info["time_type"] = "remaining" if key == "time to empty" else "to_full"
        elif key == "percentage":
            info["percentage"] = val
        elif key == "capacity":
            info["health"] = val

    return info

if __name__ == "__main__":
    print(json.dumps(get_battery_info()))
