import QtQuick 2.15
import QtQuick.Controls 2.15
import "."

Item {
    id: root
    width: 960
    height: 640

    property string screen: "lobby" // lobby | play

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0a2018" }
            GradientStop { position: 1; color: "#0c3d2e" }
        }
    }

    TablicNet {
        id: net
        onMatchReady: function (seed) {
            table.localSeat = net.localSeat
            table.role = net.role
            table.restart(seed)
            root.screen = "play"
        }
        onRemoteMove: function (msg) {
            table.applyRemoteMove(msg)
        }
    }

    TablicLobby {
        id: lobby
        anchors.fill: parent
        visible: root.screen === "lobby"
        net: net
        onPlayAi: {
            net.startAi()
            table.localSeat = 0
            table.role = "ai"
            table.restart()
            root.screen = "play"
        }
        onHostOnline: net.hostGame()
        onJoinOnline: function (code) { net.joinGame(code) }
    }

    TablicTable {
        id: table
        anchors.fill: parent
        visible: root.screen === "play"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        onMoveIntent: function (msg) {
            net.broadcastMove(msg)
        }
        onMenuRequested: {
            root.screen = "lobby"
            table.match = null
        }
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.screen = "lobby"
                event.accepted = true
            }
        }
        focus: visible
    }
}
