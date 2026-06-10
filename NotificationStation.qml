// NotificationStation.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: stationWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 10
    implicitWidth: 320
    implicitHeight: 480
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false

    onActiveChanged: {
        if (active) {
            shellRoot.closeAllExcept(stationWindow)
            stationWindow.visible = true
            slideAnimation.from = -stationWindow.height - 20
            slideAnimation.to = 0
            slideAnimation.start()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = -stationWindow.height - 20
            slideAnimation.start()
        }
    }

    NumberAnimation {
        id: slideAnimation
        target: container
        property: "y"
        duration: 200
        easing.type: Easing.OutExpo
        onFinished: {
            if (!active) {
                stationWindow.visible = false
            }
        }
    }

    IpcHandler {
        target: "notificationStation"
        function toggle(): void {
            stationWindow.active = !stationWindow.active;
        }
    }

    // 中身のコンテナ (クリッピングしてスライドインアニメーションを隠す)
    Item {
        id: clipContainer
        anchors.fill: parent
        clip: true

        Rectangle {
            id: container
            width: parent.width
            height: parent.height
            y: -height - 20
            color: theme.bg0_hard
            
            // ボーダー代わりにわずかにハイライト
            border.color: theme.bg1
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // ヘッダー部分 (タイトルと一括クリア)
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "NOTIFICATION STATION"
                        color: theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                        font.family: "Monospace"
                        Layout.fillWidth: true
                    }

                    // すべてクリアボタン
                    Text {
                        text: "[CLEAR ALL]"
                        color: clearMa.containsMouse ? theme.red : theme.fg4
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Monospace"
                        visible: shellRoot.notificationHistory.length > 0

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                shellRoot.clearHistory();
                            }
                        }
                    }
                }

                // プレースホルダー (履歴が空の場合)
                Text {
                    text: "No notifications"
                    color: theme.gray
                    font.pixelSize: 11
                    font.family: "Monospace"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: shellRoot.notificationHistory.length === 0
                }

                // 履歴リスト
                ListView {
                    id: historyListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    clip: true
                    interactive: true
                    visible: shellRoot.notificationHistory.length > 0

                    model: shellRoot.notificationHistory

                    delegate: Rectangle {
                        width: historyListView.width
                        height: Math.max(64, cardLayout.implicitHeight + 16)
                        color: theme.bg0_soft

                        RowLayout {
                            id: cardLayout
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: 10
                                rightMargin: 10
                                topMargin: 8
                            }
                            spacing: 10

                            // アプリケーションアイコン
                            Image {
                                id: appIconImage
                                visible: status === Image.Ready
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignTop
                                fillMode: Image.PreserveAspectFit
                                source: {
                                    if (modelData.image) {
                                        return modelData.image;
                                    }
                                    if (modelData.appIcon) {
                                        if (modelData.appIcon.startsWith("/")) {
                                            return "file://" + modelData.appIcon;
                                        }
                                        var resolved = Quickshell.iconPath(modelData.appIcon);
                                        if (resolved) return resolved;
                                    }
                                    if (modelData.appName) {
                                        var nameResolved = Quickshell.iconPath(modelData.appName.toLowerCase());
                                        if (nameResolved) return nameResolved;
                                    }
                                    return "";
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        text: modelData.appName.toUpperCase()
                                        color: theme.fg4
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: "Monospace"
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.timestamp
                                        color: theme.gray
                                        font.pixelSize: 8
                                        font.family: "Monospace"
                                    }

                                    // 個別削除 (x) ボタン
                                    Text {
                                        text: "×"
                                        color: deleteMa.containsMouse ? theme.red : theme.fg4
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Monospace"

                                        MouseArea {
                                            id: deleteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                shellRoot.removeHistory(modelData.id);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.summary
                                    color: theme.fg1
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "Monospace"
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.body
                                    color: theme.fg3
                                    font.pixelSize: 10
                                    font.family: "Monospace"
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 3
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
