// OSD.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: osdWindow
    anchors { bottom: true } // Center horizontally by anchoring to bottom
    margins.bottom: 100
    implicitWidth: 240
    implicitHeight: 40
    color: "transparent"
    visible: contentContainer.opacity > 0.0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    exclusionMode: ExclusionMode.Ignore

    property string mode: "volume" // "volume" or "brightness"
    property int valueVal: 0
    property bool isMuted: false

    // Timer to automatically hide OSD
    Timer {
        id: hideTimer
        interval: 1500
        repeat: false
        onTriggered: {
            contentContainer.opacity = 0.0
        }
    }

    function triggerOSD(newMode, newValue, newMuted) {
        mode = newMode
        valueVal = newValue
        isMuted = newMuted
        
        // Show and reset timer
        contentContainer.opacity = 0.85
        hideTimer.restart()
    }

    // Pipewire volume tracking
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    
    property var audioSink: Pipewire.defaultAudioSink
    property real lastVolume: -1.0
    property bool lastMuted: false
    property bool isInitialized: false

    Connections {
        target: audioSink ? audioSink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (!audioSink || !audioSink.audio) return
            let vol = audioSink.audio.volume
            let muted = audioSink.audio.muted
            let pct = Math.round(vol * 100)
            
            if (isInitialized) {
                if (pct !== Math.round(lastVolume * 100) || muted !== lastMuted) {
                    triggerOSD("volume", pct, muted)
                }
            } else {
                isInitialized = true
            }
            lastVolume = vol
            lastMuted = muted
        }
        function onMutedChanged() {
            if (!audioSink || !audioSink.audio) return
            let vol = audioSink.audio.volume
            let muted = audioSink.audio.muted
            let pct = Math.round(vol * 100)
            
            if (isInitialized) {
                triggerOSD("volume", pct, muted)
            }
            lastVolume = vol
            lastMuted = muted
        }
    }

    // Brightness watcher process
    property int lastBrightness: -1
    property bool isBriInitialized: false

    Process {
        id: briWatchProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/brightness_watcher.py"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let val = parseInt(data.trim(), 10)
                if (!isNaN(val)) {
                    if (isBriInitialized) {
                        if (val !== lastBrightness) {
                            triggerOSD("brightness", val, false)
                        }
                    } else {
                        isBriInitialized = true
                    }
                    lastBrightness = val
                }
            }
        }
    }

    // Styled Container (Gruvbox aesthetic, semi-transparent)
    Rectangle {
        id: contentContainer
        anchors.fill: parent
        color: theme.bg0_hard
        radius: 8
        border.color: theme.bg1
        border.width: 1
        
        opacity: 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            // Icon
            Text {
                text: {
                    if (osdWindow.mode === "volume") {
                        return osdWindow.isMuted ? "󰝟" : "󰓃"
                    } else {
                        return "󰖨"
                    }
                }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: {
                    if (osdWindow.mode === "volume") {
                        return osdWindow.isMuted ? theme.red : theme.blue
                    } else {
                        return theme.yellow
                    }
                }
                Layout.alignment: Qt.AlignVCenter
            }

            // Slider Track
            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: theme.bg0
                border.color: theme.bg1
                border.width: 1
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    height: parent.height
                    width: parent.width * (osdWindow.valueVal / 100.0)
                    radius: 3
                    color: {
                        if (osdWindow.mode === "volume") {
                            return osdWindow.isMuted ? theme.gray : theme.blue
                        } else {
                            return theme.yellow
                        }
                    }
                }
            }

            // Percentage Text
            Text {
                text: osdWindow.isMuted && osdWindow.mode === "volume" ? "MUT" : osdWindow.valueVal + "%"
                color: theme.fg2
                font.pixelSize: 10
                font.bold: true
                font.family: "Monospace"
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
