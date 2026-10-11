import QtQuick 2.15

Rectangle {
    id: root
    property var card: null
    property bool faceDown: false
    property bool selected: false
    property bool dimmed: false
    property bool marked: false

    signal clicked()

    width: 64
    height: 92
    radius: 5
    color: faceDown ? "#1a4030" : "#f3ebe0"
    border.color: selected || marked ? "#c9a227" : "#1a1410"
    border.width: selected || marked ? 2 : 1
    opacity: dimmed ? 0.45 : 1
    scale: selected ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // Face-down fill (ternary inline Gradient { } is invalid QML syntax).
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: faceDown
        gradient: Gradient {
            GradientStop { position: 0; color: "#1e5a42" }
            GradientStop { position: 1; color: "#0f3024" }
        }
    }

    // back pattern
    Rectangle {
        visible: faceDown
        anchors.fill: parent
        anchors.margins: 8
        radius: 3
        color: "transparent"
        border.color: "#c9a22766"
        border.width: 1
    }

    Column {
        visible: !faceDown && card
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 0
        Text {
            text: card ? card.rank : ""
            color: card && (card.suit === "d" || card.suit === "h") ? "#b33a3a" : "#1a1410"
            font.family: "Libre Baskerville"
            font.pixelSize: 16
            font.bold: true
        }
        Text {
            text: {
                if (!card)
                    return ""
                if (card.suit === "c") return "♣"
                if (card.suit === "d") return "♦"
                if (card.suit === "h") return "♥"
                return "♠"
            }
            color: card && (card.suit === "d" || card.suit === "h") ? "#b33a3a" : "#1a1410"
            font.pixelSize: 18
        }
    }

    Text {
        visible: !faceDown && card
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        text: {
            if (!card)
                return ""
            if (card.suit === "c") return "♣"
            if (card.suit === "d") return "♦"
            if (card.suit === "h") return "♥"
            return "♠"
        }
        color: card && (card.suit === "d" || card.suit === "h") ? "#b33a3a" : "#1a1410"
        font.pixelSize: 16
        rotation: 180
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
