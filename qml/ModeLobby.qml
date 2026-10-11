import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property var net: null

    signal playAi()
    signal hostOnline()
    signal joinOnline(string code)

    readonly property color cream: "#f3ebe0"
    readonly property color muted: "#c4b8a8"
    readonly property color gold: "#c9a227"
    readonly property color line: "#f3ebe033"

    property real drift: 0

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0a2018" }
            GradientStop { position: 0.4; color: "#0f3a2c" }
            GradientStop { position: 0.75; color: "#145a43" }
            GradientStop { position: 1; color: "#1a2a20" }
        }
    }

    // Soft felt shimmer — motion #1
    Rectangle {
        width: parent.width * 0.7
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Math.sin(root.drift) * 12
        y: parent.height * 0.15 - height * 0.2
        color: "#2a8f68"
        opacity: 0.08 + Math.sin(root.drift * 0.9) * 0.02
        scale: 1 + Math.sin(root.drift * 0.7) * 0.03
    }

    // Fan of decorative cards — motion #2 (slow sway)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08
        spacing: -28
        opacity: 0.35
        rotation: Math.sin(root.drift * 0.5) * 2
        Repeater {
            model: ["A♠", "10♦", "K♥", "2♣", "Q♦"]
            delegate: Rectangle {
                width: 54
                height: 78
                radius: 4
                color: "#f3ebe0"
                border.color: "#1a1410"
                border.width: 1
                rotation: (index - 2) * 8
                y: Math.abs(index - 2) * 6
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: modelData.indexOf("♥") >= 0 || modelData.indexOf("♦") >= 0 ? "#b33a3a" : "#1a1410"
                    font.family: "Libre Baskerville"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    Timer {
        interval: 40
        running: root.visible
        repeat: true
        onTriggered: root.drift += 0.04
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -24
        width: Math.min(parent.width - 48, 400)
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Tablić"
            color: cream
            font.family: "Libre Baskerville"
            font.pixelSize: 56
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
            scale: 0.96
            transformOrigin: Item.Center
            SequentialAnimation on opacity {
                running: true
                NumberAnimation { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
            }
            SequentialAnimation on scale {
                running: true
                NumberAnimation { from: 0.94; to: 1; duration: 800; easing.type: Easing.OutCubic }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Capture the table, race to 101 — vs PC or online."
            color: muted
            font.family: "Source Sans 3"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
            NumberAnimation on opacity { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        }

        Item { Layout.preferredHeight: 12 }

        Button {
            id: onlineHost
            Layout.fillWidth: true
            text: "Host online match"
            onClicked: root.hostOnline()
            contentItem: Text {
                text: onlineHost.text
                color: "#12100e"
                font.family: "Source Sans 3"
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 46
                color: onlineHost.down ? "#e0c35a" : gold
                radius: 3
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: joinField
                Layout.fillWidth: true
                placeholderText: "Room code"
                color: cream
                font.family: "Source Sans 3"
                font.pixelSize: 14
                font.capitalization: Font.AllUppercase
                background: Rectangle {
                    color: "#0a1812"
                    border.color: line
                    border.width: 1
                    radius: 3
                    implicitHeight: 46
                }
            }
            Button {
                id: joinBtn
                text: "Join"
                onClicked: root.joinOnline(joinField.text)
                contentItem: Text {
                    text: joinBtn.text
                    color: cream
                    font.family: "Source Sans 3"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 88
                    implicitHeight: 46
                    color: "#1a4030"
                    border.color: line
                    border.width: 1
                    radius: 3
                }
            }
        }

        Button {
            id: aiBtn
            Layout.fillWidth: true
            text: "Play against PC"
            onClicked: root.playAi()
            contentItem: Text {
                text: aiBtn.text
                color: cream
                font.family: "Source Sans 3"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 42
                color: "transparent"
                border.color: line
                border.width: 1
                radius: 3
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: {
                if (!net)
                    return ""
                if (net.status === "error")
                    return net.detail
                if (net.role === "host" && net.roomCode)
                    return "Your code: " + net.roomCode + (net.detail ? "\n" + net.detail : "")
                return net.detail || (net.logosAvailable ? "Online via Logos delivery (logos.dev)." : "Preview mode — online needs Basecamp.")
            }
            color: net && net.status === "error" ? "#e07060" : muted
            font.family: "Source Sans 3"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
