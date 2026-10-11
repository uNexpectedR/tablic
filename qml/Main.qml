import QtQuick 2.15
import QtQuick.Controls 2.15

/*
  Entry view for Basecamp ui_qml (metadata "view": "qml/Main.qml").

  Children load via Qt.resolvedUrl so a type-cache / qmldir failure cannot
  blank the whole tab — errors stay on-screen and in console/basecamp.log.
*/
Item {
    id: root
    width: 960
    height: 640

    property string screen: "lobby" // lobby | play
    property string bootError: ""

    function noteError(where, err) {
        var msg = String(err || "load failed")
        console.error("Tablić", where + ":", msg)
        if (!root.bootError)
            root.bootError = where + ": " + msg
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0a2018" }
            GradientStop { position: 1; color: "#0c3d2e" }
        }
    }

    Column {
        z: 100
        anchors.centerIn: parent
        spacing: 10
        width: Math.min(parent.width - 48, 440)
        visible: root.bootError.length > 0
                 || netLoader.status === Loader.Loading
                 || netLoader.status === Loader.Null
                 || (netLoader.status === Loader.Ready && lobbyLoader.status === Loader.Loading)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.bootError.length ? "Tablić could not open" : "Tablić"
            color: "#f3ebe0"
            font.family: "Libre Baskerville"
            font.pixelSize: 32
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: root.bootError.length ? "#e07060" : "#c4b8a8"
            font.family: "Source Sans 3"
            font.pixelSize: 13
            text: root.bootError.length
                  ? root.bootError
                  : "Starting…"
        }
    }

    Loader {
        id: netLoader
        source: Qt.resolvedUrl("TablicNet.qml")
        onStatusChanged: {
            if (status === Loader.Error)
                root.noteError("TablicNet", sourceComponent ? sourceComponent.errorString() : "")
        }
    }

    Loader {
        id: lobbyLoader
        anchors.fill: parent
        active: netLoader.status === Loader.Ready && !root.bootError
        source: active ? Qt.resolvedUrl("TablicLobby.qml") : ""
        visible: root.screen === "lobby" && status === Loader.Ready
        onStatusChanged: {
            if (status === Loader.Error)
                root.noteError("TablicLobby", sourceComponent ? sourceComponent.errorString() : "")
        }
        onLoaded: {
            item.net = netLoader.item
            item.playAi.connect(function () {
                netLoader.item.startAi()
                if (!tableLoader.item)
                    return
                tableLoader.item.localSeat = 0
                tableLoader.item.role = "ai"
                tableLoader.item.restart()
                root.screen = "play"
            })
            item.hostOnline.connect(function () { netLoader.item.hostGame() })
            item.joinOnline.connect(function (code) { netLoader.item.joinGame(code) })
        }
    }

    Loader {
        id: tableLoader
        anchors.fill: parent
        active: netLoader.status === Loader.Ready && !root.bootError
        source: active ? Qt.resolvedUrl("TablicTable.qml") : ""
        visible: root.screen === "play" && status === Loader.Ready
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        onStatusChanged: {
            if (status === Loader.Error)
                root.noteError("TablicTable", sourceComponent ? sourceComponent.errorString() : "")
        }
        onLoaded: {
            item.moveIntent.connect(function (msg) { netLoader.item.broadcastMove(msg) })
            item.menuRequested.connect(function () {
                root.screen = "lobby"
                item.match = null
            })
        }
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.screen = "lobby"
                event.accepted = true
            }
        }
        focus: visible
    }

    Connections {
        target: netLoader.item
        enabled: netLoader.status === Loader.Ready
        function onMatchReady(seed) {
            if (!tableLoader.item)
                return
            tableLoader.item.localSeat = netLoader.item.localSeat
            tableLoader.item.role = netLoader.item.role
            tableLoader.item.restart(seed)
            root.screen = "play"
        }
        function onRemoteMove(msg) {
            if (tableLoader.item)
                tableLoader.item.applyRemoteMove(msg)
        }
    }

    Component.onCompleted: console.log("Tablić Main.qml ready (0.4.2)")
}
