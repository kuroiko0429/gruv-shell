//@ pragma UseQApplication
// shell.qml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: shellRoot

    Item {
        id: theme
        property string mode: "dark"

        // Gruvbox Dark / Light colors
        property color bg0: mode === "dark" ? "#282828" : "#fbf1c7"
        property color bg0_hard: mode === "dark" ? "#1d2021" : "#f9f5d7"
        property color bg0_soft: mode === "dark" ? "#32302f" : "#f2e5bc"
        property color bg1: mode === "dark" ? "#3c3836" : "#ebdbb2"
        
        property color fg0: mode === "dark" ? "#fbf1c7" : "#282828"
        property color fg1: mode === "dark" ? "#ebdbb2" : "#3c3836"
        property color fg2: mode === "dark" ? "#d5c4a1" : "#504945"
        property color fg3: mode === "dark" ? "#bdae93" : "#665c54"
        property color fg4: mode === "dark" ? "#a89984" : "#7c6f64"
        property color gray: mode === "dark" ? "#928374" : "#928374"
        
        property color red: mode === "dark" ? "#fb4934" : "#cc241d"
        property color green: mode === "dark" ? "#b8bb26" : "#98971a"
        property color yellow: mode === "dark" ? "#fabd2f" : "#d79921"
        property color blue: mode === "dark" ? "#83a598" : "#458588"
        property color purple: mode === "dark" ? "#d3869b" : "#b16286"
        property color aqua: mode === "dark" ? "#8ec07c" : "#689d6a"
        property color orange: mode === "dark" ? "#fe8019" : "#d65d0e"

        Process {
            id: getThemeProc
            command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    let val = this.text.trim();
                    if (val.indexOf("prefer-light") !== -1) {
                        theme.mode = "light";
                    } else {
                        theme.mode = "dark";
                    }
                }
            }
        }

        Process {
            id: toggleThemeProc
            command: ["bash", "/home/kuroiko/.config/quickshell/kuroiko_bar/toggle_theme.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let val = this.text.trim();
                    if (val === "light" || val === "dark") {
                        theme.mode = val;
                    }
                }
            }
        }

        function toggle() {
            toggleThemeProc.running = false;
            toggleThemeProc.running = true;
        }
    }
    property var notificationHistory: []
    property int notifCardRightMargin: 15

    function addHistory(notification) {
        var list = [];
        for (var i = 0; i < notificationHistory.length; i++) {
            list.push(notificationHistory[i]);
        }
        var idx = -1;
        for (var j = 0; j < list.length; j++) {
            if (list[j].id === notification.id) {
                idx = j;
                break;
            }
        }
        if (idx !== -1) {
            list.splice(idx, 1);
        }
        
        var item = {
            id: notification.id,
            appName: notification.appName,
            appIcon: notification.appIcon,
            image: notification.image,
            summary: notification.summary,
            body: notification.body,
            timestamp: Qt.formatDateTime(new Date(), "HH:mm")
        };
        list.unshift(item);
        if (list.length > 100) list.length = 100;
        notificationHistory = list;
    }

    function removeHistory(id) {
        var list = [];
        for (var i = 0; i < notificationHistory.length; i++) {
            if (notificationHistory[i].id !== id) {
                list.push(notificationHistory[i]);
            }
        }
        notificationHistory = list;
    }

    function clearHistory() {
        notificationHistory = [];
    }

    function closeAllExcept(currentWindow) {
        let windows = [
            wallpaperSelector,
            appLauncher,
            clipboardSelector,
            powermenu,
            musicPlayer,
            batteryInfo,
            powerProfileSelector,
            wifiSelector,
            brightnessSelector,
            volumeSelector,
            notificationStation
        ];
        for (let i = 0; i < windows.length; i++) {
            let w = windows[i];
            if (w && w !== currentWindow && w.active) {
                w.active = false;
            }
        }
    }

    StatusBar {}
    WallpaperHud {}
    WallpaperSelector { id: wallpaperSelector }
    AppLauncher { id: appLauncher }
    ClipboardSelector { id: clipboardSelector }
    Powermenu { id: powermenu }
    ScreenCorners {}
    MusicPlayer { id: musicPlayer }
    BatteryInfo { id: batteryInfo }
    PowerProfileSelector { id: powerProfileSelector }
    WifiSelector { id: wifiSelector }
    BrightnessSelector { id: brightnessSelector }
    VolumeSelector { id: volumeSelector }
    Notifications { id: notifications }
    NotificationStation { id: notificationStation }

    NotificationServer {
        id: notifServer
        onNotification: (notification) => {
            notification.tracked = true;
            shellRoot.addHistory(notification);
            if (notifications) {
                notifications.addNotification(notification);
            }
        }
    }
}