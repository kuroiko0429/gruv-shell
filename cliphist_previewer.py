#!/usr/bin/env python3
import subprocess
import os
import glob
import re

def main():
    try:
        res = subprocess.run(["cliphist", "list"], capture_output=True, text=True, check=True)
    except Exception as e:
        print(f"Error running cliphist: {e}")
        return

    lines = res.stdout.strip().split("\n")
    active_ids = set()
    
    for line in lines:
        if not line.strip():
            continue
        parts = line.split("\t", 1)
        if len(parts) < 2:
            continue
        item_id, content = parts
        
        # Check if the content is a binary data/image entry
        if "[[ binary data" in content:
            active_ids.add(item_id)
            preview_path = f"/tmp/cliphist_{item_id}.png"
            
            # Decode if the preview file does not exist yet
            if not os.path.exists(preview_path):
                try:
                    with open(preview_path, "wb") as f:
                        subprocess.run(["cliphist", "decode", item_id], stdout=f, check=True)
                except Exception as e:
                    print(f"Failed to decode item {item_id}: {e}")

    # Clean up old preview files that are no longer in the clipboard history
    temp_files = glob.glob("/tmp/cliphist_*.png")
    for fpath in temp_files:
        fname = os.path.basename(fpath)
        m = re.match(r"cliphist_(\d+)\.png", fname)
        if m:
            fid = m.group(1)
            if fid not in active_ids:
                try:
                    os.remove(fpath)
                except Exception:
                    pass

if __name__ == "__main__":
    main()
