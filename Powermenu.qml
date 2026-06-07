// Powermenu.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: powermenuWindow
    anchors { bottom: true; left: true; right: true }
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
            powermenuWindow.visible = true
            slideAnimation.from = powermenuWindow.height + 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = powermenuWindow.height + 20
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
            runAction("bash ~/.config/quickshell/lockscreen/lock.sh")
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
        y: parent.height + 20 // Initial state is out of view

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
        Rectangle {
            id: card
            width: 750
            height: parent.height - 20 + 16 // Extend by radius
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -16 // Margin 0, flat bottom corners
            color: "#1d2021" // Gruvbox Background
            border.color: "#3c3836"
            border.width: 1
            radius: 16

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
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 32 // Offset the bottom-margin shift to keep buttons visible
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SYSTEM POWER OPTIONS"
                        color: "#a89984"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                        font.family: "Monospace"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "SELECT AN ACTION"
                        color: "#7c6f64"
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
                        color: (lockMa.containsMouse || currentIndex === 0) ? "#282828" : "#1d2021"
                        border.color: (lockMa.containsMouse || currentIndex === 0) ? "#fe8019" : "#3c3836" // Orange
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "LOCK"
                                color: (lockMa.containsMouse || currentIndex === 0) ? "#fe8019" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Lock Session"
                                color: "#7c6f64"
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
                        color: (logoutMa.containsMouse || currentIndex === 1) ? "#282828" : "#1d2021"
                        border.color: (logoutMa.containsMouse || currentIndex === 1) ? "#fabd2f" : "#3c3836" // Yellow
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "LOGOUT"
                                color: (logoutMa.containsMouse || currentIndex === 1) ? "#fabd2f" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Exit Session"
                                color: "#7c6f64"
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
                        color: (screenOffMa.containsMouse || currentIndex === 2) ? "#282828" : "#1d2021"
                        border.color: (screenOffMa.containsMouse || currentIndex === 2) ? "#8ec07c" : "#3c3836" // Aqua
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "DISPLAY"
                                color: (screenOffMa.containsMouse || currentIndex === 2) ? "#8ec07c" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Screen Off"
                                color: "#7c6f64"
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
                        color: (suspendMa.containsMouse || currentIndex === 3) ? "#282828" : "#1d2021"
                        border.color: (suspendMa.containsMouse || currentIndex === 3) ? "#83a598" : "#3c3836" // Blue
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "SLEEP"
                                color: (suspendMa.containsMouse || currentIndex === 3) ? "#83a598" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Suspend PC"
                                color: "#7c6f64"
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
                        color: (hibernateMa.containsMouse || currentIndex === 4) ? "#282828" : "#1d2021"
                        border.color: (hibernateMa.containsMouse || currentIndex === 4) ? "#d3869b" : "#3c3836" // Purple
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "HIBERNATE"
                                color: (hibernateMa.containsMouse || currentIndex === 4) ? "#d3869b" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Disk Suspend"
                                color: "#7c6f64"
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
                        color: (rebootMa.containsMouse || currentIndex === 5) ? "#282828" : "#1d2021"
                        border.color: (rebootMa.containsMouse || currentIndex === 5) ? "#b8bb26" : "#3c3836" // Green
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "REBOOT"
                                color: (rebootMa.containsMouse || currentIndex === 5) ? "#b8bb26" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Restart PC"
                                color: "#7c6f64"
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
                        color: (shutdownMa.containsMouse || currentIndex === 6) ? "#282828" : "#1d2021"
                        border.color: (shutdownMa.containsMouse || currentIndex === 6) ? "#fb4934" : "#3c3836" // Red
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "SHUTDOWN"
                                color: (shutdownMa.containsMouse || currentIndex === 6) ? "#fb4934" : "#ebdbb2"
                                font.bold: true
                                font.pixelSize: 13
                                font.family: "Monospace"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Power Off PC"
                                color: "#7c6f64"
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
