// StatusBar.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    anchors {
        top: true
    }
    
    margins.top: 0
    implicitWidth: 1500
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
            color: "#1d2021" // Gruvbox背景
            radius: 12
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

                    color: isFocused ? "#282828" : "#32302f"
                  
                    Text {
                        anchors.centerIn: parent
                        text: parent.wsId.toString()
                        color: parent.isFocused ? "#fbf1c7" : "#928374"
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
                color: "#282828"
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
                    color: "#fbf1c7"
                    font.bold: true
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }

                // クリックで再生/一時停止
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (activePlayer) activePlayer.togglePlaying()
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
            color: "#282828"
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
                color: "#fbf1c7"
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

            // スピーカー音量
            Rectangle {
                color: "#282828"
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
                    color: "#fbf1c7"
                    font.bold: true
                    font.pixelSize: 12
                }

                // マウススクロールで音量を調整 / クリックでミュート切り替え
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        let sink = Pipewire.defaultAudioSink
                        if (sink && sink.audio) {
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
                color: "#282828"
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
                    color: "#fbf1c7"
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
                color: "#282828"
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
                    color: "#fbf1c7"
                    font.bold: true
                    font.pixelSize: 12
                }
            }

            // パワープロファイル
            Rectangle {
                color: "#282828"
                radius: 6
                implicitWidth: pwrText.implicitWidth + 20
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
                        if (activePowerProfile === "power-saver") return "#b8bb26" // Gruvbox Green
                        if (activePowerProfile === "balanced") return "#83a598" // Gruvbox Blue
                        if (activePowerProfile === "performance") return "#fb4934" // Gruvbox Red
                        return "#fbf1c7"
                    }
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: togglePowerProfile()
                }
            }

            // バッテリー
            Rectangle {
                color: "#282828"
                radius: 6
                implicitWidth: batContent.implicitWidth + 20
                implicitHeight: 24
                Row {
                    id: batContent
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        id: batText
                        text: "--%"
                        color: "#fbf1c7"
                        font.bold: true
                        font.pixelSize: 12
                    }
                }
                Process {
                    id: batProcess
                    command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: {
                            batText.text = this.text.trim() + "%"
                        }
                    }
                }
                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: {
                        batProcess.running = false
                        batProcess.running = true
                    }
                }
            }

            // 時計
            Rectangle {
                id: clockBackground
                color: "#282828" 
                radius: 6
                implicitWidth: clockText.implicitWidth + 20
                implicitHeight: 24

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    color: "#fbf1c7"
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
