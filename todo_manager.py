#!/usr/bin/env python3
import sys
import json
import os

TODO_FILE = os.path.expanduser('~/.config/quickshell/kuroiko_bar/todo.json')

def load_todos():
    if not os.path.exists(TODO_FILE):
        return []
    try:
        with open(TODO_FILE, 'r') as f:
            return json.load(f)
    except Exception:
        return []

def save_todos(todos):
    try:
        with open(TODO_FILE, 'w') as f:
            json.dump(todos, f, indent=2)
    except Exception:
        pass

def main():
    if len(sys.argv) < 2:
        # Default: list all as JSON
        print(json.dumps(load_todos()))
        return

    cmd = sys.argv[1]
    todos = load_todos()

    if cmd == "list":
        print(json.dumps(todos))
    elif cmd == "add" and len(sys.argv) > 2:
        text = " ".join(sys.argv[2:])
        priority = 0 # 0 = Normal, 1 = Low, 2 = Medium, 3 = High
        if text.startswith("!!!"):
            priority = 3
            text = text[3:].lstrip()
        elif text.startswith("!!"):
            priority = 2
            text = text[2:].lstrip()
        elif text.startswith("!"):
            priority = 1
            text = text[1:].lstrip()
            
        new_id = max([t['id'] for t in todos], default=0) + 1
        todos.append({
            "id": new_id, 
            "text": text, 
            "completed": False, 
            "priority": priority
        })
        save_todos(todos)
        print(json.dumps(todos))
    elif cmd == "toggle" and len(sys.argv) > 2:
        try:
            tid = int(sys.argv[2])
            for t in todos:
                if t['id'] == tid:
                    t['completed'] = not t['completed']
                    break
            save_todos(todos)
        except ValueError:
            pass
        print(json.dumps(todos))
    elif cmd == "delete" and len(sys.argv) > 2:
        try:
            tid = int(sys.argv[2])
            todos = [t for t in todos if t['id'] != tid]
            save_todos(todos)
        except ValueError:
            pass
        print(json.dumps(todos))
    elif cmd == "clear":
        todos = [t for t in todos if not t.get('completed', False)]
        save_todos(todos)
        print(json.dumps(todos))
    else:
        print(json.dumps(todos))

if __name__ == '__main__':
    main()
