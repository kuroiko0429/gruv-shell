// BatteryInfo.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: batteryInfoWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 100 // Align under the battery pill
    implicitWidth: 240
    implicitHeight: 200
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property var batData: ({
        "state": "unknown",
        "power": "0.0 W",
        "time": "unknown",
        "time_type": "unknown",
        "percentage": "--%",
        "health": "--%"
    })

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(batteryInfoWindow)
            batteryInfoWindow.visible = true
            updateInfo()
            slideAnimation.from = -batteryInfoWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -batteryInfoWindow.height - 20
            slideAnimation.start()
        }
    }

    NumberAnimation {
        id: slideAnimation
        target: container
        property: "y"
        duration: 150
        easing.type: Easing.OutExpo
        onFinished: {
            if (!active) {
                batteryInfoWindow.visible = false
            }
        }
    }

    Process {
        id: batInfoProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/battery_info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    batteryInfoWindow.batData = JSON.parse(this.text.trim())
                } catch (e) {
                    console.log("Failed to parse battery data", e)
                }
            }
        }
    }

    function updateInfo() {
        batInfoProc.running = false
        batInfoProc.running = true
    }

    Timer {
        interval: 10000 // Refresh every 10 seconds while open
        running: batteryInfoWindow.active
        repeat: true
        onTriggered: updateInfo()
    }

    IpcHandler {
        target: "batteryInfo"
        function toggle(): void {
            batteryInfoWindow.active = !batteryInfoWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: batteryInfoWindow.active

        Keys.onEscapePressed: {
            batteryInfoWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                batteryInfoWindow.active = false
            }
        }

        // Card container (Concave corner top, rounded bottom)
        Canvas {
            id: card
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: theme
                function onModeChanged() {
                    card.requestPaint();
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

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.leftMargin: 32 // Offset the concave corner width
                anchors.rightMargin: 32 // Offset the concave corner width
                anchors.bottomMargin: 16
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "BATTERY DIAGNOSTICS"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        font.family: "Monospace"
                    }
                }

                // Main Reading (Percentage and State)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: batteryInfoWindow.batData.percentage
                            color: theme.fg0
                            font.pixelSize: 28
                            font.bold: true
                            font.family: "Monospace"
                        }
                        Text {
                            text: batteryInfoWindow.batData.state.toUpperCase()
                            color: {
                                let s = batteryInfoWindow.batData.state
                                if (s === "charging") return theme.green
                                if (s === "discharging") return theme.yellow
                                return theme.fg3
                            }
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Monospace"
                        }
                    }
                }

                // Divider line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.bg1
                }

                // Grid stats
                GridLayout {
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 16
                    Layout.fillWidth: true

                    // Row 1: Power rate
                    Text {
                        text: "POWER USE"
                        color: theme.fg4
                        font.pixelSize: 9
                        font.family: "Monospace"
                    }
                    Text {
                        text: batteryInfoWindow.batData.power
                        color: theme.fg1
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                        Layout.alignment: Qt.AlignRight
                    }

                    // Row 2: Remaining / charging time
                    Text {
                        text: {
                            let type = batteryInfoWindow.batData.time_type
                            if (type === "remaining") return "TIME REMAIN"
                            if (type === "to_full") return "TIME TO FULL"
                            return "TIME INFO"
                        }
                        color: theme.fg4
                        font.pixelSize: 9
                        font.family: "Monospace"
                    }
                    Text {
                        text: {
                            let t = batteryInfoWindow.batData.time
                            if (t === "unknown" || !t) return "N/A"
                            return t.toUpperCase()
                        }
                        color: theme.fg1
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                        Layout.alignment: Qt.AlignRight
                    }

                    // Row 3: Health
                    Text {
                        text: "HEALTH"
                        color: theme.fg4
                        font.pixelSize: 9
                        font.family: "Monospace"
                    }
                    Text {
                        text: {
                            let h = batteryInfoWindow.batData.health
                            if (!h || h === "--%") return "N/A"
                            let val = parseFloat(h)
                            return isNaN(val) ? h : Math.round(val) + "%"
                        }
                        color: theme.fg1
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }
    }
}
