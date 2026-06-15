import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 115
    color: theme.bg0_soft
    radius: 8
    border.color: theme.bg1
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        // 1. Quick Toggles Grid (Left)
        Grid {
            columns: 3
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            // Wi-Fi
            Rectangle {
                width: 44; height: 44; radius: 22
                color: resourcesWindow.wifiEnabled ? theme.blue : theme.bg0
                border.color: theme.bg1; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: resourcesWindow.wifiEnabled ? "󰤨" : "󰤭"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: resourcesWindow.wifiEnabled ? theme.bg0_soft : theme.fg4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resourcesWindow.toggleWifi()
                }
            }

            // Bluetooth
            Rectangle {
                width: 44; height: 44; radius: 22
                color: resourcesWindow.bluetoothEnabled ? theme.purple : theme.bg0
                border.color: theme.bg1; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: resourcesWindow.bluetoothEnabled ? "󰂯" : "󰂲"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: resourcesWindow.bluetoothEnabled ? theme.bg0_soft : theme.fg4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resourcesWindow.toggleBluetooth()
                }
            }

            // Audio Mute
            Rectangle {
                width: 44; height: 44; radius: 22
                color: (resourcesWindow.audioSink && resourcesWindow.audioSink.audio && resourcesWindow.audioSink.audio.muted) ? theme.red : theme.green
                border.color: theme.bg1; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: (resourcesWindow.audioSink && resourcesWindow.audioSink.audio && resourcesWindow.audioSink.audio.muted) ? "󰝟" : "󰓃"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: theme.bg0_soft
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resourcesWindow.toggleAudioMute()
                }
            }

            // Mic Mute
            Rectangle {
                width: 44; height: 44; radius: 22
                color: (resourcesWindow.audioSource && resourcesWindow.audioSource.audio && resourcesWindow.audioSource.audio.muted) ? theme.red : theme.yellow
                border.color: theme.bg1; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: (resourcesWindow.audioSource && resourcesWindow.audioSource.audio && resourcesWindow.audioSource.audio.muted) ? "󰍭" : "󰍬"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: theme.bg0_soft
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resourcesWindow.toggleMicMute()
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
                    onClicked: resourcesWindow.toggleDnd()
                }
            }

            // Night Light
            Rectangle {
                width: 44; height: 44; radius: 22
                color: resourcesWindow.nightLightEnabled ? theme.orange : theme.bg0
                border.color: theme.bg1; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰖔"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: resourcesWindow.nightLightEnabled ? theme.bg0_soft : theme.fg4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: resourcesWindow.toggleNightLight()
                }
            }
        }

        // 2. Sliders (Right)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // Volume Slider Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰓃"
                    font.family: "JetBrainsMono Nerd Font"
                    color: theme.fg2
                    font.pixelSize: 13
                    Layout.preferredWidth: 14
                }

                Rectangle {
                    id: ccVolTrack
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: theme.bg0
                    border.color: theme.bg1; border.width: 1

                    property real volRatio: {
                        let sink = resourcesWindow.audioSink
                        if (!sink || !sink.audio) return 0.0
                        return Math.max(0.0, Math.min(1.0, sink.audio.volume))
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width * parent.volRatio
                        radius: 3
                        color: (resourcesWindow.audioSink && resourcesWindow.audioSink.audio && resourcesWindow.audioSink.audio.muted) ? theme.gray : theme.blue
                    }

                    Rectangle {
                        x: (parent.width * parent.volRatio) - (width / 2)
                        y: (parent.height / 2) - (height / 2)
                        width: 10; height: 10; radius: 5
                        color: ccVolMa.containsMouse ? theme.fg1 : theme.fg3
                        border.color: theme.bg0_hard; border.width: 1.5
                    }

                    MouseArea {
                        id: ccVolMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true

                        function updateVal(mouse) {
                            let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                            let sink = resourcesWindow.audioSink
                            if (sink && sink.audio) {
                                sink.audio.volume = ratio
                                if (ratio > 0.0 && sink.audio.muted) {
                                    sink.audio.muted = false
                                }
                            }
                        }

                        onPressed: (mouse) => updateVal(mouse)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateVal(mouse)
                        }
                    }
                }

                Text {
                    text: {
                        let sink = resourcesWindow.audioSink
                        if (!sink || !sink.audio) return "0%"
                        if (sink.audio.muted) return "M"
                        return Math.round(sink.audio.volume * 100) + "%"
                    }
                    color: theme.fg3
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "Monospace"
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Brightness Slider Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰖨"
                    font.family: "JetBrainsMono Nerd Font"
                    color: theme.fg2
                    font.pixelSize: 13
                    Layout.preferredWidth: 14
                }

                Rectangle {
                    id: ccBriTrack
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: theme.bg0
                    border.color: theme.bg1; border.width: 1

                    property real briRatio: resourcesWindow.brightnessVal / 100.0

                    Rectangle {
                        height: parent.height
                        width: parent.width * parent.briRatio
                        radius: 3
                        color: theme.yellow
                    }

                    Rectangle {
                        x: (parent.width * parent.briRatio) - (width / 2)
                        y: (parent.height / 2) - (height / 2)
                        width: 10; height: 10; radius: 5
                        color: ccBriMa.containsMouse ? theme.fg1 : theme.fg3
                        border.color: theme.bg0_hard; border.width: 1.5
                    }

                    MouseArea {
                        id: ccBriMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true

                        function updateVal(mouse) {
                            let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                            resourcesWindow.setBrightness(Math.round(ratio * 100))
                        }

                        onPressed: (mouse) => updateVal(mouse)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateVal(mouse)
                        }
                    }
                }

                Text {
                    text: resourcesWindow.brightnessVal + "%"
                    color: theme.fg3
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "Monospace"
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
