// WallpaperSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: selectorWindow
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 180
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    // 制御変数
    property bool active: false

    onActiveChanged: {
        if (active) {
            selectorWindow.visible = true
            slideAnimation.from = selectorWindow.height + 20
            slideAnimation.to = 0
            slideAnimation.start()
            wallpaperListView.forceActiveFocus()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = selectorWindow.height + 20
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
                selectorWindow.visible = false
            }
        }
    }

    ListModel {
        id: wallpaperModel
    }

    Process {
        id: findWallpapers
        command: ["sh", "-c", "find /home/kuroiko/Pictures/Wallpapers -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.webp' \\) | sort"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                wallpaperModel.clear()
                for (let i = 0; i < lines.length; i++) {
                    let path = lines[i].trim()
                    if (path) {
                        let parts = path.split("/")
                        let name = parts[parts.length - 1]
                        let category = parts[parts.length - 2]
                        wallpaperModel.append({ "path": path, "name": name, "category": category })
                    }
                }
            }
        }
    }

    Process {
        id: setWallpaperProc
    }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void {
            selectorWindow.active = !selectorWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: parent.height + 20 // 初期状態は画面外

        // 半透明背景カード (凹型角丸)
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
                ctx.fillStyle = theme.bg0_hard; // Gruvbox背景
                
                var R = 16; // radius
                var w = width;
                var h = height;

                ctx.beginPath();
                ctx.moveTo(0, h);
                ctx.lineTo(0, 0);
                ctx.arc(R, 0, R, 1.0 * Math.PI, 0.5 * Math.PI, true);
                ctx.lineTo(w - R, R);
                ctx.arc(w - R, 0, R, 0.5 * Math.PI, 0, true);
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fill();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 32 // 16 + 16 (concave corner offset)
            anchors.bottomMargin: 16
            anchors.leftMargin: 32 // 16 + 16 (concave corner offset)
            anchors.rightMargin: 32 // 16 + 16 (concave corner offset)
            spacing: 8

            // ヘッダー行
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "WALLPAPER SELECTOR"
                    color: theme.fg4
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 2
                    font.family: "Monospace"
                }

                Text {
                    text: wallpaperModel.count + " WALLPAPERS AVAILABLE"
                    color: theme.fg4
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Monospace"
                }

                Item { Layout.fillWidth: true }

                // 閉じるボタン
                Rectangle {
                    width: 20
                    height: 20
                    radius: 4
                    color: theme.bg1
                    Layout.alignment: Qt.AlignRight

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        color: theme.red
                        font.bold: true
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: selectorWindow.active = false
                    }
                }
            }

            // 壁紙リスト
            ListView {
                id: wallpaperListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 12
                model: wallpaperModel
                clip: true
                focus: selectorWindow.active

                highlightMoveDuration: 120
                highlightResizeDuration: 120

                Keys.onEscapePressed: (event) => {
                    selectorWindow.active = false
                    event.accepted = true
                }

                Keys.onLeftPressed: (event) => {
                    let step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                    let newIndex = Math.max(0, currentIndex - step)
                    currentIndex = newIndex
                    positionViewAtIndex(currentIndex, ListView.Contain)
                    event.accepted = true
                }
                Keys.onRightPressed: (event) => {
                    let step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                    let newIndex = Math.min(model.count - 1, currentIndex + step)
                    currentIndex = newIndex
                    positionViewAtIndex(currentIndex, ListView.Contain)
                    event.accepted = true
                }
                Keys.onReturnPressed: (event) => {
                    if (currentItem) {
                        let item = model.get(currentIndex)
                        setWallpaperProc.exec(["awww", "img", item.path, "--transition-type", "grow", "--transition-pos", "0.5,0.5", "--transition-duration", "0.5"])
                    }
                    event.accepted = true
                }
                Keys.onSpacePressed: (event) => {
                    if (currentItem) {
                        let item = model.get(currentIndex)
                        setWallpaperProc.exec(["awww", "img", item.path, "--transition-type", "grow", "--transition-pos", "0.5,0.5", "--transition-duration", "0.5"])
                    }
                    event.accepted = true
                }

                WheelHandler {
                    orientation: Qt.Horizontal | Qt.Vertical
                    onWheel: (event) => {
                        let multiplier = 2.5 // Scroll sensitivity multiplier
                        let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        let newX = wallpaperListView.contentX - (delta * multiplier)
                        let maxX = Math.max(0, wallpaperListView.contentWidth - wallpaperListView.width)
                        wallpaperListView.contentX = Math.max(0, Math.min(maxX, newX))
                        event.accepted = true
                    }
                }

                delegate: Rectangle {
                    id: delegateRect
                    width: 160
                    height: 100
                    radius: 8
                    color: theme.bg0
                    border.color: ListView.isCurrentItem ? theme.orange : (delegateMa.containsMouse ? theme.yellow : theme.bg1)
                    border.width: 2

                    // 壁紙のサムネイル (メモリ節約のためsourceSizeを小さく指定)
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: "file://" + model.path
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 160
                        sourceSize.height: 100
                        asynchronous: true
                    }

                    // カテゴリと名前のオーバーレイ
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 20
                        color: Qt.rgba(theme.bg0.r, theme.bg0.g, theme.bg0.b, 0.8)
                        radius: 8

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            text: model.category + " / " + model.name
                            color: theme.fg1
                            font.pixelSize: 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "Monospace"
                        }
                    }

                    MouseArea {
                        id: delegateMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            wallpaperListView.currentIndex = index
                            setWallpaperProc.exec(["awww", "img", model.path, "--transition-type", "grow", "--transition-pos", "0.5,0.5", "--transition-duration", "0.5"])
                        }
                    }
                }
            }
        }
    }
}
