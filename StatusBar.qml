//  StatusBar.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: statusBarWindow
    anchors {
      top: true
      left: true
      right: true
    }
    
    margins.top: 0
    // implicitWidth: 1500
    implicitHeight: 35
    color: "transparent"

    // --- パワープロファイル制御 ---
    property string activePowerProfile: "balanced"

    Process {
        id: getPowerProfileProc
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                activePowerProfile = this.text.trim()
            }
        }
    }

    Process {
        id: setPowerProfileProc
    }

    Timer {
        interval: 10000 // 10秒ごとに同期
        running: true
        repeat: true
        onTriggered: {
            getPowerProfileProc.running = false
            getPowerProfileProc.running = true
        }
    }

    function togglePowerProfile() {
        let nextProfile = "balanced"
        let msg = ""
        if (activePowerProfile === "power-saver") {
            nextProfile = "balanced"
            msg = "「標準 (Balanced)」に切り替えました"
        } else if (activePowerProfile === "balanced") {
            nextProfile = "performance"
            msg = "「パフォーマンス (Performance)」に切り替えました"
        } else {
            nextProfile = "power-saver"
            msg = "「省電力 (Power Saver)」に切り替えました"
        }

        // プロファイルをセットし、直後に通知を送る
        let cmd = "powerprofilesctl set " + nextProfile + " && notify-send -h string:x-canonical-private-synchronous:power-profile -u low '電源プロファイル' '" + msg + "'"
        setPowerProfileProc.exec(["sh", "-c", cmd])

        // 状態をローカルで即時反映し、再度同期プロセスを回す
        activePowerProfile = nextProfile
    }

    IpcHandler {
        target: "statusBar"
        function updatePowerProfile(profile: string): void {
            statusBarWindow.activePowerProfile = profile
        }
        function updateBrightness(val: string): void {
            briRoot.brightnessVal = parseInt(val) || 0
        }
    }

    // Mpris プレイヤーの選定
    property var activePlayer: {
        let count = Mpris.players.count // 依存性の確保
        let list = Mpris.players.values
        // まず再生中のプレイヤーを探す
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return list[0] ?? null
    }

    Item {
        anchors.fill: parent
        Rectangle {
            id: roundedBg
            anchors.fill: parent
            color: theme.bg0_hard // Gruvbox背景
            //radius: 12
        }
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: roundedBg.radius
            color: roundedBg.color
            radius: 0 
        }
    }

    // 各ウィジェットの配置土台
    Item {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        
        // --- 1. 左側: ワークスペース & 音楽 (左端に固定) ---
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter // 縦の真ん中に揃える
            spacing: 4
                    
            Repeater {
                model: 5 // 常に5つのワークスペースを表示 (1〜5)
                         
                Rectangle {
                    width: 40
                    height: 24
                    radius: 6
                    
                    property int wsId: index + 1
                    property bool isFocused: wsId === Hyprland.focusedWorkspace?.id

                    color: isFocused ? theme.bg0 : theme.bg0_soft
                  
                    Text {
                        anchors.centerIn: parent
                        text: parent.wsId.toString()
                        color: parent.isFocused ? theme.fg0 : theme.gray
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let ws = Hyprland.workspaces.values.find(w => w && w.id === parent.wsId)
                            if (ws) {
                                ws.activate()
                            } else {
                                Hyprland.dispatch("workspace " + parent.wsId)
                            }
                        }
                    }
                }
            }

            // ワークスペースと音楽の間の隙間
            Item {
                width: 8
                height: 24
                visible: activePlayer !== null && activePlayer.trackTitle !== ""
            }

            // 音楽情報
            Rectangle {
                id: musicPill
                color: theme.bg0
                radius: 6
                width: 200
                height: 24
                visible: activePlayer !== null && activePlayer.trackTitle !== ""

                Text {
                    id: musicText
                    anchors.centerIn: parent
                    width: parent.width - 20
                    text: {
                        let player = activePlayer
                        if (!player) return ""
                        let title = player.trackTitle
                        let artist = player.trackArtist
                        return artist ? `${title} - ${artist}` : title
                    }
                    elide: Text.ElideRight
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }

                // クリックで再生/一時停止、右クリックでプレイヤー詳細トグル
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "musicPlayer", "toggle"])
                    }
                }
            }

            // スクリーンショットボタン
            Rectangle {
                id: screenshotButton
                color: theme.bg0
                radius: 6
                width: 44
                height: 24

                Text {
                    anchors.centerIn: parent
                    text: "SHOT"
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 10
                    font.family: "Monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    
                    onEntered: screenshotButton.color = theme.bg0_soft
                    onExited: screenshotButton.color = theme.bg0

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            Quickshell.execDetached(["sh", "-c", "grim -g \"$(slurp)\" - | swappy -f -"])
                        } else if (mouse.button === Qt.RightButton) {
                            Quickshell.execDetached(["sh", "-c", "grim - | swappy -f -"])
                        }
                    }
                }
            }
        }

        // --- 2. 中央: アプリ名 (親Itemの完全な中央に固定) ---
        Rectangle {
            id: activeAppBg
            anchors.centerIn: parent
            width: Math.min(250, activeAppText.implicitWidth + 20)
            height: 24
            color: theme.bg0
            radius: 6

            // 幅を滑らかに伸縮させるアニメーション
            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            Text {
                id: activeAppText
                anchors.centerIn: parent
                width: parent.width - 20
                text: Hyprland.activeToplevel ? 
                        (Hyprland.activeToplevel.title !== "" ? Hyprland.activeToplevel.title : "タイトルなし") 
                        : "デスクトップ"
                color: theme.fg0
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // --- 3. 右側: 各種ステータス (右端に固定) ---
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // システムトレイ切り替えボタン
            Rectangle {
                id: systrayBtn
                color: theme.bg0
                radius: 6
                width: 24
                height: 24

                Text {
                    anchors.centerIn: parent
                    text: "^"
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: systrayBtn.color = theme.bg0_soft
                    onExited: systrayBtn.color = theme.bg0
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "systraySelector", "toggle"])
                    }
                }
            }

            // スピーカー音量
            Rectangle {
                id: volRect
                color: theme.bg0
                radius: 6
                width: implicitWidth
                height: implicitHeight
                implicitWidth: volText.implicitWidth + 20
                implicitHeight: 24

                PwObjectTracker {
                    objects: [Pipewire.defaultAudioSink]
                }

                Text {
                    id: volText
                    anchors.centerIn: parent
                    text: {
                        let sink = Pipewire.defaultAudioSink
                        if (!sink || !sink.audio) return "VOL --%"
                        if (sink.audio.muted) return "VOL MUT"
                        return "VOL " + Math.round(sink.audio.volume * 100) + "%"
                    }
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 12
                }

                // マウススクロールで音量を調整 / 左クリックで詳細トグル / 右クリックでミュート切り替え
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        let sink = Pipewire.defaultAudioSink
                        if (mouse.button === Qt.LeftButton) {
                            Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "volumeSelector", "toggle"])
                        } else if (mouse.button === Qt.RightButton && sink && sink.audio) {
                            sink.audio.muted = !sink.audio.muted
                        }
                    }
                    onWheel: event => {
                        let sink = Pipewire.defaultAudioSink
                        if (!sink || !sink.audio) return
                        let step = -(event.angleDelta.y / 120 * 0.01)
                        sink.audio.volume = Math.max(0.0, Math.min(1.5, sink.audio.volume + step))
                    }
                }
            }

            // ディスプレイ光度
            Rectangle {
                id: briRoot
                color: theme.bg0
                radius: 6
                width: implicitWidth
                height: implicitHeight
                implicitWidth: briText.implicitWidth + 20
                implicitHeight: 24

                property int brightnessVal: 50

                Text {
                    id: briText
                    anchors.centerIn: parent
                    text: "BRI " + briRoot.brightnessVal + "%"
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 12
                }

                Process {
                    id: briProcess
                    command: ["sh", "-c", "cat /sys/class/backlight/intel_backlight/brightness /sys/class/backlight/intel_backlight/max_brightness"]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n")
                            if (lines.length >= 2) {
                                let cur = parseInt(lines[0])
                                let max = parseInt(lines[1])
                                if (!isNaN(cur) && !isNaN(max) && max > 0) {
                                    briRoot.brightnessVal = Math.round(cur / max * 100)
                                }
                            }
                        }
                    }
                }

                Process {
                    id: briSetProcess
                }

                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: {
                        briProcess.running = false
                        briProcess.running = true
                    }
                }

                Timer {
                    id: syncTimer
                    interval: 300
                    running: false
                    repeat: false
                    onTriggered: {
                        briProcess.running = false
                        briProcess.running = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "brightnessSelector", "toggle"])
                    }
                    onWheel: event => {
                        let increase = event.angleDelta.y < 0
                        if (increase) {
                            briRoot.brightnessVal = Math.min(100, briRoot.brightnessVal + 1)
                        } else {
                            briRoot.brightnessVal = Math.max(0, briRoot.brightnessVal - 1)
                        }

                        let arg = increase ? "+1%" : "1%-"
                        briSetProcess.exec(["brightnessctl", "set", arg])
                        syncTimer.restart()
                    }
                }
            }

            // Wi-Fi 接続名
            Rectangle {
                id: wifiRoot
                color: theme.bg0
                radius: 6
                width: implicitWidth
                height: implicitHeight
                implicitWidth: wifiText.implicitWidth + 20
                implicitHeight: 24

                property var wifiDevice: {
                    let count = Networking.devices.count
                    let devList = Networking.devices.values
                    for (let i = 0; i < devList.length; i++) {
                        let device = devList[i]
                        if (device && device.type === DeviceType.Wifi) return device
                    }
                    return null
                }

                Text {
                    id: wifiText
                    anchors.centerIn: parent
                    text: {
                        let dev = wifiRoot.wifiDevice
                        if (!dev) return "WIFI --"
                        
                        let netList = dev.networks.values
                        for (let i = 0; i < netList.length; i++) {
                            let net = netList[i]
                            if (net && net.connected) {
                                return net.name
                            }
                        }
                        return "WIFI DISCONN"
                    }
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "wifiSelector", "toggle"])
                    }
                }
            }

            // パワープロファイル
            Rectangle {
                id: pwrRect
                color: theme.bg0
                radius: 6
                implicitWidth: 90
                implicitHeight: 24

                Text {
                    id: pwrText
                    anchors.centerIn: parent
                    text: {
                        if (activePowerProfile === "power-saver") return "SAVER"
                        if (activePowerProfile === "balanced") return "BALANCED"
                        if (activePowerProfile === "performance") return "PERF"
                        return "PWR --"
                    }
                    color: {
                        if (activePowerProfile === "power-saver") return theme.green
                        if (activePowerProfile === "balanced") return theme.blue
                        if (activePowerProfile === "performance") return theme.red
                        return theme.fg0
                    }
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "powerProfileSelector", "toggle"])
                        } else if (mouse.button === Qt.RightButton) {
                            togglePowerProfile()
                        }
                    }
                }
            }

            // ライト/ダークモード切り替え
            Rectangle {
                id: themeRect
                color: theme.bg0
                radius: 6
                implicitWidth: themeText.implicitWidth + 20
                implicitHeight: 24

                Text {
                    id: themeText
                    anchors.centerIn: parent
                    text: theme.mode === "dark" ? "DARK" : "LIGHT"
                    color: theme.mode === "dark" ? theme.yellow : theme.blue
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    id: themeMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        themeMa.enabled = false;
                        debounceTimer.start();
                        theme.toggle();
                    }
                }

                Timer {
                    id: debounceTimer
                    interval: 1000
                    repeat: false
                    onTriggered: themeMa.enabled = true
                }
            }

            // バッテリー
            Rectangle {
                id: batRect
                color: theme.bg0
                radius: 6
                implicitWidth: batContent.implicitWidth + 20
                implicitHeight: 24

                property int batCapacity: -1
                property string batStatus: ""

                Row {
                    id: batContent
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        id: batText
                        text: batRect.batCapacity >= 0 ? batRect.batCapacity + "%" : "--%"
                        color: {
                            if (batRect.batStatus === "Charging" || batRect.batStatus === "Full") return theme.green
                            if (batRect.batCapacity >= 0 && batRect.batCapacity <= 20) return theme.red
                            return theme.fg0
                        }
                        font.bold: true
                        font.pixelSize: 12
                    }
                }
                Process {
                    id: batProcess
                    command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1) $(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)"]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.trim().split(" ")
                            let cap = parseInt(parts[0])
                            if (!isNaN(cap)) batRect.batCapacity = cap
                            if (parts[1]) batRect.batStatus = parts[1]
                        }
                    }
                }
                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: {
                        batProcess.running = false
                        batProcess.running = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "batteryInfo", "toggle"])
                    }
                }
            }

            // 通知ステーション
            Rectangle {
                id: notifStationBtn
                color: theme.bg0
                radius: 6
                implicitWidth: 85
                implicitHeight: 24

                Text {
                    id: notifStationText
                    anchors.centerIn: parent
                    text: "NOTIF " + shellRoot.notificationHistory.length
                    color: shellRoot.notificationHistory.length > 0 ? theme.yellow : theme.gray
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "notificationStation", "toggle"])
                    }
                }
            }

            // 通知カードの右マージンを時計幅から逆算してshellRootに伝える
            Binding {
                target: shellRoot
                property: "notifCardRightMargin"
                value: 15 + 8 + clockBackground.implicitWidth
            }

            // システムトレイカードの右マージンを計算してshellRootに伝える
            Binding {
                target: shellRoot
                property: "systrayCardRightMargin"
                value: {
                    let rWidth = 15 +
                        clockBackground.implicitWidth + 8 +
                        notifStationBtn.implicitWidth + 8 +
                        batRect.implicitWidth + 8 +
                        themeRect.implicitWidth + 8 +
                        pwrRect.implicitWidth + 8 +
                        wifiRoot.implicitWidth + 8 +
                        briRoot.implicitWidth + 8 +
                        volRect.implicitWidth + 8;
                    // Center the 170px wide systray card under the 24px wide button
                    return rWidth + 12 - 85;
                }
            }

            // 時計
            Rectangle {
                id: clockBackground
                color: theme.bg0
                radius: 6
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: 24

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    color: theme.fg0
                    font.bold: true
                    font.pixelSize: 12
                    text: Qt.formatDateTime(new Date(), "MM/dd HH:mm")

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "MM/dd HH:mm")
                    }
                }
            }
        }
    }
}
