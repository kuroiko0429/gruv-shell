import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

ShellRoot {
    id: shellRoot

    property string currentUser: Quickshell.env("USER") || "user"
    property string wallpaperPath: ""
    property bool authenticated: false
    property bool sessionLocked: true
    property string authError: ""
    property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property bool isTesting: Quickshell.env("QS_TESTING") === "1"
    property bool isAuthenticating: false

    Process {
        id: getWallpaper
        command: ["sh", "-c", "awww query | grep -o 'image: .*' | cut -d' ' -f2-"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let path = this.text.trim()
                if (path) {
                    shellRoot.wallpaperPath = "file://" + path
                }
            }
        }
    }

    function tryAuthenticate(password) {
        if (password === "") return
        shellRoot.isAuthenticating = true
        shellRoot.authError = ""
        pam.pendingPassword = password
        pam.start()
    }

    PamContext {
        id: pam
        user: shellRoot.currentUser
        property string pendingPassword: ""

        onResponseRequiredChanged: {
            if (responseRequired && pendingPassword !== "") {
                respond(pendingPassword)
                pendingPassword = ""
            }
        }

        onCompleted: (result) => {
            shellRoot.isAuthenticating = false
            if (result === PamResult.Success) {
                shellRoot.authenticated = true
                Quickshell.execDetached(["loginctl", "unlock-session"])
                shellRoot.sessionLocked = false
                Qt.quit()
            } else {
                shellRoot.authError = "Authentication Failed"
                errorTimer.restart()
            }
        }
    }

    Timer {
        id: errorTimer
        interval: 3000
        onTriggered: shellRoot.authError = ""
    }

    Component {
        id: lockUIComponent

        Item {
            anchors.fill: parent

            // 1. Wallpaper background
            Image {
                anchors.fill: parent
                source: shellRoot.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: shellRoot.wallpaperPath !== ""
            }

            // Fallback flat color if wallpaper is not loaded
            Rectangle {
                anchors.fill: parent
                color: "#1d2021"
                visible: shellRoot.wallpaperPath === ""
            }

            // 2. Dark Gruvbox Overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.11, 0.12, 0.13, 0.85) // Transparent Gruvbox dark
            }

            // 3. Central Login Card
            Rectangle {
                id: loginCard
                width: 380
                height: 300
                anchors.centerIn: parent
                color: Qt.rgba(0.157, 0.157, 0.157, 0.92) // #282828 with opacity
                border.color: "#504945"
                border.width: 1
                radius: 16

                layer.enabled: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 14

                    // Clock display
                    Text {
                        id: clockDisplay
                        Layout.alignment: Qt.AlignHCenter
                        color: "#ebdbb2"
                        font.pixelSize: 36
                        font.bold: true
                        font.family: "Monospace"
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockDisplay.text = Qt.formatDateTime(new Date(), "HH:mm")
                        }
                    }

                    // User Info Header
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: shellRoot.currentUser
                            color: "#a89984"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.letterSpacing: 2
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Password Input
                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        color: "#1d2021"
                        radius: 6
                        border.color: shellRoot.authError !== "" ? "#fb4934" : (pwInput.activeFocus ? "#fe8019" : "#3c3836")
                        border.width: 1

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        TextField {
                            id: pwInput
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: shellRoot.isAuthenticating ? 46 : 14
                            background: Item {}
                            color: "#ebdbb2"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            echoMode: TextInput.Password
                            placeholderText: shellRoot.isAuthenticating ? "" : "Enter password..."
                            placeholderTextColor: "#7c6f64"
                            verticalAlignment: TextInput.AlignVCenter
                            enabled: !shellRoot.isAuthenticating

                            Component.onCompleted: forceActiveFocus()

                            onAccepted: {
                                let pw = text
                                text = ""
                                shellRoot.tryAuthenticate(pw)
                            }
                        }

                        // Spinner during auth
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: "transparent"
                            border.color: "#fe8019"
                            border.width: 2
                            visible: shellRoot.isAuthenticating
                            opacity: shellRoot.isAuthenticating ? 1 : 0

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#fe8019"
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            RotationAnimator on rotation {
                                from: 0; to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: shellRoot.isAuthenticating
                            }
                        }
                    }

                    // Status / Error Messages
                    Text {
                        text: shellRoot.authError
                        color: "#fb4934" // Gruvbox Red
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                        font.letterSpacing: 1
                        Layout.alignment: Qt.AlignHCenter
                        visible: shellRoot.authError !== ""
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        opacity: shellRoot.authError !== "" ? 1 : 0
                    }

                    // Spacer
                    Item {
                        height: 4
                        Layout.fillHeight: false
                        visible: shellRoot.authError === ""
                    }

                    // Bottom Quick Actions (Reboot / Shutdown)
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 24

                        Text {
                            text: "REBOOT"
                            color: rebootMa.containsMouse ? "#b8bb26" : "#7c6f64"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Monospace"

                            MouseArea {
                                id: rebootMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                            }
                        }

                        Text {
                            text: "SHUTDOWN"
                            color: shutdownMa.containsMouse ? "#fb4934" : "#7c6f64"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Monospace"

                            MouseArea {
                                id: shutdownMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: waylandLoader
        active: shellRoot.isWayland && !shellRoot.isTesting
        sourceComponent: Component {
            WlSessionLock {
                id: lock
                locked: shellRoot.sessionLocked
                surface: Component {
                    WlSessionLockSurface {
                        color: "black"
                        
                        PinchHandler { target: null }
                        WheelHandler { target: null }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            hoverEnabled: true
                            onWheel: (wheel) => { wheel.accepted = true }
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: lockUIComponent
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: x11Loader
        active: !shellRoot.isWayland || shellRoot.isTesting
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: Window {
                    required property var modelData
                    screen: modelData
                    width: shellRoot.isTesting ? 1280 : screen.width
                    height: shellRoot.isTesting ? 720 : screen.height
                    visible: shellRoot.sessionLocked
                    visibility: shellRoot.isTesting ? Window.Windowed : Window.FullScreen
                    
                    onClosing: (close) => {
                        close.accepted = shellRoot.authenticated || shellRoot.isTesting;
                    }
                    
                    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.MaximizeUsingFullscreenGeometryHint
                    color: "black"

                    Loader {
                        anchors.fill: parent
                        sourceComponent: lockUIComponent
                    }
                }
            }
        }
    }
}
