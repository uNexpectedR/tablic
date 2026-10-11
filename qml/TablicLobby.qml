import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/Theme.js" as T

Item {
    id: root
    property var net: null

    signal playAi()
    signal hostOnline()
    signal joinOnline(string code)

    // Atmosphere
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: T.feltDeep }
            GradientStop { position: 0.45; color: T.feltMid }
            GradientStop { position: 1; color: "#12261c" }
        }
    }

    // Soft light pool on felt
    Rectangle {
        width: parent.width * 0.85
        height: width * 0.55
        radius: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -40
        color: T.feltLite
        opacity: 0.12
        scale: 1
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 0.1; to: 0.16; duration: 4200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.16; to: 0.1; duration: 4200; easing.type: Easing.InOutSine }
        }
    }

    // Decorative card fan
    Row {
        id: fan
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.07
        spacing: -30
        opacity: 0.4
        property real sway: 0
        transform: Rotation {
            origin.x: fan.width / 2
            origin.y: fan.height
            angle: Math.sin(fan.sway) * 2.2
        }
        NumberAnimation on sway {
            from: 0; to: 6.28318
            duration: 9000
            loops: Animation.Infinite
        }
        Repeater {
            model: [
                { r: "A", s: "♠", red: false },
                { r: "10", s: "♦", red: true },
                { r: "K", s: "♥", red: true },
                { r: "2", s: "♣", red: false },
                { r: "Q", s: "♦", red: true }
            ]
            delegate: Rectangle {
                width: 56
                height: 80
                radius: 5
                color: T.ivory
                border.color: "#2a2218"
                border.width: 1
                rotation: (index - 2) * 9
                y: Math.abs(index - 2) * 7
                Text {
                    anchors.centerIn: parent
                    text: modelData.r + modelData.s
                    color: modelData.red ? T.crimson : T.ink
                    font.family: T.displayFont
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -28
        width: Math.min(parent.width - 48, 380)
        spacing: 10

        Text {
            id: title
            Layout.fillWidth: true
            text: "Tablić"
            color: T.cream
            font.family: T.displayFont
            font.pixelSize: 64
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
            scale: 0.94
            transformOrigin: Item.Center
            SequentialAnimation on opacity {
                NumberAnimation { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
            }
            SequentialAnimation on scale {
                NumberAnimation { from: 0.94; to: 1; duration: 780; easing.type: Easing.OutCubic }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Capture the table. First to 101."
            color: T.inkSoft
            font.family: T.bodyFont
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
            NumberAnimation on opacity { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        }

        Item { Layout.preferredHeight: 14 }

        Button {
            id: hostBtn
            Layout.fillWidth: true
            text: "Host online match"
            onClicked: root.hostOnline()
            contentItem: Text {
                text: hostBtn.text
                color: T.ink
                font.family: T.bodyFont
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 48
                color: hostBtn.down ? T.brassHot : T.brass
                radius: 4
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: joinField
                Layout.fillWidth: true
                placeholderText: "Room code"
                color: T.cream
                font.family: T.bodyFont
                font.pixelSize: 14
                font.capitalization: Font.AllUppercase
                background: Rectangle {
                    color: "#06140f"
                    border.color: T.line
                    border.width: 1
                    radius: 4
                    implicitHeight: 48
                }
            }
            Button {
                id: joinBtn
                text: "Join"
                onClicked: root.joinOnline(joinField.text)
                contentItem: Text {
                    text: joinBtn.text
                    color: T.cream
                    font.family: T.bodyFont
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: 92
                    implicitHeight: 48
                    color: "#143528"
                    border.color: T.line
                    border.width: 1
                    radius: 4
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
                color: T.cream
                font.family: T.bodyFont
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 44
                color: "transparent"
                border.color: T.line
                border.width: 1
                radius: 4
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: {
                if (!net)
                    return ""
                if (net.status === "error")
                    return net.detail
                if (net.role === "host" && net.roomCode)
                    return "Your code: " + net.roomCode + (net.detail ? "\n" + net.detail : "")
                return net.detail || (net.logosAvailable
                    ? "Online via Logos delivery."
                    : "Preview — online needs Basecamp.")
            }
            color: net && net.status === "error" ? "#e07060" : T.inkSoft
            font.family: T.bodyFont
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
