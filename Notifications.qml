// Notifications.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: notifWindow
    anchors { top: true; right: true }
    margins.top: 35
    margins.right: 0
    implicitWidth: 320
    implicitHeight: notifListView.contentHeight
    color: "transparent"
    visible: notificationsList.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    exclusionMode: ExclusionMode.Ignore

    // JavaScript 配列で通知オブジェクトを直接安全に保持 (同一性参照バグの回避)
    property var notificationsList: []

    function addNotification(notification) {
        var list = [];
        // 重複チェックを同時に行いながらコピー
        for (var i = 0; i < notificationsList.length; i++) {
            if (notificationsList[i].id !== notification.id) {
                list.push(notificationsList[i]);
            }
        }
        // 末尾に追加 (最新が一番下、古いものが一番上)
        list.push(notification);
        notificationsList = list;
    }

    function removeNotification(notification) {
        var list = [];
        for (var i = 0; i < notificationsList.length; i++) {
            if (notificationsList[i] !== notification) {
                list.push(notificationsList[i]);
            }
        }
        notificationsList = list;
    }

    ListView {
        id: notifListView
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        spacing: 0
        interactive: false
        
        model: notifWindow.notificationsList
        
        // カードの追加・削除時に他のカードがスッと上下にスライドして詰めるアニメーション
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        delegate: Item {
            id: cardWrapper
            width: 320
            height: cardInnerContainer.height
            clip: true
            
            // modelData は Notification オブジェクトを直接参照
            property var notifObject: modelData
            
            Item {
                id: cardInnerContainer
                width: 320
                height: cardBg.height
                x: -width // 開始位置（左外側、画面中央方向から）
                y: 0
                
                Component.onCompleted: {
                    slideIn.start();
                }

                NumberAnimation {
                    id: slideIn
                    target: cardInnerContainer
                    property: "x"
                    from: -cardInnerContainer.width
                    to: 0 // 定位置。320px幅のWindowに対してぴったり右寄せ
                    duration: 300
                    easing.type: Easing.OutExpo
                }

                NumberAnimation {
                    id: slideOut
                    target: cardInnerContainer
                    property: "x"
                    to: 320 // 右外側へスライドアウト
                    duration: 200
                    easing.type: Easing.InQuad
                    onFinished: {
                        if (notifObject) {
                            notifObject.dismiss();
                            notifWindow.removeNotification(notifObject);
                        }
                    }
                }

                Timer {
                    id: expireTimer
                    interval: notifObject.expireTimeout > 0 ? notifObject.expireTimeout : 5000
                    // 一番上（indexが0の最も古い通知）のみタイマーを動かして順次消去する
                    running: index === 0 && notifObject.urgency !== NotificationUrgency.Critical
                    onTriggered: {
                        slideOut.start();
                    }
                }

                // 背景カード (Gruvboxテーマ、完全に直角)
                Rectangle {
                    id: cardBg
                    width: parent.width
                    height: Math.max(80, cardLayout.implicitHeight + 24)
                    color: theme.bg0_hard

                    // 緊急度インジケーターバー
                    Rectangle {
                        id: urgencyBar
                        width: 4
                        height: parent.height - 24
                        radius: 2
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        color: {
                            if (notifObject.urgency === NotificationUrgency.Critical) return theme.red;
                            if (notifObject.urgency === NotificationUrgency.Low) return theme.blue;
                            return theme.green;
                        }
                    }

                    RowLayout {
                        id: cardLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 18
                            rightMargin: 16
                            topMargin: 12
                        }
                        spacing: 12

                        // アプリケーションアイコン
                        Image {
                            id: appIconImage
                            visible: status === Image.Ready
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectFit
                            source: {
                                if (notifObject.image) {
                                    return notifObject.image;
                                }
                                if (notifObject.appIcon) {
                                    if (notifObject.appIcon.startsWith("/")) {
                                        return "file://" + notifObject.appIcon;
                                    }
                                    var resolved = Quickshell.iconPath(notifObject.appIcon);
                                    if (resolved) return resolved;
                                }
                                // アプリ名によるフォールバック (例: "slack" など)
                                if (notifObject.appName) {
                                    var nameResolved = Quickshell.iconPath(notifObject.appName.toLowerCase());
                                    if (nameResolved) return nameResolved;
                                }
                                return "";
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: notifObject.appName.toUpperCase()
                                    color: theme.fg4
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1
                                    font.family: "Monospace"
                                    Layout.fillWidth: true
                                }

                                // 閉じる (x) ボタン
                                Text {
                                    text: "×"
                                    color: closeMouseArea.containsMouse ? theme.red : theme.fg4
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Monospace"

                                    MouseArea {
                                        id: closeMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            slideOut.start();
                                        }
                                    }
                                }
                            }

                            Text {
                                text: notifObject.summary
                                color: theme.fg1
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "Monospace"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                Layout.fillWidth: true
                            }

                            Text {
                                text: notifObject.body
                                color: theme.fg3
                                font.pixelSize: 11
                                font.family: "Monospace"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // クリックでデフォルトアクション実行
                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onClicked: {
                            if (notifObject.actions.length > 0) {
                                var defaultAction = null;
                                for (var i = 0; i < notifObject.actions.length; i++) {
                                    if (notifObject.actions[i].id === "default") {
                                        defaultAction = notifObject.actions[i];
                                        break;
                                    }
                                }
                                if (!defaultAction && notifObject.actions.length > 0) {
                                    defaultAction = notifObject.actions[0];
                                }
                                if (defaultAction) {
                                    defaultAction.trigger();
                                }
                            }
                            slideOut.start();
                        }
                    }
                }
            }

            Connections {
                target: notifObject
                ignoreUnknownSignals: true
                function onClosed(reason) {
                    slideOut.start();
                }
            }
        }
    }
}
