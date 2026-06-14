// WifiSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: wifiWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 320// Align under the Wi-Fi pill
    implicitWidth: 300
    implicitHeight: 380
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false
    property string rxSpeed: "0 B/s"
    property string txSpeed: "0 B/s"
    property string selectedSsid: ""
    property string selectedSecurity: ""
    property string targetSsid: ""
    property bool connecting: false

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(wifiWindow)
            wifiWindow.visible = true
            updateWifiList()
            slideAnimation.from = -wifiWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -wifiWindow.height - 20
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
                wifiWindow.visible = false
            }
        }
    }

    // Network speed monitoring (runs when card is active)
    Process {
        id: speedMonitorProc
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/network_info.py", "--speed"]
        running: wifiWindow.active
        stdout: SplitParser {
            onRead: data => {
                try {
                    let info = JSON.parse(data.trim());
                    wifiWindow.rxSpeed = info.rx_speed;
                    wifiWindow.txSpeed = info.tx_speed;
                } catch (e) {}
            }
        }
    }

    // Nearby hotspot list scanner
    Process {
        id: wifiListProc
        running: false
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/network_info.py", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    wifiModel.clear();
                    for (let i = 0; i < data.length; i++) {
                        wifiModel.append(data[i]);
                    }
                } catch (e) {
                    console.log("Failed to parse wifi list. Error:", e, "Raw text:", this.text);
                }
            }
        }
    }

    function updateWifiList() {
        wifiListProc.running = false
        wifiListProc.running = true
    }

    // Wi-Fi Connection process
    Process {
        id: connectProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = this.text.trim();
                let success = val.indexOf("successfully activated") !== -1;
                let msg = success ? "「" + targetSsid + "」に接続しました。" : "接続に失敗しました：\n" + val.substring(0, 80);
                
                Quickshell.execDetached(["notify-send", "-h", "string:x-canonical-private-synchronous:network", "-u", success ? "low" : "normal", "ネットワーク", msg]);
                
                connecting = false;
                if (success) {
                    wifiWindow.active = false;
                    updateWifiList();
                }
            }
        }
    }

    ListModel {
        id: wifiModel
    }

    IpcHandler {
        target: "wifiSelector"
        function toggle(): void {
            wifiWindow.active = !wifiWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: wifiWindow.active

        Keys.onEscapePressed: {
            wifiWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                wifiWindow.active = false
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
                        text: "WIFI DIAGNOSTICS & SETUP"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        font.family: "Monospace"
                    }
                }

                // Speed Display
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "DOWN"
                            color: theme.fg4
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }
                        Text {
                            text: "↓ " + wifiWindow.rxSpeed
                            color: theme.green
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "Monospace"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "UP"
                            color: theme.fg4
                            font.pixelSize: 9
                            font.family: "Monospace"
                        }
                        Text {
                            text: "↑ " + wifiWindow.txSpeed
                            color: theme.blue
                            font.pixelSize: 12
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

                // Hotspots Title with Refresh button
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "AVAILABLE HOTSPOTS"
                        color: theme.fg4
                        font.pixelSize: 9
                        font.family: "Monospace"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "REFRESH"
                        color: refreshMa.containsMouse ? theme.fg1 : theme.gray
                        font.pixelSize: 9
                        font.bold: true
                        font.family: "Monospace"
                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: updateWifiList()
                        }
                    }
                }

                // ListView
                ListView {
                    id: wifiListView
                    Layout.fillWidth: true
                    height: 120
                    clip: true
                    model: wifiModel
                    spacing: 4

                    delegate: Rectangle {
                        width: wifiListView.width
                        height: 28
                        radius: 6
                        color: model.active ? theme.bg0_soft : (index === wifiListView.currentIndex ? theme.bg0 : "transparent")
                        border.color: model.active ? theme.green : (index === wifiListView.currentIndex ? theme.bg1 : "transparent")
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: model.signal + "%"
                                color: model.active ? theme.green : theme.fg3
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Monospace"
                            }

                            Text {
                                text: model.ssid
                                color: model.active ? theme.green : theme.fg1
                                font.pixelSize: 12
                                font.bold: model.active
                                font.family: "Monospace"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.security.indexOf("WPA") !== -1 ? "SECURE" : "OPEN"
                                color: model.security.indexOf("WPA") !== -1 ? theme.yellow : theme.fg4
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "Monospace"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiListView.currentIndex = index;
                                selectedSsid = model.ssid;
                                selectedSecurity = model.security;
                                passwordInput.text = "";
                                if (model.security !== "OPEN") {
                                    passwordInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.bg1
                    visible: selectedSsid !== ""
                }

                // Connection Area
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: selectedSsid !== ""
                    spacing: 6

                    Text {
                        text: "CONNECT TO: " + selectedSsid
                        color: theme.fg3
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Monospace"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Password Input
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        color: theme.bg0
                        radius: 6
                        border.color: passwordInput.activeFocus ? theme.yellow : theme.bg1
                        border.width: 1
                        visible: selectedSecurity !== "OPEN"

                        TextField {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            background: Item {}
                            color: theme.fg1
                            font.pixelSize: 12
                            font.family: "Monospace"
                            placeholderText: "Password..."
                            placeholderTextColor: theme.fg4
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            enabled: !connecting
                        }
                    }

                    // CONNECT Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 6
                        color: connecting ? theme.bg0_soft : (connectBtnMa.containsMouse ? theme.bg0_soft : theme.bg0)
                        border.color: theme.bg1
                        border.width: 1
                        enabled: !connecting

                        Text {
                            anchors.centerIn: parent
                            text: connecting ? "CONNECTING..." : "CONNECT"
                            color: parent.enabled ? theme.fg1 : theme.gray
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Monospace"
                        }

                        MouseArea {
                            id: connectBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (selectedSsid === "") return;
                                connecting = true;
                                targetSsid = selectedSsid;
                                
                                let args = ["nmcli", "device", "wifi", "connect", selectedSsid];
                                if (selectedSecurity !== "OPEN") {
                                    args.push("password");
                                    args.push(passwordInput.text);
                                }
                                connectProc.command = args;
                                connectProc.running = false;
                                connectProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
