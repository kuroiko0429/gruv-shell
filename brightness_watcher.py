#!/usr/bin/env python3
import os
import time
import sys

def get_backlight_path():
    base = "/sys/class/backlight"
    if os.path.exists(base):
        dirs = os.listdir(base)
        if dirs:
            # Prefer intel_backlight or amdgpu_bl0 if multiple exist
            for d in dirs:
                if "intel" in d or "amdgpu" in d:
                    return os.path.join(base, d)
            return os.path.join(base, dirs[0])
    return None

def main():
    path = get_backlight_path()
    if not path:
        # Fallback print if no backlight
        sys.exit(0)
    
    bri_file = os.path.join(path, "brightness")
    max_file = os.path.join(path, "max_brightness")
    
    try:
        with open(max_file, "r") as f:
            max_val = int(f.read().strip())
    except Exception:
        max_val = 100
        
    last_val = -1
    while True:
        try:
            with open(bri_file, "r") as f:
                cur_val = int(f.read().strip())
            pct = int((cur_val / max_val) * 100)
            if pct != last_val:
                # Always print the new value
                print(pct)
                sys.stdout.flush()
                last_val = pct
        except Exception:
            pass
        time.sleep(0.15)

if __name__ == "__main__":
    main()
