// AppLauncher.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: launcherWindow
    anchors { left: true; top: true; bottom: true }
    margins.top: 35
    implicitWidth: 500
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    property bool active: false

    onActiveChanged: {
        if (active) {
            launcherWindow.visible = true
            slideAnimation.from = -launcherWindow.width - 20
            slideAnimation.to = 0
            slideAnimation.start()
            focusTimer.restart()
        } else {
            slideAnimation.from = container.x
            slideAnimation.to = -launcherWindow.width - 20
            slideAnimation.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    NumberAnimation {
        id: slideAnimation
        target: container
        property: "x"
        duration: 150
        easing.type: Easing.OutExpo
        onFinished: {
            if (!active) {
                launcherWindow.visible = false
            }
        }
    }

    property var allApps: []

    Process {
        id: appFetcher
        running: true
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko_bar/app_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        launcherWindow.allApps = JSON.parse(this.text);
                        filterApps("");
                    }
                } catch(e) {
                    console.log("Error parsing apps list: ", e);
                }
            }
        }
    }

    ListModel {
        id: appModel
    }

    function getFuzzyScore(str, query) {
        let s = str.toLowerCase();
        let q = query.toLowerCase();
        
        if (s === q) return 100;
        if (s.startsWith(q)) return 90;
        if (s.includes(q)) return 80;
        
        let sIdx = 0;
        let qIdx = 0;
        let lastMatchIdx = -1;
        let distanceSum = 0;
        
        while (sIdx < s.length && qIdx < q.length) {
            if (s[sIdx] === q[qIdx]) {
                if (lastMatchIdx !== -1) {
                    distanceSum += (sIdx - lastMatchIdx);
                }
                lastMatchIdx = sIdx;
                qIdx++;
            }
            sIdx++;
        }
        
        if (qIdx === q.length) {
            let baseScore = 70;
            let penalty = Math.min(40, distanceSum);
            return baseScore - penalty;
        }
        return 0;
    }

    function filterApps(query) {
        appModel.clear();
        let q = query.toLowerCase().trim();
        if (q === "") {
            for (let i = 0; i < allApps.length; i++) {
                appModel.append(allApps[i]);
            }
            if (appModel.count > 0) {
                appListView.currentIndex = 0;
            } else {
                appListView.currentIndex = -1;
            }
            return;
        }

        let results = [];
        for (let i = 0; i < allApps.length; i++) {
            let name = allApps[i].name;
            let score = getFuzzyScore(name, q);
            if (score > 0) {
                results.push({ app: allApps[i], score: score });
            }
        }

        results.sort((a, b) => b.score - a.score);

        for (let i = 0; i < results.length; i++) {
            appModel.append(results[i].app);
        }

        if (appModel.count > 0) {
            appListView.currentIndex = 0;
        } else {
            appListView.currentIndex = -1;
        }
    }

    function launchApp(execStr) {
        launcherWindow.active = false
        // %u, %f, %U, %F, %i, %c, %k などの .desktop プレースホルダーを除去
        let cmd = execStr.replace(/%[uUfFiIcCkbdDnN]/g, "").trim()
        // shで実行することでスペース区切りの複合コマンドも扱える
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    IpcHandler {
        target: "appLauncher"
        function toggle(): void {
            launcherWindow.active = !launcherWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        x: -parent.width - 20 // Initial state is out of view

        // Central card containing search and results
        Canvas {
            id: card
            width: parent.width + 16
            anchors.left: parent.left
            anchors.leftMargin: -16 // Push left corners off-screen
            anchors.top: parent.top
            anchors.bottom: parent.bottom

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
                ctx.arc(w, h - R, R, 1.0 * Math.PI, 0.5 * Math.PI, true);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fill();
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.leftMargin: 32 // Offset the left-margin shift to keep content visible
                anchors.rightMargin: 32 // Offset the concave corner width of 16px
                anchors.bottomMargin: 16
                spacing: 12

                // Search Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 45
                    color: theme.bg0
                    radius: 8
                    border.color: searchInput.activeFocus ? theme.yellow : theme.bg1
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "FIND"
                            color: theme.fg4
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "Monospace"
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            background: Item {}
                            color: theme.fg1
                            font.pixelSize: 14
                            font.family: "Monospace"
                            placeholderText: "Search Applications..."
                            placeholderTextColor: theme.fg4
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: filterApps(text)

                            Keys.onDownPressed: (event) => {
                                if (appListView.currentIndex < appModel.count - 1) {
                                    appListView.currentIndex++;
                                    appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true;
                            }
                            Keys.onUpPressed: (event) => {
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--;
                                    appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain)
                                }
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: (event) => {
                                if (appListView.currentIndex >= 0 && appListView.currentIndex < appModel.count) {
                                    launchApp(appModel.get(appListView.currentIndex).exec);
                                }
                                event.accepted = true;
                            }
                            Keys.onEscapePressed: (event) => {
                                launcherWindow.active = false
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Application List
                ListView {
                    id: appListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: appModel
                    spacing: 4

                    highlightMoveDuration: 120
                    highlightResizeDuration: 120

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 50
                        radius: 8
                        color: index === appListView.currentIndex ? theme.bg0 : "transparent"
                        border.color: index === appListView.currentIndex ? theme.yellow : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            anchors.leftMargin: 12
                            spacing: 12

                            // Icon/Fallback
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 6
                                color: theme.bg1
                                clip: true

                                Image {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: {
                                        if (!model.icon) return "";
                                        if (model.icon.startsWith("/")) return "file://" + model.icon;
                                        let path = Quickshell.iconPath(model.icon, true);
                                        if (!path) return "";
                                        if (path.startsWith("/image://")) return path.substring(1);
                                        if (path.startsWith("image://")) return path;
                                        return "file://" + path;
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready

                                    onStatusChanged: {
                                        if (status === Image.Error && model.icon && !model.icon.startsWith("/")) {
                                            // XDGアイコン名での読み込みが失敗した場合、
                                            // フルパス検索にフォールバックしてからあきらめる
                                            source = ""
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.name ? model.name.substring(0, 1).toUpperCase() : "?"
                                    color: theme.fg1
                                    font.bold: true
                                    font.pixelSize: 14
                                    visible: appIcon.status !== Image.Ready
                                }
                            }

                            // Application Name
                            Text {
                                Layout.fillWidth: true
                                text: model.name
                                color: theme.fg1
                                font.pixelSize: 13
                                font.bold: index === appListView.currentIndex
                                font.family: "Monospace"
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: appListView.currentIndex = index
                            onClicked: launchApp(model.exec)
                        }
                    }
                }
            }
        }
    }
}
