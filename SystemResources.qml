// SystemResources.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: resourcesWindow
    anchors { top: true } // Center horizontally by only anchoring to top
    margins.top: 35
    implicitWidth: 680
    implicitHeight: 540
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    // Main states
    property bool active: false
    
    // Resource values
    property real cpuVal: 0.0
    property real ramUsed: 0.0
    property real ramTotal: 0.0
    property real ramPercent: 0.0
    property real diskUsed: 0.0
    property real diskTotal: 0.0
    property real diskPercent: 0.0
    property real netDown: 0.0
    property real netUp: 0.0
    property string uptimeStr: ""
    property string kernelStr: ""
    property string hostnameStr: ""
    property int cpuTemp: 0

    // Control Center states
    property bool wifiEnabled: false
    property bool bluetoothEnabled: false
    property bool nightLightEnabled: false
    property int brightnessVal: 50
    
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    
    property var audioSink: Pipewire.defaultAudioSink
    property var audioSource: Pipewire.defaultAudioSource

    property var activePlayer: {
        let count = Mpris.players.count
        let list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return list[0] ?? null
    }

    // Weather values
    property string weatherEmoji: "☀️"
    property real weatherTemp: 0.0
    property string weatherCity: "Loading..."
    property string weatherDesc: "Loading..."
    property int weatherCode: -1
    property var lastWeatherUpdate: null

    // Calendar Event properties
    property string selectedDateStr: "" // format "YYYY-MM-DD"
    property string selectedDateLabel: "" // format "M/D"
    property string selectedDateNote: "" // note text
    property var calendarEvents: ({}) // event dictionary
    property int viewedYear: new Date().getFullYear()
    property int viewedMonth: new Date().getMonth() // 0-based
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth()
    property int todayDay: new Date().getDate()

    onViewedYearChanged: updateCalendar()
    onViewedMonthChanged: updateCalendar()

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(resourcesWindow)
            resourcesWindow.visible = true
            slideAnimation.from = -resourcesWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
            
            // Populate dynamic panel elements on open
            let now = new Date()
            todayYear = now.getFullYear()
            todayMonth = now.getMonth()
            todayDay = now.getDate()
            
            viewedYear = todayYear
            viewedMonth = todayMonth
            
            let y = todayYear
            let m = String(todayMonth + 1).padStart(2, '0')
            let d = String(todayDay).padStart(2, '0')
            selectedDateStr = `${y}-${m}-${d}`
            selectedDateLabel = `${todayMonth + 1}/${todayDay}`
            
            loadCalendarEvents()
            loadWeather()
            loadTodos()
            
            // Refresh Control Center toggle states
            wifiStateProc.running = false
            wifiStateProc.running = true
            btStateProc.running = false
            btStateProc.running = true
            nlStateProc.running = false
            nlStateProc.running = true
            getBrightness()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -resourcesWindow.height - 20
            slideAnimation.start()
        }
    }

    onSelectedDateNoteChanged: {
        eventInput.text = selectedDateNote
    }

    Component.onCompleted: {
        let now = new Date()
        let y = now.getFullYear()
        let m = String(now.getMonth() + 1).padStart(2, '0')
        let d = String(now.getDate()).padStart(2, '0')
        selectedDateStr = `${y}-${m}-${d}`
        selectedDateLabel = `${now.getMonth() + 1}/${now.getDate()}`
    }

    NumberAnimation {
        id: slideAnimation
        target: container
        property: "y"
        duration: 150
        easing.type: Easing.OutExpo
        onFinished: {
            if (!active) {
                resourcesWindow.visible = false
            }
        }
    }

    // System resources polling daemon (runs only when active)
    Process {
        id: sysResourcesProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/system_resources.py"]
        running: resourcesWindow.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    let parsed = JSON.parse(data.trim())
                    cpuVal = parsed.cpu
                    ramUsed = parsed.ram_used
                    ramTotal = parsed.ram_total
                    ramPercent = parsed.ram_percent
                    cpuTemp = parsed.temp
                    diskUsed = parsed.disk_used
                    diskTotal = parsed.disk_total
                    diskPercent = parsed.disk_percent
                    netDown = parsed.net_down
                    netUp = parsed.net_up
                    uptimeStr = parsed.uptime
                    kernelStr = parsed.kernel
                    hostnameStr = parsed.hostname
                    
                    procModel.clear()
                    for (let i = 0; i < parsed.top_procs.length; i++) {
                        procModel.append(parsed.top_procs[i])
                    }
                } catch (e) {
                    console.log("Failed to parse system resources JSON. Error:", e, "Raw data:", data)
                }
            }
        }
    }

    // Weather fetcher process
    Process {
        id: weatherProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/weather_fetcher.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text.trim())
                    weatherEmoji = parsed.emoji
                    weatherTemp = parsed.temp
                    weatherCity = parsed.city
                    weatherDesc = parsed.desc
                    weatherCode = parsed.code
                    if (parsed.code !== -1) {
                        lastWeatherUpdate = new Date()
                    } else {
                        lastWeatherUpdate = null
                    }
                } catch (e) {
                    console.log("Failed to parse weather JSON:", e)
                }
            }
        }
    }

    // Helper function to update todo model from process stdout
    function updateTodoModel(text) {
        try {
            let parsed = JSON.parse(text.trim())
            todoModel.clear()
            for (let i = 0; i < parsed.length; i++) {
                todoModel.append(parsed[i])
            }
        } catch (e) {
            console.log("Failed to parse todo JSON:", e, "Raw output was:", text)
        }
    }

    // Todo manager processes
    Process {
        id: todoListProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/todo_manager.py", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: updateTodoModel(this.text)
        }
    }

    Process {
        id: todoAddProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: updateTodoModel(this.text)
        }
    }

    Process {
        id: todoToggleProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: updateTodoModel(this.text)
        }
    }

    Process {
        id: todoDeleteProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: updateTodoModel(this.text)
        }
    }

    Process {
        id: todoClearProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/todo_manager.py", "clear"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: updateTodoModel(this.text)
        }
    }

    // Calendar events process
    Process {
        id: calendarProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/calendar_manager.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text.trim())
                    calendarEvents = parsed
                    selectedDateNote = calendarEvents[selectedDateStr] || ""
                    updateCalendar() // Re-populate grid to refresh event dots
                } catch (e) {
                    console.log("Failed to parse calendar events JSON:", e)
                }
            }
        }
    }

    ListModel {
        id: procModel
    }

    ListModel {
        id: calendarModel
    }

    ListModel {
        id: todoModel
    }

    // Weather retrieval logic (10-minute cache)
    function loadWeather() {
        let now = new Date()
        if (!lastWeatherUpdate || (now - lastWeatherUpdate) > 600000) {
            weatherProc.running = false
            weatherProc.running = true
        }
    }

    // Todo functions
    function loadTodos() {
        todoListProc.running = false
        todoListProc.running = true
    }

    function addTodo(text) {
        todoAddProc.command = ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/todo_manager.py", "add", text]
        todoAddProc.running = false
        todoAddProc.running = true
    }

    function toggleTodo(id) {
        todoToggleProc.command = ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/todo_manager.py", "toggle", id.toString()]
        todoToggleProc.running = false
        todoToggleProc.running = true
    }

    function deleteTodo(id) {
        todoDeleteProc.command = ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/todo_manager.py", "delete", id.toString()]
        todoDeleteProc.running = false
        todoDeleteProc.running = true
    }

    function clearCompletedTodos() {
        todoClearProc.running = false
        todoClearProc.running = true
    }

    // Calendar events functions
    function loadCalendarEvents() {
        calendarProc.command = ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/calendar_manager.py", "list"]
        calendarProc.running = false
        calendarProc.running = true
    }

    function saveCalendarEvent(date, text) {
        calendarProc.command = ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/calendar_manager.py", "set", date, text]
        calendarProc.running = false
        calendarProc.running = true
    }

    // Wi-Fi state process
    Process {
        id: wifiStateProc
        command: ["nmcli", "radio", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let state = this.text.trim()
                wifiEnabled = (state === "enabled")
            }
        }
    }

    // Bluetooth state process
    Process {
        id: btStateProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                bluetoothEnabled = (this.text.trim() === "on")
            }
        }
    }

    // Night Light state process
    Process {
        id: nlStateProc
        command: ["pgrep", "-x", "wlsunset"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                nightLightEnabled = (this.text.trim() !== "")
            }
        }
    }

    // Brightness get process
    Process {
        id: briGetProc
        running: false
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(",")
                if (parts.length >= 4) {
                    let pctStr = parts[3].replace("%", "")
                    let pct = parseInt(pctStr, 10)
                    if (!isNaN(pct)) {
                        brightnessVal = pct
                    }
                }
            }
        }
    }

    // Brightness set process
    Process {
        id: briSetProc
        running: false
    }

    function getBrightness() {
        briGetProc.running = false
        briGetProc.running = true
    }

    function setBrightness(percentage) {
        briSetProc.command = ["brightnessctl", "set", percentage + "%"]
        briSetProc.running = false
        briSetProc.running = true
        brightnessVal = percentage
        // Notify StatusBar to update instantly
        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "statusBar", "updateBrightness", percentage.toString()])
    }

    function toggleWifi() {
        let target = wifiEnabled ? "off" : "on"
        Quickshell.execDetached(["nmcli", "radio", "wifi", target])
        wifiEnabled = !wifiEnabled
    }

    function toggleBluetooth() {
        let target = bluetoothEnabled ? "off" : "on"
        Quickshell.execDetached(["bluetoothctl", "power", target])
        bluetoothEnabled = !bluetoothEnabled
    }

    function toggleAudioMute() {
        let sink = audioSink
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted
        }
    }

    function toggleMicMute() {
        let source = audioSource
        if (source && source.audio) {
            source.audio.muted = !source.audio.muted
        }
    }

    function toggleDnd() {
        shellRoot.dndEnabled = !shellRoot.dndEnabled
    }

    function toggleNightLight() {
        if (nightLightEnabled) {
            Quickshell.execDetached(["pkill", "-x", "wlsunset"])
            nightLightEnabled = false
        } else {
            Quickshell.execDetached(["wlsunset", "-T", "4000"])
            nightLightEnabled = true
        }
    }

    // Calendar generation logic
    function updateCalendar() {
        calendarModel.clear()
        let year = viewedYear
        let month = viewedMonth
        
        let firstDay = new Date(year, month, 1)
        let startDayOfWeek = firstDay.getDay()
        let daysInMonth = new Date(year, month + 1, 0).getDate()
        let prevDaysInMonth = new Date(year, month, 0).getDate()
        
        // Prev month padding
        for (let i = startDayOfWeek - 1; i >= 0; i--) {
            let pYear = month === 0 ? year - 1 : year
            let pMonth = month === 0 ? 11 : month - 1
            let pDay = prevDaysInMonth - i
            let pKey = `${pYear}-${String(pMonth + 1).padStart(2, '0')}-${String(pDay).padStart(2, '0')}`
            let pHasEvent = calendarEvents[pKey] ? true : false
            
            calendarModel.append({
                day: pDay,
                isCurrentMonth: false,
                isToday: (pYear === todayYear && pMonth === todayMonth && pDay === todayDay),
                dateStr: pKey,
                hasEvent: pHasEvent
            })
        }
        
        // Current month days
        for (let day = 1; day <= daysInMonth; day++) {
            let dateKey = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
            let hasEvent = calendarEvents[dateKey] ? true : false
            
            calendarModel.append({
                day: day,
                isCurrentMonth: true,
                isToday: (year === todayYear && month === todayMonth && day === todayDay),
                dateStr: dateKey,
                hasEvent: hasEvent
            })
        }
        
        // Next month padding
        let totalCells = 42
        let remaining = totalCells - calendarModel.count
        for (let day = 1; day <= remaining; day++) {
            let nYear = month === 11 ? year + 1 : year
            let nMonth = month === 11 ? 0 : month + 1
            let nKey = `${nYear}-${String(nMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
            let nHasEvent = calendarEvents[nKey] ? true : false
            
            calendarModel.append({
                day: day,
                isCurrentMonth: false,
                isToday: (nYear === todayYear && nMonth === todayMonth && day === todayDay),
                dateStr: nKey,
                hasEvent: nHasEvent
            })
        }
    }

    function nextMonth() {
        if (viewedMonth === 11) {
            viewedYear += 1
            viewedMonth = 0
        } else {
            viewedMonth += 1
        }
    }
    
    function prevMonth() {
        if (viewedMonth === 0) {
            viewedYear -= 1
            viewedMonth = 11
        } else {
            viewedMonth -= 1
        }
    }
    
    function jumpToToday() {
        let now = new Date()
        todayYear = now.getFullYear()
        todayMonth = now.getMonth()
        todayDay = now.getDate()
        viewedYear = todayYear
        viewedMonth = todayMonth
        
        let y = todayYear
        let m = String(todayMonth + 1).padStart(2, '0')
        let d = String(todayDay).padStart(2, '0')
        selectedDateStr = `${y}-${m}-${d}`
        selectedDateLabel = `${todayMonth + 1}/${todayDay}`
        selectedDateNote = calendarEvents[selectedDateStr] || ""
    }

    IpcHandler {
        target: "systemResources"
        property bool active: resourcesWindow.active
        function toggle(): void {
            resourcesWindow.active = !resourcesWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: resourcesWindow.active

        Keys.onEscapePressed: {
            resourcesWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                resourcesWindow.active = false
            }
        }

        // Card container (Gruvbox theme, same shape as other cards, borderless)
        Canvas {
            id: cardBg
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: theme
                function onModeChanged() {
                    cardBg.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = theme.bg0_hard;

                var R = 16; // radius
                var w = width;
                var h = height;

                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.arc(w, R, R, 1.5 * Math.PI, 1.0 * Math.PI, true);
                ctx.lineTo(w - R, h - R);
                ctx.arc(w - 2*R, h - R, R, 0, 0.5 * Math.PI, false);
                ctx.lineTo(2*R, h);
                ctx.arc(2*R, h - R, R, 0.5 * Math.PI, 1.0 * Math.PI, false);
                ctx.lineTo(R, R);
                ctx.arc(0, R, R, 0, 1.5 * Math.PI, true);
                ctx.closePath();
                ctx.fill();
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {} // Intercept clicks
            }

            // Safe content area
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.bottomMargin: 20
                anchors.leftMargin: 26
                anchors.rightMargin: 26
                spacing: 12

                // 1. Header: Hostname, Kernel, Uptime
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: hostnameStr.toUpperCase()
                        color: theme.fg1
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "Monospace"
                    }
                    
                    Text {
                        text: "•"
                        color: theme.fg4
                        font.pixelSize: 11
                    }
                    
                    Text {
                        text: kernelStr
                        color: theme.fg3
                        font.pixelSize: 11
                        font.family: "Monospace"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: "UPTIME: " + uptimeStr
                        color: theme.fg4
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                    }
                }
                
                // Horizontal divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.bg1
                }

                // Bento 0: Quick Toggles & Sliders (Control Center)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 85
                    color: theme.bg0_soft
                    radius: 8
                    border.color: theme.bg1
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 16
                        
                        // 1. Quick Toggles Grid (Left)
                        Grid {
                            columns: 6
                            spacing: 8
                            Layout.alignment: Qt.AlignVCenter
                            
                            // Wi-Fi
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: wifiEnabled ? theme.blue : theme.bg0
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: wifiEnabled ? "󰤨" : "󰤭"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: wifiEnabled ? theme.bg0_soft : theme.fg4
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleWifi()
                                }
                            }
                            
                            // Bluetooth
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: bluetoothEnabled ? theme.purple : theme.bg0
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: bluetoothEnabled ? "󰂯" : "󰂲"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: bluetoothEnabled ? theme.bg0_soft : theme.fg4
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleBluetooth()
                                }
                            }
                            
                            // Audio Mute
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: (audioSink && audioSink.audio && audioSink.audio.muted) ? theme.red : theme.green
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: (audioSink && audioSink.audio && audioSink.audio.muted) ? "󰝟" : "󰓃"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: theme.bg0_soft
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleAudioMute()
                                }
                            }
                            
                            // Mic Mute
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: (audioSource && audioSource.audio && audioSource.audio.muted) ? theme.red : theme.yellow
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: (audioSource && audioSource.audio && audioSource.audio.muted) ? "󰍭" : "󰍬"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: theme.bg0_soft
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleMicMute()
                                }
                            }
                            
                            // DND
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: shellRoot.dndEnabled ? theme.orange : theme.bg0
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂛"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: shellRoot.dndEnabled ? theme.bg0_soft : theme.fg4
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleDnd()
                                }
                            }
                            
                            // Night Light
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: nightLightEnabled ? theme.orange : theme.bg0
                                border.color: theme.bg1; border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖔"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    color: nightLightEnabled ? theme.bg0_soft : theme.fg4
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleNightLight()
                                }
                            }
                        }
                        
                        // Vertical divider
                        Rectangle {
                            Layout.fillHeight: true
                            width: 1
                            color: theme.bg1
                        }
                        
                        // 2. Sliders (Right)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8
                            
                            // Volume Slider Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                Text {
                                    text: "󰓃"
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: theme.fg2
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 16
                                }
                                
                                // Slider Track
                                Rectangle {
                                    id: ccVolTrack
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 4
                                    color: theme.bg0
                                    border.color: theme.bg1; border.width: 1
                                    
                                    property real volRatio: {
                                        let sink = audioSink
                                        if (!sink || !sink.audio) return 0.0
                                        return Math.max(0.0, Math.min(1.0, sink.audio.volume))
                                    }
                                    
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * parent.volRatio
                                        radius: 4
                                        color: (audioSink && audioSink.audio && audioSink.audio.muted) ? theme.gray : theme.blue
                                    }
                                    
                                    Rectangle {
                                        x: (parent.width * parent.volRatio) - (width / 2)
                                        y: (parent.height / 2) - (height / 2)
                                        width: 12; height: 12; radius: 6
                                        color: ccVolMa.containsMouse ? theme.fg1 : theme.fg3
                                        border.color: theme.bg0_hard; border.width: 2
                                    }
                                    
                                    MouseArea {
                                        id: ccVolMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        
                                        function updateVal(mouse) {
                                            let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                            let sink = audioSink
                                            if (sink && sink.audio) {
                                                sink.audio.volume = ratio
                                                if (ratio > 0.0 && sink.audio.muted) {
                                                    sink.audio.muted = false
                                                }
                                            }
                                        }
                                        onPressed: mouse => updateVal(mouse)
                                        onPositionChanged: mouse => { if (pressed) updateVal(mouse) }
                                    }
                                }
                                
                                Text {
                                    text: {
                                        let sink = audioSink
                                        if (!sink || !sink.audio) return "0%"
                                        if (sink.audio.muted) return "MUT"
                                        return Math.round(sink.audio.volume * 100) + "%"
                                    }
                                    color: theme.fg3
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                            
                            // Brightness Slider Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                Text {
                                    text: "󰖨"
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: theme.fg2
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 16
                                }
                                
                                // Slider Track
                                Rectangle {
                                    id: ccBriTrack
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 4
                                    color: theme.bg0
                                    border.color: theme.bg1; border.width: 1
                                    
                                    property real briRatio: brightnessVal / 100.0
                                    
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * parent.briRatio
                                        radius: 4
                                        color: theme.yellow
                                    }
                                    
                                    Rectangle {
                                        x: (parent.width * parent.briRatio) - (width / 2)
                                        y: (parent.height / 2) - (height / 2)
                                        width: 12; height: 12; radius: 6
                                        color: ccBriMa.containsMouse ? theme.fg1 : theme.fg3
                                        border.color: theme.bg0_hard; border.width: 2
                                    }
                                    
                                    MouseArea {
                                        id: ccBriMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        
                                        function updateVal(mouse) {
                                            let pct = Math.round(Math.max(0.0, Math.min(1.0, mouse.x / width)) * 100)
                                            setBrightness(pct)
                                        }
                                        onPressed: mouse => updateVal(mouse)
                                        onPositionChanged: mouse => { if (pressed) updateVal(mouse) }
                                    }
                                }
                                
                                Text {
                                    text: brightnessVal + "%"
                                    color: theme.fg3
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "Monospace"
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                // 2. Main content: Left and Right Bento Columns
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // --- LEFT COLUMN: Resources & Processes ---
                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 12

                        // Bento 1: Resources Monitor
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 145
                            color: theme.bg0_soft
                            radius: 8
                            border.color: theme.bg1
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                // CPU Row
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "CPU"; color: theme.fg2; font.pixelSize: 11; font.bold: true; font.family: "Monospace" }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: cpuVal.toFixed(1) + "% (" + cpuTemp + "°C)"
                                            color: cpuVal > 80.0 ? theme.red : (cpuVal > 50.0 ? theme.yellow : theme.blue)
                                            font.pixelSize: 11; font.bold: true; font.family: "Monospace"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 8; radius: 4; color: theme.bg0
                                        border.color: theme.bg1; border.width: 1
                                        Rectangle {
                                            height: parent.height; width: parent.width * (cpuVal / 100.0); radius: 4
                                            color: cpuVal > 80.0 ? theme.red : (cpuVal > 50.0 ? theme.yellow : theme.blue)
                                            Behavior on width { NumberAnimation { duration: 150 } }
                                        }
                                    }
                                }

                                // RAM Row
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "RAM"; color: theme.fg2; font.pixelSize: 11; font.bold: true; font.family: "Monospace" }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: ramPercent.toFixed(1) + "% (" + ramUsed.toFixed(1) + "G/" + ramTotal.toFixed(0) + "G)"
                                            color: ramPercent > 85.0 ? theme.red : (ramPercent > 65.0 ? theme.yellow : theme.green)
                                            font.pixelSize: 11; font.bold: true; font.family: "Monospace"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 8; radius: 4; color: theme.bg0
                                        border.color: theme.bg1; border.width: 1
                                        Rectangle {
                                            height: parent.height; width: parent.width * (ramPercent / 100.0); radius: 4
                                            color: ramPercent > 85.0 ? theme.red : (ramPercent > 65.0 ? theme.yellow : theme.green)
                                            Behavior on width { NumberAnimation { duration: 150 } }
                                        }
                                    }
                                }

                                // Disk Row
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "DISK"; color: theme.fg2; font.pixelSize: 11; font.bold: true; font.family: "Monospace" }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: diskPercent.toFixed(1) + "% (" + diskUsed.toFixed(0) + "G/" + diskTotal.toFixed(0) + "G)"
                                            color: theme.purple
                                            font.pixelSize: 11; font.bold: true; font.family: "Monospace"
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 8; radius: 4; color: theme.bg0
                                        border.color: theme.bg1; border.width: 1
                                        Rectangle {
                                            height: parent.height; width: parent.width * (diskPercent / 100.0); radius: 4
                                            color: theme.purple
                                            Behavior on width { NumberAnimation { duration: 150 } }
                                        }
                                    }
                                }

                                // Net stats
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    RowLayout {
                                        spacing: 5
                                        Text { text: "▼"; color: theme.aqua; font.pixelSize: 11 }
                                        Text {
                                            text: netDown > 1024.0 ? (netDown / 1024.0).toFixed(1) + "M/s" : netDown.toFixed(1) + "K/s"
                                            color: theme.fg3; font.pixelSize: 11; font.family: "Monospace"
                                        }
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                    RowLayout {
                                        spacing: 5
                                        Text { text: "▲"; color: theme.orange; font.pixelSize: 11 }
                                        Text {
                                            text: netUp > 1024.0 ? (netUp / 1024.0).toFixed(1) + "M/s" : netUp.toFixed(1) + "K/s"
                                            color: theme.fg3; font.pixelSize: 11; font.family: "Monospace"
                                        }
                                    }
                                }
                            }
                        }

                        // Bento 5: Music Player
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 85
                            color: theme.bg0_soft
                            radius: 8
                            border.color: theme.bg1
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                // Album Art (Left)
                                Rectangle {
                                    width: 60
                                    height: 60
                                    radius: 6
                                    color: theme.bg0
                                    border.color: theme.bg1
                                    border.width: 1
                                    Layout.alignment: Qt.AlignVCenter
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰎆"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 24
                                        color: theme.fg4
                                        visible: !albumArtImage.visible
                                    }
                                    
                                    Image {
                                        id: albumArtImage
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: activePlayer && activePlayer.trackArtUrl !== ""
                                    }
                                }
                                
                                // Metadata & Controls (Right)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    
                                    // Title & Artist
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        
                                        Text {
                                            text: activePlayer ? activePlayer.trackTitle : "Nothing playing"
                                            color: theme.fg0
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Monospace"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        
                                        Text {
                                            text: activePlayer ? activePlayer.trackArtist : "Unknown Artist"
                                            color: theme.fg3
                                            font.pixelSize: 9
                                            font.family: "Monospace"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                    
                                    // Playback controls row
                                    RowLayout {
                                        spacing: 12
                                        Layout.alignment: Qt.AlignLeft
                                        
                                        // Prev
                                        Text {
                                            text: "󰒮"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 16
                                            color: (activePlayer && activePlayer.canGoPrevious) ? (prevMa.containsMouse ? theme.fg1 : theme.fg3) : theme.gray
                                            
                                            MouseArea {
                                                id: prevMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                enabled: activePlayer && activePlayer.canGoPrevious
                                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: activePlayer.previous()
                                            }
                                        }
                                        
                                        // Play / Pause
                                        Text {
                                            text: (activePlayer && activePlayer.isPlaying) ? "󰏤" : "󰐊"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 20
                                            color: activePlayer ? (playPauseMa.containsMouse ? theme.fg1 : theme.fg2) : theme.gray
                                            
                                            MouseArea {
                                                id: playPauseMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                enabled: activePlayer !== null
                                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: activePlayer.togglePlaying()
                                            }
                                        }
                                        
                                        // Next
                                        Text {
                                            text: "󰒭"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 16
                                            color: (activePlayer && activePlayer.canGoNext) ? (nextMa.containsMouse ? theme.fg1 : theme.fg3) : theme.gray
                                            
                                            MouseArea {
                                                id: nextMa
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                enabled: activePlayer && activePlayer.canGoNext
                                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: activePlayer.next()
                                            }
                                        }
                                        
                                        // Player source identity label
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: activePlayer ? activePlayer.identity.toLowerCase() : ""
                                            color: theme.fg4
                                            font.pixelSize: 8
                                            font.family: "Monospace"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        // Bento 2: Processes
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: theme.bg0_soft
                            radius: 8
                            border.color: theme.bg1
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Text {
                                    text: "TOP PROCESSES (CPU)"
                                    color: theme.fg4
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "Monospace"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: procModel
                                        delegate: RowLayout {
                                            Layout.fillWidth: true
                                            
                                            Text {
                                                text: model.name
                                                color: theme.fg2
                                                font.pixelSize: 11
                                                font.family: "Monospace"
                                                elide: Text.ElideRight
                                                Layout.preferredWidth: 110
                                            }
                                            
                                            Item { Layout.fillWidth: true }
                                            
                                            Text {
                                                text: "CPU " + model.cpu.toFixed(0) + "%"
                                                color: model.cpu > 50.0 ? theme.red : theme.fg3
                                                font.pixelSize: 11
                                                font.family: "Monospace"
                                                Layout.preferredWidth: 55
                                                horizontalAlignment: Text.AlignRight
                                            }
                                            
                                            Text {
                                                text: "MEM " + model.mem.toFixed(0) + "%"
                                                color: theme.fg4
                                                font.pixelSize: 11
                                                font.family: "Monospace"
                                                Layout.preferredWidth: 55
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- RIGHT COLUMN: Weather/Calendar & To-Do memo ---
                    ColumnLayout {
                        Layout.preferredWidth: 320
                        Layout.fillHeight: true
                        spacing: 12

                        // Bento 3: Weather, Calendar & Agenda Note
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            color: {
                                let isDark = theme.mode === "dark";
                                let code = weatherCode;
                                if (code === 0 || code === 1 || code === 2) {
                                    // Sunny / Warm (Orange-Yellow tint)
                                    return isDark ? "#322d29" : "#fbf2e6";
                                } else if ((code >= 51 && code <= 65) || (code >= 80 && code <= 82) || code === 95) {
                                    // Rainy / Drizzle / Storm (Aqua-Blue tint)
                                    return isDark ? "#28302f" : "#edf7f5";
                                } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
                                    // Snowy / Cold (Purple tint)
                                    return isDark ? "#2c2a32" : "#f1edf7";
                                } else if (code === 3 || code === 45 || code === 48) {
                                    // Cloudy / Foggy (Gray tint)
                                    return isDark ? "#2e3032" : "#f2f2f5";
                                } else {
                                    // Default
                                    return theme.bg0_soft;
                                }
                            }
                            radius: 8
                            border.color: {
                                let code = weatherCode;
                                if (code === 0 || code === 1 || code === 2) {
                                    return theme.orange;
                                } else if ((code >= 51 && code <= 65) || (code >= 80 && code <= 82) || code === 95) {
                                    return theme.aqua;
                                } else if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
                                    return theme.purple;
                                } else if (code === 3 || code === 45 || code === 48) {
                                    return theme.fg4;
                                } else {
                                    return theme.bg1;
                                }
                            }
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                // Row 1: Weather & Calendar
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 10

                                    // Weather (Left)
                                    ColumnLayout {
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            text: weatherEmoji
                                            font.pixelSize: 32
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: weatherTemp.toFixed(1) + "°C"
                                            color: theme.fg1
                                            font.pixelSize: 18
                                            font.bold: true
                                            font.family: "Monospace"
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: weatherDesc
                                            color: theme.fg2
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Monospace"
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: weatherCity
                                            color: theme.fg4
                                            font.pixelSize: 11
                                            font.family: "Monospace"
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: 100
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    // Vertical Separator
                                    Rectangle {
                                        Layout.fillHeight: true
                                        width: 1
                                        color: theme.bg1
                                    }

                                    // Calendar (Right)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 6
                                        Layout.alignment: Qt.AlignVCenter

                                        // Calendar Header with month navigation
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            
                                            // Dummy element to balance the "今日" button and keep title centered
                                            Item {
                                                width: 26
                                                height: 16
                                                visible: (viewedYear !== todayYear || viewedMonth !== todayMonth)
                                            }

                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 3
                                                color: prevHover.containsMouse ? theme.bg1 : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "◀"
                                                    color: prevHover.containsMouse ? theme.fg1 : theme.fg4
                                                    font.pixelSize: 8
                                                }
                                                
                                                MouseArea {
                                                    id: prevHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: prevMonth()
                                                }
                                            }
                                            
                                            Text {
                                                Layout.fillWidth: true
                                                text: `${viewedYear}年 ${viewedMonth + 1}月`
                                                color: theme.fg2
                                                font.pixelSize: 10
                                                font.bold: true
                                                font.family: "Monospace"
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 3
                                                color: nextHover.containsMouse ? theme.bg1 : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "▶"
                                                    color: nextHover.containsMouse ? theme.fg1 : theme.fg4
                                                    font.pixelSize: 8
                                                }
                                                
                                                MouseArea {
                                                    id: nextHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: nextMonth()
                                                }
                                            }

                                            // Today Button
                                            Rectangle {
                                                width: 26
                                                height: 16
                                                radius: 3
                                                color: todayBtnHover.containsMouse ? theme.bg1 : "transparent"
                                                visible: (viewedYear !== todayYear || viewedMonth !== todayMonth)
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "今日"
                                                    color: todayBtnHover.containsMouse ? theme.fg1 : theme.fg4
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                                
                                                MouseArea {
                                                    id: todayBtnHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: jumpToToday()
                                                }
                                            }
                                        }

                                        Grid {
                                            columns: 7
                                            spacing: 3
                                            Layout.alignment: Qt.AlignHCenter
                                            
                                            Repeater {
                                                model: ["日", "月", "火", "水", "木", "金", "土"]
                                                delegate: Text {
                                                    text: modelData
                                                    color: modelData === "日" ? theme.red : (modelData === "土" ? theme.blue : theme.fg4)
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    width: 22
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                            
                                            Repeater {
                                                model: calendarModel
                                                delegate: Rectangle {
                                                    width: 22
                                                    height: 15
                                                    radius: 3
                                                    color: model.isToday ? theme.yellow : "transparent"
                                                    border.color: (selectedDateStr === model.dateStr) ? theme.blue : "transparent"
                                                    border.width: (selectedDateStr === model.dateStr) ? 1.5 : 0
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: model.day
                                                        color: model.isToday ? theme.bg0_hard : (model.isCurrentMonth ? theme.fg1 : theme.fg4)
                                                        font.pixelSize: 10
                                                        font.bold: model.isToday
                                                        font.family: "Monospace"
                                                    }

                                                    // Event dot indicator
                                                    Rectangle {
                                                        width: 3
                                                        height: 3
                                                        radius: 1.5
                                                        color: theme.green
                                                        visible: model.hasEvent
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 1
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            let parts = model.dateStr.split('-')
                                                            let clickedYear = parseInt(parts[0], 10)
                                                            let clickedMonth = parseInt(parts[1], 10) - 1 // 0-indexed
                                                            
                                                            selectedDateStr = model.dateStr
                                                            selectedDateLabel = parseInt(parts[1], 10) + "/" + parseInt(parts[2], 10)
                                                            selectedDateNote = calendarEvents[model.dateStr] || ""
                                                            
                                                            if (clickedYear !== viewedYear || clickedMonth !== viewedMonth) {
                                                                viewedYear = clickedYear
                                                                viewedMonth = clickedMonth
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Separator
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: theme.bg1
                                }

                                // Row 2: Selected Day Event Note Editor
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: "📅 " + selectedDateLabel + " 予定:"
                                        color: theme.fg2
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "Monospace"
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 20
                                        color: theme.bg0
                                        radius: 4
                                        border.color: eventInput.activeFocus ? theme.blue : theme.bg1
                                        border.width: 1
                                        
                                        TextInput {
                                            id: eventInput
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: clearBtn.visible ? 20 : 6
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: theme.fg1
                                            font.pixelSize: 10
                                            font.family: "Monospace"
                                            selectByMouse: true
                                            text: selectedDateNote
                                            
                                            Text {
                                                text: "予定なし"
                                                color: theme.fg4
                                                font.pixelSize: 10
                                                font.family: "Monospace"
                                                visible: !parent.text && !parent.activeFocus
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onAccepted: {
                                                saveCalendarEvent(selectedDateStr, text.trim())
                                                focus = false
                                            }
                                        }
                                        
                                        Item {
                                            id: clearBtn
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: 20
                                            visible: eventInput.text !== ""
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: theme.red
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    eventInput.text = ""
                                                    saveCalendarEvent(selectedDateStr, "")
                                                    eventInput.focus = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bento 4: To-Do Memo
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: theme.bg0_soft
                            radius: 8
                            border.color: theme.bg1
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "TO-DO MEMO"
                                        color: theme.fg4
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "Monospace"
                                    }
                                    Item { Layout.fillWidth: true }
                                    
                                    // Sized container to ensure a large, reliable click target
                                    Item {
                                        width: 60
                                        height: 20
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 20
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "🧹 CLEAR"
                                            color: theme.red
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.family: "Monospace"
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                console.log("[Todo] Clicking CLEAR completed")
                                                clearCompletedTodos()
                                            }
                                        }
                                    }
                                }

                                // Todo List ScrollView
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    
                                    ColumnLayout {
                                        width: parent.availableWidth
                                        spacing: 4
                                        
                                        Repeater {
                                            model: todoModel
                                            delegate: RowLayout {
                                                Layout.fillWidth: true
                                                Layout.rightMargin: 12
                                                spacing: 8
                                                
                                                Item {
                                                    width: 20
                                                    height: 20
                                                    Layout.preferredWidth: 20
                                                    Layout.preferredHeight: 20
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 12; height: 12; radius: 3
                                                        color: model.completed ? theme.green : "transparent"
                                                        border.color: model.completed ? theme.green : (model.priority === 3 ? theme.red : (model.priority === 2 ? theme.yellow : (model.priority === 1 ? theme.blue : theme.fg4)))
                                                        border.width: 1
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: model.completed ? "✓" : ""
                                                            color: theme.bg0_soft
                                                            font.bold: true
                                                            font.pixelSize: 10
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            console.log("[Todo] Clicking toggle for ID:", model.id)
                                                            toggleTodo(model.id)
                                                        }
                                                    }
                                                }

                                                // Priority dot indicator
                                                Rectangle {
                                                    width: 5; height: 5; radius: 2.5
                                                    color: model.priority === 3 ? theme.red : (model.priority === 2 ? theme.yellow : theme.blue)
                                                    visible: model.priority > 0 && !model.completed
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                                
                                                Text {
                                                    text: model.text
                                                    color: model.completed ? theme.fg4 : theme.fg1
                                                    font.pixelSize: 11
                                                    font.family: "Monospace"
                                                    font.strikeout: model.completed
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            console.log("[Todo] Clicking text toggle for ID:", model.id)
                                                            toggleTodo(model.id)
                                                        }
                                                    }
                                                }
                                                
                                                Item {
                                                    width: 20
                                                    height: 20
                                                    Layout.preferredWidth: 20
                                                    Layout.preferredHeight: 20
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: theme.red
                                                        font.bold: true
                                                        font.pixelSize: 13
                                                    }
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            console.log("[Todo] Clicking delete for ID:", model.id)
                                                            deleteTodo(model.id)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Input Field
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    color: theme.bg0
                                    radius: 4
                                    border.color: todoInput.activeFocus ? theme.yellow : theme.bg1
                                    border.width: 1
                                    
                                    TextInput {
                                        id: todoInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: theme.fg1
                                        font.pixelSize: 11
                                        font.family: "Monospace"
                                        selectByMouse: true
                                        
                                        Text {
                                            text: "新しいタスクを入力..."
                                            color: theme.fg4
                                            font.pixelSize: 11
                                            font.family: "Monospace"
                                            visible: !parent.text && !parent.activeFocus
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onAccepted: {
                                            if (text.trim() !== "") {
                                                addTodo(text.trim())
                                                text = ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
