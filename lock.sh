#!/usr/bin/env bash

# Current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set library paths
export QML2_IMPORT_PATH="$DIR/..:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Get session type
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type --value 2>/dev/null || echo wayland)}"

# Kill active lockers to prevent collisions
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# Execute lock screen using full path
/usr/bin/quickshell -p "$DIR/lock_shell.qml"
