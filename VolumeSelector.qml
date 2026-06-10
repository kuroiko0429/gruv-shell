// VolumeSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: volumeWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 350 // Align under the volume pill
    implicitWidth: 260
    implicitHeight: 120
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(volumeWindow)
            volumeWindow.visible = true
            slideAnimation.from = -volumeWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -volumeWindow.height - 20
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
                volumeWindow.visible = false
            }
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property var audioSink: Pipewire.defaultAudioSink

    IpcHandler {
        target: "volumeSelector"
        function toggle(): void {
            volumeWindow.active = !volumeWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: volumeWindow.active

        Keys.onEscapePressed: {
            volumeWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                volumeWindow.active = false
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
                        text: "AUDIO VOLUME"
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
                        text: {
                            let sink = volumeWindow.audioSink
                            if (!sink || !sink.audio) return "0%"
                            if (sink.audio.muted) return "MUT"
                            return Math.round(sink.audio.volume * 100) + "%"
                        }
                        color: {
                            let sink = volumeWindow.audioSink
                            if (sink && sink.audio && sink.audio.muted) return theme.red
                            return theme.blue
                        }
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

                        property real volumeRatio: {
                            let sink = volumeWindow.audioSink
                            if (!sink || !sink.audio) return 0.0
                            return Math.max(0.0, Math.min(1.0, sink.audio.volume))
                        }

                        // Fill
                        Rectangle {
                            height: parent.height
                            width: parent.width * parent.volumeRatio
                            radius: 4
                            color: {
                                let sink = volumeWindow.audioSink
                                if (sink && sink.audio && sink.audio.muted) return theme.gray
                                return theme.blue
                            }
                        }

                        // Handle
                        Rectangle {
                            x: (parent.width * parent.volumeRatio) - (width / 2)
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
                                let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                let sink = volumeWindow.audioSink
                                if (sink && sink.audio) {
                                    sink.audio.volume = ratio
                                    if (ratio > 0.0 && sink.audio.muted) {
                                        sink.audio.muted = false
                                    }
                                }
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
