// BrightnessSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: brightnessWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 440 // Align under the brightness pill
    implicitWidth: 260
    implicitHeight: 120
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property int brightnessVal: 50

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(brightnessWindow)
            brightnessWindow.visible = true
            getBrightness()
            slideAnimation.from = -brightnessWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -brightnessWindow.height - 20
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
                brightnessWindow.visible = false
            }
        }
    }

    Process {
        id: briGetProc
        running: false
        command: ["sh", "-c", "cat /sys/class/backlight/intel_backlight/brightness /sys/class/backlight/intel_backlight/max_brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 2) {
                    let cur = parseInt(lines[0])
                    let max = parseInt(lines[1])
                    if (!isNaN(cur) && !isNaN(max) && max > 0) {
                        brightnessWindow.brightnessVal = Math.round(cur / max * 100)
                    }
                }
            }
        }
    }

    Process {
        id: briSetProc
        running: false
    }

    function getBrightness() {
        briGetProc.running = false
        briGetProc.running = true
    }

    function setBrightness(percentage) {
        briSetProc.exec(["brightnessctl", "set", percentage + "%"])
        // Notify StatusBar to update instantly
        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "statusBar", "updateBrightness", percentage.toString()])
    }

    IpcHandler {
        target: "brightnessSelector"
        function toggle(): void {
            brightnessWindow.active = !brightnessWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: brightnessWindow.active

        Keys.onEscapePressed: {
            brightnessWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                brightnessWindow.active = false
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
                        text: "SCREEN BRIGHTNESS"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        font.family: "Monospace"
                    }
                }

                // Info & Slider Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: brightnessWindow.brightnessVal + "%"
                        color: theme.yellow
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Monospace"
                        Layout.preferredWidth: 40
                    }

                    // Custom Slider Track
                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        height: 8
                        radius: 4
                        color: theme.bg0
                        border.color: theme.bg1
                        border.width: 1

                        // Fill
                        Rectangle {
                            height: parent.height
                            width: parent.width * (brightnessWindow.brightnessVal / 100.0)
                            radius: 4
                            color: theme.yellow
                        }

                        // Handle
                        Rectangle {
                            x: (parent.width * (brightnessWindow.brightnessVal / 100.0)) - (width / 2)
                            y: (parent.height / 2) - (height / 2)
                            width: 14
                            height: 14
                            radius: 7
                            color: sliderMa.containsMouse ? theme.fg1 : theme.fg3
                            border.color: theme.bg0_hard
                            border.width: 2

                            Behavior on x {
                                enabled: !sliderMa.pressed
                                NumberAnimation { duration: 100 }
                            }
                        }

                        MouseArea {
                            id: sliderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true

                            function updateValue(mouse) {
                                let percentage = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                brightnessWindow.brightnessVal = percentage
                                setBrightness(percentage)
                            }

                            onPressed: mouse => updateValue(mouse)
                            onPositionChanged: mouse => {
                                if (pressed) updateValue(mouse)
                            }
                        }
                    }
                }
            }
        }
    }
}
