// Powermenu.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: powermenuWindow
    anchors { top: true; left: true; right: true }
    margins.top: 35
    implicitHeight: 180
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property int currentIndex: 0

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(powermenuWindow)
            powermenuWindow.visible = true
            slideAnimation.from = -powermenuWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -powermenuWindow.height - 20
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
                powermenuWindow.visible = false
            }
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            powermenuWindow.active = !powermenuWindow.active
        }
    }

    function runAction(cmd) {
        powermenuWindow.active = false
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function triggerAction(idx) {
        if (idx === 0) {
            runAction("bash ~/.config/quickshell/kuroiko_bar/lock.sh")
        } else if (idx === 1) {
            runAction("hyprctl dispatch exit")
        } else if (idx === 2) {
            runAction("hyprctl dispatch dpms off")
        } else if (idx === 3) {
            runAction("systemctl suspend")
        } else if (idx === 4) {
            runAction("systemctl hibernate")
        } else if (idx === 5) {
            runAction("systemctl reboot")
        } else if (idx === 6) {
            runAction("systemctl poweroff")
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20 // Initial state is out of view

        focus: powermenuWindow.active

        Keys.onEscapePressed: {
            powermenuWindow.active = false
        }

        Keys.onLeftPressed: (event) => {
            let step = (event.modifiers & Qt.ShiftModifier) ? 3 : 1
            currentIndex = Math.max(0, currentIndex - step)
            event.accepted = true
        }

        Keys.onRightPressed: (event) => {
            let step = (event.modifiers & Qt.ShiftModifier) ? 3 : 1
            currentIndex = Math.min(6, currentIndex + step)
            event.accepted = true
        }

        Keys.onReturnPressed: (event) => {
            triggerAction(currentIndex)
            event.accepted = true
        }

        Keys.onSpacePressed: (event) => {
            triggerAction(currentIndex)
            event.accepted = true
        }

        // Close when clicking the background (outside the card)
        MouseArea {
            anchors.fill: parent
            onClicked: {
                powermenuWindow.active = false
            }
        }

        // Central card containing system actions
        Canvas {
            id: card
            width: 782 // 750 + 2 * 16 (radius)
            height: parent.height - 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 0

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
                ctx.fillStyle = theme.bg0_hard; // Gruvbox Background
                
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

            // Prevent background click handler from triggering when clicking inside the card
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // Do nothing, just intercept the click
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.leftMargin: 36 // 20 + 16 (concave corner offset)
                anchors.rightMargin: 36 // 20 + 16 (concave corner offset)
                anchors.bottomMargin: 16
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SYSTEM POWER OPTIONS"
                        color: theme.fg4
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                        font.family: "Monospace"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "SELECT AN ACTION"
                        color: theme.fg4
                        font.pixelSize: 9
                        font.family: "Monospace"
                    }
                }

                // Power Buttons (Horizontal layout)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // 1. Lock
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (lockMa.containsMouse || currentIndex === 0) ? theme.bg0 : theme.bg0_hard
                        border.color: (lockMa.containsMouse || currentIndex === 0) ? theme.orange : theme.bg1 // Orange
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "LOCK"
                                color: (lockMa.containsMouse || currentIndex === 0) ? theme.orange : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Lock Session"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: lockMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 0
                            onClicked: triggerAction(0)
                        }
                    }

                    // 2. Logout
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (logoutMa.containsMouse || currentIndex === 1) ? theme.bg0 : theme.bg0_hard
                        border.color: (logoutMa.containsMouse || currentIndex === 1) ? theme.yellow : theme.bg1 // Yellow
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "LOGOUT"
                                color: (logoutMa.containsMouse || currentIndex === 1) ? theme.yellow : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Exit Session"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: logoutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 1
                            onClicked: triggerAction(1)
                        }
                    }

                    // 3. Screen Off
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (screenOffMa.containsMouse || currentIndex === 2) ? theme.bg0 : theme.bg0_hard
                        border.color: (screenOffMa.containsMouse || currentIndex === 2) ? theme.aqua : theme.bg1 // Aqua
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "DISPLAY"
                                color: (screenOffMa.containsMouse || currentIndex === 2) ? theme.aqua : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Screen Off"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: screenOffMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 2
                            onClicked: triggerAction(2)
                        }
                    }

                    // 4. Sleep
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (suspendMa.containsMouse || currentIndex === 3) ? theme.bg0 : theme.bg0_hard
                        border.color: (suspendMa.containsMouse || currentIndex === 3) ? theme.blue : theme.bg1 // Blue
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "SLEEP"
                                color: (suspendMa.containsMouse || currentIndex === 3) ? theme.blue : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Suspend PC"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: suspendMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 3
                            onClicked: triggerAction(3)
                        }
                    }

                    // 5. Hibernate
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (hibernateMa.containsMouse || currentIndex === 4) ? theme.bg0 : theme.bg0_hard
                        border.color: (hibernateMa.containsMouse || currentIndex === 4) ? theme.purple : theme.bg1 // Purple
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "HIBERNATE"
                                color: (hibernateMa.containsMouse || currentIndex === 4) ? theme.purple : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Disk Suspend"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: hibernateMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 4
                            onClicked: triggerAction(4)
                        }
                    }

                    // 6. Reboot
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (rebootMa.containsMouse || currentIndex === 5) ? theme.bg0 : theme.bg0_hard
                        border.color: (rebootMa.containsMouse || currentIndex === 5) ? theme.green : theme.bg1 // Green
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "REBOOT"
                                color: (rebootMa.containsMouse || currentIndex === 5) ? theme.green : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Restart PC"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: rebootMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 5
                            onClicked: triggerAction(5)
                        }
                    }

                    // 7. Shutdown
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: (shutdownMa.containsMouse || currentIndex === 6) ? theme.bg0 : theme.bg0_hard
                        border.color: (shutdownMa.containsMouse || currentIndex === 6) ? theme.red : theme.bg1 // Red
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "SHUTDOWN"
                                color: (shutdownMa.containsMouse || currentIndex === 6) ? theme.red : theme.fg1
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Power Off PC"
                                color: theme.fg4
                                font.pixelSize: 8
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        MouseArea {
                            id: shutdownMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: currentIndex = 6
                            onClicked: triggerAction(6)
                        }
                    }
                }
            }
        }
    }
}
