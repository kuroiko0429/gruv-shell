// PowerProfileSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: powerProfileWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 220 // Align under the power profile pill
    implicitWidth: 280
    implicitHeight: 170
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property string activeProfile: "balanced"

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(powerProfileWindow)
            powerProfileWindow.visible = true
            getProfile()
            slideAnimation.from = -powerProfileWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -powerProfileWindow.height - 20
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
                powerProfileWindow.visible = false
            }
        }
    }

    Process {
        id: getProfileProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                powerProfileWindow.activeProfile = this.text.trim()
            }
        }
    }

    Process {
        id: setProfileProc
    }

    function getProfile() {
        getProfileProc.running = false
        getProfileProc.running = true
    }

    function setProfile(profileName) {
        let msg = ""
        if (profileName === "power-saver") {
            msg = "「省電力 (Power Saver)」に切り替えました"
        } else if (profileName === "balanced") {
            msg = "「標準 (Balanced)」に切り替えました"
        } else if (profileName === "performance") {
            msg = "「パフォーマンス (Performance)」に切り替えました"
        }

        let cmd = "powerprofilesctl set " + profileName + " && notify-send -h string:x-canonical-private-synchronous:power-profile -u low '電源プロファイル' '" + msg + "'"
        setProfileProc.exec(["sh", "-c", cmd])
        
        powerProfileWindow.activeProfile = profileName
        
        // Notify StatusBar to update instantly
        Quickshell.execDetached(["quickshell", "ipc", "-p", "/home/kuroiko/.config/quickshell/kuroiko_bar/", "call", "statusBar", "updatePowerProfile", profileName])

        powerProfileWindow.active = false // Close after selection
    }

    IpcHandler {
        target: "powerProfileSelector"
        function toggle(): void {
            powerProfileWindow.active = !powerProfileWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: powerProfileWindow.active

        Keys.onEscapePressed: {
            powerProfileWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                powerProfileWindow.active = false
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
                        text: "POWER PROFILE SELECTOR"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        font.family: "Monospace"
                    }
                }

                // Profile Buttons (3 buttons vertical)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // SAVER Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 6
                        color: powerProfileWindow.activeProfile === "power-saver" ? theme.green : (saverMa.containsMouse ? theme.bg0_soft : theme.bg0)
                        border.color: powerProfileWindow.activeProfile === "power-saver" ? theme.green : theme.bg1
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "SAVER"
                            color: powerProfileWindow.activeProfile === "power-saver" ? theme.bg0_hard : theme.fg1
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: saverMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setProfile("power-saver")
                        }
                    }

                    // BALANCED Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 6
                        color: powerProfileWindow.activeProfile === "balanced" ? theme.blue : (balancedMa.containsMouse ? theme.bg0_soft : theme.bg0)
                        border.color: powerProfileWindow.activeProfile === "balanced" ? theme.blue : theme.bg1
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "BALANCED"
                            color: powerProfileWindow.activeProfile === "balanced" ? theme.bg0_hard : theme.fg1
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: balancedMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setProfile("balanced")
                        }
                    }

                    // PERFORMANCE Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 6
                        color: powerProfileWindow.activeProfile === "performance" ? theme.red : (perfMa.containsMouse ? theme.bg0_soft : theme.bg0)
                        border.color: powerProfileWindow.activeProfile === "performance" ? theme.red : theme.bg1
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "PERFORMANCE"
                            color: powerProfileWindow.activeProfile === "performance" ? theme.bg0_hard : theme.fg1
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: perfMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setProfile("performance")
                        }
                    }
                }
            }
        }
    }
}
