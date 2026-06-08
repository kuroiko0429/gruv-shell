// WallpaperHud.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: wallpaperHud
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    SystemClock { id: sysClock; precision: SystemClock.Minutes }

    // ── システムリソース取得用 ────────────────────────────────────
    property real _prevIdle:  0
    property real _prevTotal: 0
    property int  cpuPercent: 0
    property real ramGb:      0.0
    property real ramTotal:   16.0

    // ディスク容量用
    property real diskUsedGb: 0.0
    property real diskTotalGb: 0.0
    property real diskPercent: 0.0

    // ネットワーク・温度・メモ用
    property real _prevRx: 0
    property real _prevTx: 0
    property string rxSpeedStr: "0.0 KB/s"
    property string txSpeedStr: "0.0 KB/s"
    property int cpuTemp: 0

    // ── 天気データ取得 ─────────────────────────────────────
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherHum: ""
    property string weatherWind: ""
    property int _weatherRetryCount: 0
    property int _weatherRetryMax: 3

    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "10", "wttr.in/Nishinopporo?format=j1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let json = JSON.parse(this.text)
                        if (json && json.current_condition && json.current_condition.length > 0) {
                            let cond = json.current_condition[0]
                            weatherTemp = cond.temp_C || ""
                            weatherHum = cond.humidity || ""
                            weatherWind = cond.windspeedKmph || ""
                            if (cond.weatherDesc && cond.weatherDesc.length > 0) {
                                weatherDesc = cond.weatherDesc[0].value || ""
                            }
                            // 成功: リトライカウントをリセット
                            wallpaperHud._weatherRetryCount = 0
                        } else {
                            wallpaperHud._scheduleWeatherRetry()
                        }
                    } else {
                        wallpaperHud._scheduleWeatherRetry()
                    }
                } catch(e) {
                    console.log("Error parsing weather JSON: ", e)
                    wallpaperHud._scheduleWeatherRetry()
                }
            }
        }
    }

    function _scheduleWeatherRetry() {
        if (_weatherRetryCount < _weatherRetryMax) {
            _weatherRetryCount++
            // 指数バックオフ: 30s, 60s, 120s
            weatherRetryTimer.interval = 30000 * _weatherRetryCount
            weatherRetryTimer.restart()
        }
        // 失敗上限を超えたら30分の通常サイクルに任せる
    }

    Timer {
        id: weatherRetryTimer
        repeat: false
        running: false
        onTriggered: {
            weatherProc.running = false
            weatherProc.running = true
        }
    }

    Timer {
        interval: 1800000 // 30分ごとに天気を更新
        running: true
        repeat: true
        onTriggered: {
            wallpaperHud._weatherRetryCount = 0
            weatherProc.running = false
            weatherProc.running = true
        }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        let kb = bytesPerSec / 1024
        if (kb < 1024) return kb.toFixed(1) + " KB/s"
        let mb = kb / 1024
        return mb.toFixed(1) + " MB/s"
    }

    function formatUptime(totalSecs) {
        let days = Math.floor(totalSecs / 86400)
        let hours = Math.floor((totalSecs % 86400) / 3600)
        let mins = Math.floor((totalSecs % 3600) / 60)
        
        let res = ""
        if (days > 0) res += days + "d "
        if (hours > 0 || days > 0) res += hours + "h "
        res += mins + "m"
        return res
    }

    readonly property string uptimeStr: formatUptime(uptimeSecs)

    Process {
        id: statsProc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; cat /proc/net/dev | grep -v -E '(lo|face|bytes)' | awk '{rx+=$2; tx+=$10} END {print \"net\", rx, tx}'; temp_val=\"\"; for f in /sys/class/thermal/thermal_zone*; do if [ -f \"$f/type\" ] && [ \"$(cat \"$f/type\")\" = \"x86_pkg_temp\" ]; then temp_val=$(cat \"$f/temp\"); break; fi; done; if [ -z \"$temp_val\" ] && [ -f /sys/class/thermal/thermal_zone0/temp ]; then temp_val=$(cat /sys/class/thermal/thermal_zone0/temp); fi; echo \"temp $temp_val\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                let memTotal = 0, memAvail = 0
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (!line) continue
                    if (line.startsWith("cpu ")) {
                        let p = line.split(/\s+/)
                        if (p.length < 5) continue
                        let user    = parseFloat(p[1])
                        let nice    = parseFloat(p[2])
                        let system  = parseFloat(p[3])
                        let idle    = parseFloat(p[4])
                        let iowait  = parseFloat(p[5]) || 0

                        let totalIdle = idle + iowait
                        let totalBusy = user + nice + system
                        let total     = totalIdle + totalBusy

                        let diffTotal = total - wallpaperHud._prevTotal
                        let diffIdle  = totalIdle - wallpaperHud._prevIdle
                        if (diffTotal > 0 && wallpaperHud._prevTotal > 0)
                            wallpaperHud.cpuPercent = Math.round((diffTotal - diffIdle) / diffTotal * 100)
                        wallpaperHud._prevIdle  = totalIdle
                        wallpaperHud._prevTotal = total
                    } else if (line.startsWith("MemTotal:")) {
                        let m = line.match(/:\s*(\d+)/)
                        if (m) memTotal = parseInt(m[1])
                    } else if (line.startsWith("MemAvailable:")) {
                        let m = line.match(/:\s*(\d+)/)
                        if (m) memAvail = parseInt(m[1])
                    } else if (line.startsWith("net ")) {
                        let p = line.split(/\s+/)
                        if (p.length >= 3) {
                            let rx = parseFloat(p[1]) || 0
                            let tx = parseFloat(p[2]) || 0
                            if (wallpaperHud._prevRx > 0 && wallpaperHud._prevTx > 0) {
                                let rxSpeed = (rx - wallpaperHud._prevRx) / 3
                                let txSpeed = (tx - wallpaperHud._prevTx) / 3
                                wallpaperHud.rxSpeedStr = wallpaperHud.formatSpeed(Math.max(0, rxSpeed))
                                wallpaperHud.txSpeedStr = wallpaperHud.formatSpeed(Math.max(0, txSpeed))
                            }
                            wallpaperHud._prevRx = rx
                            wallpaperHud._prevTx = tx
                        }
                    } else if (line.startsWith("temp ")) {
                        let p = line.split(/\s+/)
                        if (p.length >= 2) {
                            let rawTemp = parseFloat(p[1]) || 0
                            if (rawTemp > 0) {
                                wallpaperHud.cpuTemp = Math.round(rawTemp / 1000)
                            }
                        }
                    }
                }
                if (memTotal > 0) {
                    wallpaperHud.ramTotal = memTotal / 1048576
                    wallpaperHud.ramGb = (memTotal - memAvail) / 1048576
                }
            }
        }
    }



    // ── Uptime & RPG レベル ────────────────────────────────────
    property int playerLevel: 1
    property int uptimeSecs: 0
    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(/\s+/)
                if (parts.length > 0) {
                    let s = parseFloat(parts[0]) || 0
                    wallpaperHud.uptimeSecs = Math.round(s)
                    wallpaperHud.playerLevel = Math.floor(wallpaperHud.uptimeSecs / 3600) + 1
                }
            }
        }
    }

    // ── バッテリー ───────────────────────────────────────
    property var batteryDevice: UPower.displayDevice
    readonly property real batteryPct: (batteryDevice?.percentage ?? 0.0) * 100

    Process {
        id: diskProc
        command: ["df", "-B1", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 2) {
                    let parts = lines[1].trim().split(/\s+/)
                    if (parts.length >= 5) {
                        let total = parseInt(parts[1]) || 0
                        let used = parseInt(parts[2]) || 0
                        if (total > 0) {
                            wallpaperHud.diskTotalGb = total / 1073741824
                            wallpaperHud.diskUsedGb = used / 1073741824
                            wallpaperHud.diskPercent = Math.round(used / total * 100)
                        }
                    }
                }
            }
        }
    }



    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            statsProc.running = true
            uptimeProc.running = true
        }
    }

    Timer {
        id: diskTimer
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            diskProc.running = false
            diskProc.running = true
        }
    }

    // ── カレンダーロジック ───────────────────────────────────────
    property var daysInMonth: [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    function getDays(year, month) {
        let isLeap = (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0)
        let days = wallpaperHud.daysInMonth[month]
        if (month === 1 && isLeap) days = 29
        return days
    }

    property var calendarModel: {
        let now = sysClock.date
        let year = now.getFullYear()
        let month = now.getMonth()
        let today = now.getDate()
        let firstDay = new Date(year, month, 1).getDay()
        let days = wallpaperHud.getDays(year, month)
        
        let res = []
        for (let i = 0; i < firstDay; i++) {
            res.push({ day: 0, isToday: false })
        }
        for (let d = 1; d <= days; d++) {
            res.push({ day: d, isToday: (d === today) })
        }
        return res
    }

    // 壁紙のあみあみ (40px)
    Canvas {
        id: gridCanvas
        anchors {
            top: parent.top
            topMargin: 35
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        z: -2 // Conkyの背景カードより下に描画されるようにする
        opacity: 0.1 // 壁紙を邪魔しない淡いグリッド
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: theme
            function onModeChanged() {
                gridCanvas.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = theme.fg1; // 手前の文字と同系色の極細線
            ctx.lineWidth = 0.5;

            var step = 40; // グリッドの間隔 (40px)

            // 縦線
            for (var x = step; x < width; x += step) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            // 横線
            for (var y = step; y < height; y += step) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
    }

    // ── HUD コーナーブラケット ───────────────────
    Item {
        anchors {
            top: parent.top
            topMargin: 75 // 35px statusbar offset + 40px margin
            bottom: parent.bottom
            bottomMargin: 40
            left: parent.left
            leftMargin: 40
            right: parent.right
            rightMargin: 40
        }
        z: -1

        // 左上
        Rectangle { x: 0; y: 0; width: 24; height: 2; color: theme.bg1 }
        Rectangle { x: 0; y: 0; width: 2; height: 24; color: theme.bg1 }

        // 右上
        Rectangle { x: parent.width - 24; y: 0; width: 24; height: 2; color: theme.bg1 }
        Rectangle { x: parent.width - 2; y: 0; width: 2; height: 24; color: theme.bg1 }

        // 左下
        Rectangle { x: 0; y: parent.height - 2; width: 24; height: 2; color: theme.bg1 }
        Rectangle { x: 0; y: parent.height - 24; width: 2; height: 24; color: theme.bg1 }

        // 右下
        Rectangle { x: parent.width - 24; y: parent.height - 2; width: 24; height: 2; color: theme.bg1 }
        Rectangle { x: parent.width - 2; y: parent.height - 24; width: 2; height: 24; color: theme.bg1 }
    }

    // ── メインレイアウト (画面の右側奥に美しく配置) ───────────────
    Item {
        anchors {
            right: parent.right
            rightMargin: 60
            top: parent.top
            topMargin: 130
            bottom: parent.bottom
            bottomMargin: 100
        }
        width: 320

        // 半透明フロストガラスカード背景
        Rectangle {
            anchors.fill: parent
            anchors.margins: -16
            radius: 16
            color: Qt.rgba(theme.bg0.r, theme.bg0.g, theme.bg0.b, 0.4)
            border.color: Qt.rgba(theme.fg0.r, theme.fg0.g, theme.fg0.b, 0.05)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 24

            // ① 巨大背景時計
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: Qt.formatDateTime(sysClock.date, "HH:mm")
                    color: theme.fg1
                    font.pixelSize: 84
                    font.bold: true
                    font.family: "sans-serif"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: theme.green
                        
                        SequentialAnimation on color {
                            loops: Animation.Infinite
                            ColorAnimation { to: theme.green; duration: 800 }
                            ColorAnimation { to: "transparent"; duration: 800 }
                        }
                    }

                    Text {
                        text: "ZONE SECURE // ONLINE"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        font.family: "Monospace"
                    }
                }

                Text {
                    text: Qt.formatDateTime(sysClock.date, "yyyy年 MM月dd日 dddd")
                    color: theme.fg3
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "UPTIME: " + wallpaperHud.uptimeStr
                    color: theme.fg4
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Monospace"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.bg1
            }

            // ② システムステータス
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14

                // BATTERY
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Text { text: "BATTERY"; color: theme.fg4; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace" }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(wallpaperHud.batteryPct) + "%"; color: wallpaperHud.batteryPct < 20 ? theme.red : theme.fg2; font.pixelSize: 10; font.family: "Monospace" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 3; color: theme.bg0; radius: 1.5
                        Rectangle {
                            width: parent.width * (wallpaperHud.batteryPct / 100.0)
                            height: parent.height; radius: 1.5
                            color: wallpaperHud.batteryPct < 20 ? theme.red : theme.fg1
                        }
                    }
                }

                // CPU
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Text { text: "CPU"; color: theme.fg4; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace" }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: (wallpaperHud.cpuTemp > 0 ? (wallpaperHud.cpuTemp + "°C @ ") : "") + wallpaperHud.cpuPercent + "%"
                            color: wallpaperHud.cpuPercent > 70 ? theme.yellow : theme.fg2
                            font.pixelSize: 10
                            font.family: "Monospace" 
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 3; color: theme.bg0; radius: 1.5
                        Rectangle {
                            width: parent.width * (wallpaperHud.cpuPercent / 100.0)
                            height: parent.height; radius: 1.5
                            color: wallpaperHud.cpuPercent > 70 ? theme.yellow : theme.fg1
                        }
                    }
                }

                // RAM
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Text { text: "RAM"; color: theme.fg4; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace" }
                        Item { Layout.fillWidth: true }
                        Text { text: wallpaperHud.ramGb.toFixed(1) + "G / " + wallpaperHud.ramTotal.toFixed(0) + "G"; color: theme.fg2; font.pixelSize: 10; font.family: "Monospace" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 3; color: theme.bg0; radius: 1.5
                        Rectangle {
                            width: parent.width * (wallpaperHud.ramGb / wallpaperHud.ramTotal)
                            height: parent.height; radius: 1.5
                            color: theme.fg1
                        }
                    }
                }

                // DISK
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Text { text: "DISK"; color: theme.fg4; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace" }
                        Item { Layout.fillWidth: true }
                        Text { text: wallpaperHud.diskUsedGb.toFixed(1) + "G / " + wallpaperHud.diskTotalGb.toFixed(0) + "G"; color: theme.fg2; font.pixelSize: 10; font.family: "Monospace" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 3; color: theme.bg0; radius: 1.5
                        Rectangle {
                            width: parent.width * (wallpaperHud.diskPercent / 100.0)
                            height: parent.height; radius: 1.5
                            color: theme.fg1
                        }
                    }
                }

                // NETWORK SPEED
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Text { text: "NETWORK"; color: theme.fg4; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace" }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: "DN " + wallpaperHud.rxSpeedStr + "  UP " + wallpaperHud.txSpeedStr
                            color: theme.fg2
                            font.pixelSize: 10
                            font.family: "Monospace" 
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.bg1
            }

            // ②.5 天気ステータス (絵文字なしのクリーンなデザイン)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: wallpaperHud.weatherTemp !== ""

                Text {
                    text: "ENVIRONMENTAL WEATHER"
                    color: theme.fg4
                    font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Text {
                        text: wallpaperHud.weatherTemp + "°C"
                        color: theme.fg1
                        font.pixelSize: 24
                        font.bold: true
                        font.family: "Monospace"
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: wallpaperHud.weatherDesc.toUpperCase()
                            color: theme.yellow
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "Monospace"
                        }
                        Text {
                            text: "WIND: " + wallpaperHud.weatherWind + " km/h  |  HUMIDITY: " + wallpaperHud.weatherHum + "%"
                            color: theme.fg4
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.bg1
                visible: wallpaperHud.weatherTemp !== ""
            }

            // ③ フラットデスクトップカレンダー
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "CHRONICLE CALENDAR"
                    color: theme.fg4
                    font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: ["日", "月", "火", "水", "木", "金", "土"]
                        delegate: Text {
                            text: modelData
                            color: index === 0 ? theme.red : (index === 6 ? theme.blue : theme.fg3)
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }

                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    rowSpacing: 8
                    columnSpacing: 0

                    Repeater {
                        model: wallpaperHud.calendarModel
                        delegate: Item {
                            Layout.fillWidth: true
                            height: 20

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.color: theme.yellow
                                border.width: 1
                                visible: modelData.isToday
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day > 0 ? modelData.day : ""
                                color: modelData.isToday 
                                    ? theme.yellow 
                                    : (modelData.day > 0 ? theme.fg3 : "transparent")
                                font.pixelSize: 11
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }



            Item { Layout.fillHeight: true }
        }
    }
}
