// MusicPlayer.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: musicPlayerWindow
    anchors { top: true; left: true }
    margins.top: 35
    margins.left: 231 // Align under the music pill
    implicitWidth: 320
    implicitHeight: 180
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property var cavaValues: [0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    Process {
        id: cavaProcess
        command: ["cava", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/cava.conf"]
        running: musicPlayerWindow.active
        stdout: SplitParser {
            onRead: data => {
                let text = data.trim();
                if (!text) return;
                let parts = text.split(/\s+/);
                let vals = [];
                for (let i = 0; i < parts.length; i++) {
                    vals.push(parseInt(parts[i]) || 0);
                }
                musicPlayerWindow.cavaValues = vals;
            }
        }
    }

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(musicPlayerWindow)
            musicPlayerWindow.visible = true
            slideAnimation.from = -musicPlayerWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -musicPlayerWindow.height - 20
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
                musicPlayerWindow.visible = false
            }
        }
    }

    property var activePlayer: {
        let count = Mpris.players.count
        let list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return list[0] ?? null
    }

    IpcHandler {
        target: "musicPlayer"
        function toggle(): void {
            musicPlayerWindow.active = !musicPlayerWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: musicPlayerWindow.active

        Keys.onEscapePressed: {
            musicPlayerWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                musicPlayerWindow.active = false
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
                        text: activePlayer ? activePlayer.identity.toUpperCase() : "NO ACTIVE PLAYER"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 2
                        font.family: "Monospace"
                    }
                }

                // Track Info Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Album Art
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 6
                        color: theme.bg0
                        border.color: theme.bg1
                        border.width: 1

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: activePlayer && activePlayer.trackArtUrl
                        }
                    }

                    // Metadata Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: activePlayer ? activePlayer.trackTitle : "Nothing playing"
                            color: theme.fg0
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "Monospace"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: activePlayer ? activePlayer.trackArtist : "Unknown Artist"
                            color: theme.fg3
                            font.pixelSize: 10
                            font.family: "Monospace"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // Visualizer Row
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    Row {
                        anchors.fill: parent
                        spacing: 4

                        Repeater {
                            model: 14
                            Rectangle {
                                width: (parent.width - 52) / 14
                                anchors.bottom: parent.bottom
                                height: Math.max(2, (musicPlayerWindow.cavaValues && musicPlayerWindow.cavaValues[index] !== undefined) ? musicPlayerWindow.cavaValues[index] : 0)
                                color: theme.aqua
                                radius: 2
                            }
                        }
                    }
                }

                // Controls Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // PREV Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: prevMa.containsMouse ? theme.bg0_soft : theme.bg0
                        border.color: theme.bg1
                        border.width: 1
                        enabled: activePlayer && activePlayer.canGoPrevious

                        Text {
                            anchors.centerIn: parent
                            text: "PREV"
                            color: parent.enabled ? theme.fg1 : theme.gray
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (activePlayer) activePlayer.previous()
                            }
                        }
                    }

                    // PLAY / PAUSE Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: playMa.containsMouse ? theme.bg0_soft : theme.bg0
                        border.color: theme.bg1
                        border.width: 1
                        enabled: activePlayer !== null

                        Text {
                            anchors.centerIn: parent
                            text: activePlayer && activePlayer.isPlaying ? "PAUSE" : "PLAY"
                            color: parent.enabled ? theme.fg1 : theme.gray
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (activePlayer) activePlayer.togglePlaying()
                            }
                        }
                    }

                    // NEXT Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: nextMa.containsMouse ? theme.bg0_soft : theme.bg0
                        border.color: theme.bg1
                        border.width: 1
                        enabled: activePlayer && activePlayer.canGoNext

                        Text {
                            anchors.centerIn: parent
                            text: "NEXT"
                            color: parent.enabled ? theme.fg1 : theme.gray
                            font.bold: true
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (activePlayer) activePlayer.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
