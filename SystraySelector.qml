// SystraySelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: systrayWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: shellRoot.systrayCardRightMargin
    implicitWidth: 170
    implicitHeight: Math.max(50, Math.ceil(selectorRepeater.count / 4) * 30 + 24)
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(systrayWindow)
            systrayWindow.visible = true
            slideAnimation.from = -systrayWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -systrayWindow.height - 20
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
                systrayWindow.visible = false
            }
        }
    }

    IpcHandler {
        target: "systraySelector"
        function toggle(): void {
            systrayWindow.active = !systrayWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: -parent.height - 20

        focus: systrayWindow.active

        Keys.onEscapePressed: {
            systrayWindow.active = false
        }

        // Close when clicking outside
        MouseArea {
            anchors.fill: parent
            onClicked: {
                systrayWindow.active = false
            }
        }

        // Card container (Gruvbox theme, same shape as other cards, borderless)
        Canvas {
            id: cardBg
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: theme
                function onModeChanged() {
                    cardBg.requestPaint();
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

            // Safe content area within the concave corners
            Item {
                id: contentArea
                anchors.fill: parent
                anchors.topMargin: 22 // R + 6
                anchors.bottomMargin: 8
                anchors.leftMargin: 28 // R + 12
                anchors.rightMargin: 28

                // プレースホルダー (トレイが空の場合)
                Text {
                    text: "No tray items"
                    color: theme.gray
                    font.pixelSize: 10
                    font.family: "Monospace"
                    anchors.centerIn: parent
                    visible: selectorRepeater.count === 0
                }

                // アイコンのグリッド表示 (4列)
                Grid {
                    id: trayGrid
                    anchors.centerIn: parent
                    columns: 4
                    spacing: 6
                    visible: selectorRepeater.count > 0

                    Repeater {
                        id: selectorRepeater
                        model: SystemTray.items
                        delegate: Rectangle {
                            width: 24
                            height: 24
                            radius: 4
                            color: ma.containsMouse ? theme.bg1 : theme.bg0_soft

                            Image {
                                id: iconImage
                                anchors.fill: parent
                                anchors.margins: 4
                                source: {
                                    let iconStr = modelData.icon;
                                    if (!iconStr) return "";
                                    if (iconStr.startsWith("/") || iconStr.startsWith("file://")) {
                                        return iconStr.startsWith("/") ? "file://" + iconStr : iconStr;
                                    }
                                    let name = iconStr;
                                    if (iconStr.startsWith("image://icon/")) {
                                        name = iconStr.substring(13);
                                    }
                                    let path = Quickshell.iconPath(name, true);
                                    if (!path) return "";
                                    if (path.startsWith("/image://")) return path.substring(1);
                                    if (path.startsWith("image://")) return path;
                                    return "file://" + path;
                                }
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.title ? modelData.title.substring(0, 1).toUpperCase() : "?"
                                color: theme.fg0
                                font.bold: true
                                font.pixelSize: 10
                                visible: iconImage.status !== Image.Ready
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate()
                                        systrayWindow.active = false
                                    } else if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                        let pos = ma.mapToItem(null, mouse.x, mouse.y)
                                        modelData.display(systrayWindow, pos.x, pos.y)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
