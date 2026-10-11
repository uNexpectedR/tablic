import QtQuick 2.15
import "js/Theme.js" as T
import "js/Cards.js" as Cards

Item {
    id: root
    property var card: null
    property bool faceDown: false
    property bool selected: false
    property bool dimmed: false
    property bool marked: false
    property int dealIndex: 0

    signal clicked()

    width: T.cardW
    height: T.cardH

    property real pulse: 1
    property real dealY: 20
    property real dealOp: 0

    scale: pulse * (selected ? 1.08 : 1)
    y: selected ? -10 : 0
    z: selected ? 2 : 0
    opacity: dealOp * (dimmed ? 0.42 : 1)

    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Soft shadow
    Rectangle {
        anchors.fill: face
        radius: T.cardR + 1
        color: "#00000050"
        x: 1
        y: selected ? 5 : 2
        z: -1
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: T.cardR
        color: faceDown ? T.feltMid : T.ivory
        border.width: selected || marked ? 2 : 1
        border.color: selected || marked ? T.brass : (faceDown ? "#0a1f18" : "#2a2218")

        Item {
            anchors.fill: parent
            anchors.margins: 5
            visible: faceDown
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1a6b4c" }
                    GradientStop { position: 1; color: "#0c3528" }
                }
            }
            Repeater {
                model: 5
                Rectangle {
                    width: parent.width * 1.45
                    height: 1
                    color: "#c9a22730"
                    rotation: 34
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * 18 - 10
                }
            }
            Repeater {
                model: 5
                Rectangle {
                    width: parent.width * 1.45
                    height: 1
                    color: "#c9a22722"
                    rotation: -34
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * 18 - 2
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                color: "transparent"
                border.color: T.brass
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Т"
                    color: T.brass
                    font.family: T.displayFont
                    font.pixelSize: 14
                }
            }
        }

        Item {
            id: pips
            anchors.fill: parent
            visible: !faceDown && !!card
            readonly property bool red: card ? Cards.isRed(card) : false
            readonly property color pip: red ? T.crimson : T.ink
            readonly property string suit: card ? Cards.SUIT_LABEL[card.suit] : ""
            readonly property string rank: card ? card.rank : ""

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 7
                spacing: -2
                Text {
                    text: pips.rank
                    color: pips.pip
                    font.family: T.displayFont
                    font.pixelSize: pips.rank === "10" ? 15 : 17
                    font.bold: true
                }
                Text {
                    text: pips.suit
                    color: pips.pip
                    font.pixelSize: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                anchors.centerIn: parent
                text: pips.suit
                color: pips.pip
                font.pixelSize: 38
                opacity: 0.9
            }

            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 7
                spacing: -2
                rotation: 180
                Text {
                    text: pips.rank
                    color: pips.pip
                    font.family: T.displayFont
                    font.pixelSize: pips.rank === "10" ? 15 : 17
                    font.bold: true
                }
                Text {
                    text: pips.suit
                    color: pips.pip
                    font.pixelSize: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    transform: Translate { y: root.dealY }

    SequentialAnimation {
        id: capturePulse
        running: false
        NumberAnimation { target: root; property: "pulse"; to: 1.14; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 170; easing.type: Easing.OutCubic }
    }

    onMarkedChanged: if (marked) capturePulse.restart()

    ParallelAnimation {
        id: dealIn
        running: true
        NumberAnimation {
            target: root
            property: "dealY"
            from: 20
            to: 0
            duration: 260 + dealIndex * 32
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "dealOp"
            from: 0
            to: 1
            duration: 220 + dealIndex * 28
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
