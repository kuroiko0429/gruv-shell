// ScreenCorners.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root
    property int cornerRadius: 16
    property color cornerColor: theme.bg0_hard // Color matching display bezel (black)
    property int topMargin: 35

    Connections {
        target: theme
        function onModeChanged() {
            tlCanvas.requestPaint();
            trCanvas.requestPaint();
            blCanvas.requestPaint();
            brCanvas.requestPaint();
        }
    }

    // Top-Left Corner
    PanelWindow {
        anchors { top: true; left: true }
        margins.top: root.topMargin
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screen-corner-tl"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {} // Empty input region to guarantee mouse passthrough

        Canvas {
            id: tlCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.cornerColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(root.cornerRadius, 0);
                ctx.arcTo(0, 0, 0, root.cornerRadius, root.cornerRadius);
                ctx.lineTo(0, root.cornerRadius);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // Top-Right Corner
    PanelWindow {
        anchors { top: true; right: true }
        margins.top: root.topMargin
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screen-corner-tr"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {} // Empty input region to guarantee mouse passthrough

        Canvas {
            id: trCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.cornerColor;
                ctx.beginPath();
                ctx.moveTo(root.cornerRadius, 0);
                ctx.lineTo(root.cornerRadius, root.cornerRadius);
                ctx.arcTo(root.cornerRadius, 0, 0, 0, root.cornerRadius);
                ctx.lineTo(0, 0);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // Bottom-Left Corner
    PanelWindow {
        anchors { bottom: true; left: true }
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screen-corner-bl"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {} // Empty input region to guarantee mouse passthrough

        Canvas {
            id: blCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.cornerColor;
                ctx.beginPath();
                ctx.moveTo(0, root.cornerRadius);
                ctx.lineTo(0, 0);
                ctx.arcTo(0, root.cornerRadius, root.cornerRadius, root.cornerRadius, root.cornerRadius);
                ctx.lineTo(cornerRadius, root.cornerRadius);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // Bottom-Right Corner
    PanelWindow {
        anchors { bottom: true; right: true }
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screen-corner-br"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {} // Empty input region to guarantee mouse passthrough

        Canvas {
            id: brCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = root.cornerColor;
                ctx.beginPath();
                ctx.moveTo(root.cornerRadius, root.cornerRadius);
                ctx.lineTo(root.cornerRadius, 0);
                ctx.arcTo(root.cornerRadius, root.cornerRadius, 0, root.cornerRadius, root.cornerRadius);
                ctx.lineTo(0, root.cornerRadius);
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
