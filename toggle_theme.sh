#!/usr/bin/env bash

# Get current color scheme
current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme)

echo "$(date '+%H:%M:%S.%N'): Called with scheme $current_scheme" >> /tmp/theme_toggle.log

if [ "$current_scheme" = "'prefer-dark'" ]; then
    # Switch to Light Mode
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    # Update Kvantum config to Colloid (light theme)
    sed -i 's/theme=.*/theme=Colloid/' ~/.config/Kvantum/kvantum.kvconfig
    echo "light"
else
    # Switch to Dark Mode
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    # Update Kvantum config to MaterialAdw (dark theme)
    sed -i 's/theme=.*/theme=MaterialAdw/' ~/.config/Kvantum/kvantum.kvconfig
    echo "dark"
fi
