#!/usr/bin/env python3
import sys
import json
import os

EVENTS_FILE = os.path.expanduser('~/.config/quickshell/kuroiko_bar/calendar_events.json')

def load_events():
    if not os.path.exists(EVENTS_FILE):
        return {}
    try:
        with open(EVENTS_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def save_events(events):
    try:
        with open(EVENTS_FILE, 'w') as f:
            json.dump(events, f, indent=2)
    except Exception:
        pass

def main():
    if len(sys.argv) < 2:
        # Default: list all as JSON
        print(json.dumps(load_events()))
        return

    cmd = sys.argv[1]
    events = load_events()

    if cmd == "list":
        print(json.dumps(events))
    elif cmd == "set" and len(sys.argv) > 2:
        date = sys.argv[2]
        text = " ".join(sys.argv[3:]).strip()
        if text:
            events[date] = text
        else:
            events.pop(date, None)
        save_events(events)
        print(json.dumps(events))
    elif cmd == "get" and len(sys.argv) > 2:
        date = sys.argv[2]
        print(json.dumps({"date": date, "text": events.get(date, "")}))
    else:
        print(json.dumps(events))

if __name__ == '__main__':
    main()
