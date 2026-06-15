import QtQuick

Item {
    id: root
    property real value: 0.0      // 0.0 to 1.0
    property color color: "#458588"
    property color bgColor: "#3c3836"
    property real lineWidth: 6
    
    Canvas {
        id: canvas
        anchors.fill: parent
        
        // Trigger repaint when properties change
        property real val: root.value
        property color col: root.color
        property color bgCol: root.bgColor
        property real lWidth: root.lineWidth
        
        onValChanged: requestPaint()
        onColChanged: requestPaint()
        onBgColChanged: requestPaint()
        onLWidthChanged: requestPaint()
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            
            var x = width / 2;
            var y = height / 2;
            var r = Math.min(width, height) / 2 - root.lineWidth;
            
            // Draw background circle arc (from 0.75 PI to 2.25 PI - bottom gap)
            ctx.beginPath();
            ctx.arc(x, y, r, 0.75 * Math.PI, 2.25 * Math.PI);
            ctx.strokeStyle = root.bgColor;
            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";
            ctx.stroke();
            
            // Draw progress arc
            if (root.value > 0.0) {
                ctx.beginPath();
                var endAngle = 0.75 * Math.PI + (Math.min(1.0, root.value) * 1.5 * Math.PI);
                ctx.arc(x, y, r, 0.75 * Math.PI, endAngle);
                ctx.strokeStyle = root.color;
                ctx.lineWidth = root.lineWidth;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
