import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/Game.js" as Game
import "js/Cards.js" as Cards

Item {
    id: root

    property var match: null
    property int localSeat: -1   // -1 = hotseat (see current turn)
    property string role: "local"

    signal moveIntent(var msg)
    signal menuRequested()
    signal nextRoundRequested()

    property int selectedCardId: -1
    property var selectedCapture: []
    property int aceAs: 11
    property int optionIndex: 0
    property var currentOptions: []
    property int tick: 0

    readonly property int viewSeat: localSeat < 0
        ? (match ? match.turn : 0)
        : localSeat
    readonly property bool myTurn: match && match.phase === "play"
        && (localSeat < 0 || match.turn === localSeat)
    readonly property var myHand: (tick, match && match.players) ? match.players[viewSeat].hand : []
    readonly property int oppHandCount: (tick, match && match.players) ? match.players[oppSeat].hand.length : 0
    readonly property int tableCount: (tick, match) ? match.table.length : 0
    readonly property var oppSeat: viewSeat === 0 ? 1 : 0

    function restart(seed) {
        match = Game.newMatch(seed === undefined ? Date.now() : seed)
        clearSelection()
        tick++
    }

    function clearSelection() {
        selectedCardId = -1
        selectedCapture = []
        currentOptions = []
        optionIndex = 0
        aceAs = 11
    }

    function refreshOptions() {
        if (!match || selectedCardId < 0) {
            currentOptions = []
            selectedCapture = []
            return
        }
        var sug = Game.suggestCapture(match, match.turn, selectedCardId)
        aceAs = sug.aceAs
        currentOptions = Game.legalCaptures(match, match.turn, selectedCardId, aceAs)
        optionIndex = 0
        if (sug.option && currentOptions.length) {
            var want = sug.option.captureIds.slice().sort(function (a, b) { return a - b }).join(",")
            for (var i = 0; i < currentOptions.length; i++) {
                var got = currentOptions[i].captureIds.slice().sort(function (a, b) { return a - b }).join(",")
                if (got === want) {
                    optionIndex = i
                    break
                }
            }
            selectedCapture = currentOptions[optionIndex].captureIds.slice()
        } else {
            selectedCapture = []
        }
        tick++
    }

    function selectHandCard(cardId) {
        if (!myTurn)
            return
        if (localSeat >= 0 && match.turn !== localSeat)
            return
        if (selectedCardId === cardId) {
            clearSelection()
            tick++
            return
        }
        selectedCardId = cardId
        refreshOptions()
    }

    function toggleTableCard(cardId) {
        if (!myTurn || selectedCardId < 0)
            return
        var next = selectedCapture.slice()
        var idx = next.indexOf(cardId)
        if (idx >= 0)
            next.splice(idx, 1)
        else
            next.push(cardId)
        // validate against options
        var key = next.slice().sort(function (a, b) { return a - b }).join(",")
        for (var i = 0; i < currentOptions.length; i++) {
            var k = currentOptions[i].captureIds.slice().sort(function (a, b) { return a - b }).join(",")
            if (k === key) {
                selectedCapture = next
                optionIndex = i
                tick++
                return
            }
        }
        // if empty selection of captures is always ok (drop)
        if (next.length === 0) {
            selectedCapture = []
            tick++
        }
    }

    function cycleOption() {
        if (!currentOptions.length)
            return
        optionIndex = (optionIndex + 1) % currentOptions.length
        selectedCapture = currentOptions[optionIndex].captureIds.slice()
        tick++
    }

    function toggleAce() {
        if (selectedCardId < 0 || !match)
            return
        var card = Cards.findById(match.players[match.turn].hand, selectedCardId)
        if (!card || card.rank !== "A")
            return
        aceAs = aceAs === 11 ? 1 : 11
        refreshOptions()
    }

    function commitPlay(capture) {
        if (!match || !myTurn || selectedCardId < 0)
            return
        var ids = capture === undefined ? selectedCapture.slice() : capture
        var seat = match.turn
        var msg = {
            t: "move",
            seat: seat,
            cardId: selectedCardId,
            captureIds: ids,
            aceAs: aceAs
        }
        var result = Game.playMove(match, seat, selectedCardId, ids, aceAs)
        if (!result.ok)
            return
        clearSelection()
        matchChanged()
        tick++
        moveIntent(msg)
    }

    function applyRemoteMove(msg) {
        if (!match || !msg)
            return
        if (msg.t === "next") {
            Game.continueMatch(match)
            clearSelection()
            matchChanged()
            tick++
            return
        }
        if (msg.t !== "move")
            return
        // ignore echo of own seat when online
        if (localSeat >= 0 && msg.seat === localSeat)
            return
        var result = Game.playMove(match, msg.seat, msg.cardId, msg.captureIds || [], msg.aceAs || 1)
        if (result.ok) {
            clearSelection()
            matchChanged()
            tick++
        }
    }

    function continueRound() {
        if (!match || match.phase !== "scoring")
            return
        Game.continueMatch(match)
        clearSelection()
        matchChanged()
        tick++
        moveIntent({ t: "next" })
        nextRoundRequested()
    }

    function matchChanged() {
        // force property bindings that depend on nested fields
        match = match
    }

    function isMarked(id) {
        return selectedCapture.indexOf(id) >= 0
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0c3d2e" }
            GradientStop { position: 0.55; color: "#145a43" }
            GradientStop { position: 1; color: "#0a281c" }
        }
    }

    // Score / status bar
    RowLayout {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        Text {
            text: "Tablić"
            color: "#f3ebe0"
            font.family: "Libre Baskerville"
            font.pixelSize: 22
        }
        Item { Layout.fillWidth: true }
        Text {
            text: match
                  ? ("P1 " + match.players[0].score + "  ·  P2 " + match.players[1].score
                     + "  →  101")
                  : ""
            color: "#c4b8a8"
            font.family: "Source Sans 3"
            font.pixelSize: 14
        }
        Button {
            text: "Menu"
            onClicked: root.menuRequested()
            contentItem: Text {
                text: parent.text
                color: "#f3ebe0"
                font.family: "Source Sans 3"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitWidth: 64
                implicitHeight: 30
                color: "transparent"
                border.color: "#f3ebe033"
                radius: 3
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topBar.bottom
        anchors.topMargin: 4
        text: {
            if (!match)
                return ""
            if (match.phase === "over")
                return match.message
            if (match.phase === "scoring")
                return match.message + "  ·  Continue for next deal"
            var who = localSeat < 0
                      ? ("Player " + (match.turn + 1) + "'s turn")
                      : (match.turn === localSeat ? "Your turn" : "Opponent's turn")
            var tabla = match.message.indexOf("Tabla") >= 0 ? "  ·  Tabla!" : ""
            return who + "  ·  stock " + match.stock.length + tabla
        }
        color: "#e0c35a"
        font.family: "Source Sans 3"
        font.pixelSize: 13
    }

    // Opponent hand (backs)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 64
        spacing: -36
        Repeater {
            model: oppHandCount
            CardView {
                faceDown: true
                scale: 0.72
                enabled: false
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 58
        text: (tick, match) ? ("captured " + match.players[oppSeat].captured.length
                       + " · T" + match.roundTablas[oppSeat]) : ""
        color: "#c4b8a888"
        font.family: "Source Sans 3"
        font.pixelSize: 11
    }

    // Table (talon)
    Flow {
        id: tableFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        width: Math.min(parent.width - 48, 520)
        spacing: 10
        Repeater {
            model: tableCount
            CardView {
                card: match.table[index]
                marked: root.isMarked(match.table[index].id)
                dimmed: root.selectedCardId >= 0 && !marked && currentOptions.length > 0
                onClicked: root.toggleTableCard(match.table[index].id)
            }
        }
        Text {
            visible: match && tableCount === 0
            text: "Table clear — play a card"
            color: "#c4b8a8"
            font.family: "Source Sans 3"
            font.pixelSize: 14
            width: tableFlow.width
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Controls
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: handRow.top
        anchors.bottomMargin: 12
        spacing: 8
        visible: match && match.phase === "play" && myTurn && selectedCardId >= 0

        Button {
            visible: {
                if (!match || selectedCardId < 0)
                    return false
                var c = Cards.findById(match.players[match.turn].hand, selectedCardId)
                return c && c.rank === "A"
            }
            text: "Ace as " + aceAs
            onClicked: root.toggleAce()
            contentItem: Text {
                text: parent.text
                color: "#f3ebe0"
                font.family: "Source Sans 3"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 34
                implicitWidth: 88
                color: "#1a4030"
                radius: 3
            }
        }
        Button {
            visible: currentOptions.length > 1
            text: "Next take"
            onClicked: root.cycleOption()
            contentItem: Text {
                text: parent.text
                color: "#f3ebe0"
                font.family: "Source Sans 3"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 34
                implicitWidth: 88
                color: "#1a4030"
                radius: 3
            }
        }
        Button {
            text: selectedCapture.length ? "Take" : "Drop"
            onClicked: root.commitPlay()
            contentItem: Text {
                text: parent.text
                color: "#12100e"
                font.family: "Source Sans 3"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 34
                implicitWidth: 88
                color: "#c9a227"
                radius: 3
            }
        }
    }

    // Scoring / over overlay actions
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: match && (match.phase === "scoring" || match.phase === "over")
        z: 5

        Rectangle {
            width: 320
            height: 160
            radius: 6
            color: "#12100eee"
            border.color: "#c9a22766"
            Column {
                anchors.centerIn: parent
                spacing: 8
                width: parent.width - 32
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: match ? match.message : ""
                    color: "#f3ebe0"
                    font.family: "Libre Baskerville"
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: match && match.phase === "scoring"
                    text: match
                          ? ("Cards " + match.players[0].roundCards + "–" + match.players[1].roundCards
                             + "  ·  Tablas " + match.roundTablas[0] + "–" + match.roundTablas[1])
                          : ""
                    color: "#c4b8a8"
                    font.family: "Source Sans 3"
                    font.pixelSize: 12
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: match && match.phase === "over" ? "Back to lobby" : "Next deal"
                    onClicked: {
                        if (match.phase === "over")
                            root.menuRequested()
                        else
                            root.continueRound()
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#12100e"
                        font.family: "Source Sans 3"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitHeight: 36
                        implicitWidth: 140
                        color: "#c9a227"
                        radius: 3
                    }
                }
            }
        }
    }

    // Own hand
    Row {
        id: handRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 8
        Repeater {
            model: myHand.length
            CardView {
                card: myHand[index]
                selected: selectedCardId === myHand[index].id
                dimmed: !myTurn
                enabled: myTurn
                onClicked: root.selectHandCard(myHand[index].id)
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        text: match ? ("you captured " + match.players[viewSeat].captured.length
                       + " · T" + match.roundTablas[viewSeat]) : ""
        color: "#c4b8a888"
        font.family: "Source Sans 3"
        font.pixelSize: 11
    }
}
