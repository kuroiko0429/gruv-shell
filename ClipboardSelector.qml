// ClipboardSelector.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: clipboardWindow
    anchors { bottom: true; left: true; right: true }
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
            clipboardWindow.visible = true
            loadHistory()
            slideAnimation.from = clipboardWindow.height + 20
            slideAnimation.to = 0
            slideAnimation.start()
            focusTimer.restart()
        } else {
            slideAnimation.from = container.y
            slideAnimation.to = clipboardWindow.height + 20
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
        property: "y"
        duration: 150
        easing.type: Easing.OutExpo
        onFinished: {
            if (!active) {
                clipboardWindow.visible = false
            }
        }
    }

    property var allItems: []

    // クリップボード監視の自動起動デーモン
    Process {
        id: cliphistTextWatch
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: true
    }

    Process {
        id: cliphistImageWatch
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: true
    }

    Process {
        id: listFetcher
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                let items = []
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line) {
                        let tabIdx = line.indexOf("\t")
                        if (tabIdx !== -1) {
                            let id = line.substring(0, tabIdx)
                            let content = line.substring(tabIdx + 1)
                            items.push({ "raw": line, "id": id, "content": content })
                        } else {
                            items.push({ "raw": line, "id": "", "content": line })
                        }
                    }
                }
                clipboardWindow.allItems = items
                filterItems("")
            }
        }
    }

    ListModel {
        id: clipboardModel
    }

    function loadHistory() {
        listFetcher.running = false
        listFetcher.running = true
    }

    function filterItems(query) {
        clipboardModel.clear()
        let q = query.toLowerCase().trim()
        for (let i = 0; i < allItems.length; i++) {
            if (allItems[i].content.toLowerCase().includes(q)) {
                clipboardModel.append(allItems[i])
            }
        }
        if (clipboardModel.count > 0) {
            historyListView.currentIndex = 0
        } else {
            historyListView.currentIndex = -1
        }
    }

    function copyAndClose(rawItem) {
        clipboardWindow.active = false
        let shellCmd = "printf '%s' " + quoteShell(rawItem) + " | cliphist decode | wl-copy"
        Quickshell.execDetached(["sh", "-c", shellCmd])
        
        let notifyCmd = "notify-send -h string:x-canonical-private-synchronous:clipboard -u low 'クリップボード' '選択した履歴をコピーしました'"
        Quickshell.execDetached(["sh", "-c", notifyCmd])
    }

    function clearClipboardHistory() {
        Quickshell.execDetached(["cliphist", "wipe"])
        
        let notifyCmd = "notify-send -h string:x-canonical-private-synchronous:clipboard -u low 'クリップボード' '履歴をすべて削除しました'"
        Quickshell.execDetached(["sh", "-c", notifyCmd])
        
        searchInput.text = ""
        loadHistory()
    }

    function quoteShell(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }

    IpcHandler {
        target: "clipboardSelector"
        function toggle(): void {
            clipboardWindow.active = !clipboardWindow.active
        }
    }

    Item {
        id: container
        width: parent.width
        height: parent.height
        y: parent.height + 20 // Initial state is out of view

        // Central card containing search and results
        Rectangle {
            id: card
            width: 600
            height: parent.height - 20 + 16 // Extend by radius
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -16 // Margin 0, flat bottom corners
            color: theme.bg0_hard // Gruvbox Background
            border.color: theme.bg1
            border.width: 1
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 32 // Offset the bottom-margin shift to keep list visible
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
                            text: "CLIP"
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
                            placeholderText: "Search Clipboard History..."
                            placeholderTextColor: theme.fg4
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: filterItems(text)

                            Keys.onDownPressed: (event) => {
                                if (historyListView.currentIndex < clipboardModel.count - 1) {
                                    historyListView.currentIndex++;
                                }
                                event.accepted = true;
                            }
                            Keys.onUpPressed: (event) => {
                                if (historyListView.currentIndex > 0) {
                                    historyListView.currentIndex--;
                                }
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: (event) => {
                                if (searchInput.text.trim() === "/clear") {
                                    clearClipboardHistory();
                                } else if (historyListView.currentIndex >= 0 && historyListView.currentIndex < clipboardModel.count) {
                                    copyAndClose(clipboardModel.get(historyListView.currentIndex).raw);
                                }
                                event.accepted = true;
                            }
                            Keys.onEscapePressed: (event) => {
                                clipboardWindow.active = false
                                event.accepted = true;
                            }
                        }
                    }
                }

                // History List
                ListView {
                    id: historyListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: clipboardModel
                    spacing: 4

                    highlightMoveDuration: 120
                    highlightResizeDuration: 120

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0) {
                            positionViewAtIndex(currentIndex, ListView.Contain)
                        }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 40
                        radius: 6
                        color: index === historyListView.currentIndex ? theme.bg0 : "transparent"
                        border.color: index === historyListView.currentIndex ? theme.yellow : "transparent"
                        border.width: 1


                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: (index + 1) + "."
                                color: index === historyListView.currentIndex ? theme.yellow : theme.fg4
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "Monospace"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    let c = model.content
                                    if (c.startsWith("<meta")) return "[Image / Binary Data]"
                                    return c
                                }
                                color: index === historyListView.currentIndex ? theme.fg1 : theme.fg4
                                font.pixelSize: 13
                                font.bold: index === historyListView.currentIndex
                                font.family: "Monospace"
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: historyListView.currentIndex = index
                            onClicked: copyAndClose(model.raw)
                        }
                    }
                }
            }
        }
    }
}
