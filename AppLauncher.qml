// AppLauncher.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: launcherWindow
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
            launcherWindow.visible = true
            slideAnimation.to = 0
            slideAnimation.start()
            focusTimer.restart()
        } else {
            slideAnimation.to = launcherWindow.implicitHeight + 20
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
                launcherWindow.visible = false
            }
        }
    }

    property var allApps: []

    Process {
        id: appFetcher
        running: true
        command: ["python3", "/home/kuroiko/.config/quickshell/kuroiko-bar/app_fetcher.py"]
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

    function filterApps(query) {
        appModel.clear();
        let q = query.toLowerCase().trim();
        for (let i = 0; i < allApps.length; i++) {
            if (allApps[i].name.toLowerCase().includes(q)) {
                appModel.append(allApps[i]);
            }
        }
        if (appModel.count > 0) {
            appListView.currentIndex = 0;
        } else {
            appListView.currentIndex = -1;
        }
    }

    function launchApp(execStr) {
        launcherWindow.active = false
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "--", execStr])
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
        y: parent.height + 20 // Initial state is out of view

        // Central card containing search and results
        Rectangle {
            id: card
            width: 500
            height: parent.height - 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            color: "#1d2021" // Gruvbox Background
            border.color: "#3c3836"
            border.width: 1
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Search Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 45
                    color: "#282828"
                    radius: 8
                    border.color: searchInput.activeFocus ? "#fabd2f" : "#3c3836"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "🔍"
                            color: "#a89984"
                            font.pixelSize: 14
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            background: Item {}
                            color: "#ebdbb2"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            placeholderText: "Search Applications..."
                            placeholderTextColor: "#7c6f64"
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: filterApps(text)

                            Keys.onDownPressed: (event) => {
                                if (appListView.currentIndex < appModel.count - 1) {
                                    appListView.currentIndex++;
                                }
                                event.accepted = true;
                            }
                            Keys.onUpPressed: (event) => {
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--;
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

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 50
                        radius: 8
                        color: index === appListView.currentIndex ? "#282828" : "transparent"
                        border.color: index === appListView.currentIndex ? "#fabd2f" : "transparent"
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
                                color: "#3c3836"
                                clip: true

                                Image {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: model.icon ? (model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: model.icon !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.name ? model.name.substring(0, 1).toUpperCase() : "?"
                                    color: "#ebdbb2"
                                    font.bold: true
                                    font.pixelSize: 14
                                    visible: model.icon === ""
                                }
                            }

                            // Application Name
                            Text {
                                Layout.fillWidth: true
                                text: model.name
                                color: "#ebdbb2"
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
