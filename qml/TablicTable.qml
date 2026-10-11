import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "."
import "js/Theme.js" as T
import "js/Game.js" as Game
import "js/Cards.js" as Cards
import "js/Ai.js" as Ai

Item {
    id: root

    property var match: null
    property int localSeat: 0
    property string role: "ai"

    signal moveIntent(var msg)
    signal menuRequested()
    signal nextRoundRequested()

    property int selectedCardId: -1
    property var selectedCapture: []
    property int aceAs: 11
    property int optionIndex: 0
    property var currentOptions: []
    property int tick: 0
    property int dealGen: 0

    readonly property int viewSeat: localSeat
    readonly property int aiSeat: 1
    readonly property bool myTurn: match && match.phase === "play" && match.turn === localSeat
    readonly property bool aiTurn: role === "ai" && match && match.phase === "play" && match.turn === aiSeat
    readonly property var myHand: (tick, match && match.players) ? match.players[viewSeat].hand : []
    readonly property int oppHandCount: (tick, match && match.players) ? match.players[oppSeat].hand.length : 0
    readonly property int tableCount: (tick, match) ? match.table.length : 0
    readonly property var oppSeat: viewSeat === 0 ? 1 : 0

    Timer {
        id: aiTimer
        interval: 520
        repeat: false
        onTriggered: root.playAiMove()
    }

    function scheduleAi() {
        if (aiTurn)
            aiTimer.restart()
    }

    function playAiMove() {
        if (!aiTurn)
            return
        var mv = Ai.chooseMove(match, aiSeat)
        if (!mv)
            return
        var result = Game.playMove(match, aiSeat, mv.cardId, mv.captureIds || [], mv.aceAs || 1)
        if (!result.ok)
            return
        clearSelection()
        bumpMatch()
        tick++
        scheduleAi()
    }

    function restart(seed) {
        aiTimer.stop()
        match = Game.newMatch(seed === undefined ? Date.now() : seed)
        clearSelection()
        dealGen++
        tick++
        scheduleAi()
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
        var msg = { t: "move", seat: seat, cardId: selectedCardId, captureIds: ids, aceAs: aceAs }
        var result = Game.playMove(match, seat, selectedCardId, ids, aceAs)
        if (!result.ok)
            return
        clearSelection()
        bumpMatch()
        tick++
        moveIntent(msg)
        scheduleAi()
    }

    function applyRemoteMove(msg) {
        if (!match || !msg)
            return
        if (msg.t === "next") {
            Game.continueMatch(match)
            clearSelection()
            dealGen++
            bumpMatch()
            tick++
            return
        }
        if (msg.t !== "move" || msg.seat === localSeat)
            return
        var result = Game.playMove(match, msg.seat, msg.cardId, msg.captureIds || [], msg.aceAs || 1)
        if (result.ok) {
            clearSelection()
            bumpMatch()
            tick++
        }
    }

    function continueRound() {
        if (!match || match.phase !== "scoring")
            return
        Game.continueMatch(match)
        clearSelection()
        dealGen++
        bumpMatch()
        tick++
        moveIntent({ t: "next" })
        nextRoundRequested()
        scheduleAi()
    }

    function bumpMatch() {
        match = match
    }

    function isMarked(id) {
        return selectedCapture.indexOf(id) >= 0
    }

    // Felt room
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: T.feltDeep }
            GradientStop { position: 0.5; color: T.feltMid }
            GradientStop { position: 1; color: "#081810" }
        }
    }

    // Oval table
    Rectangle {
        id: felt
        width: Math.min(parent.width - 48, 640)
        height: Math.min(parent.height * 0.52, 320)
        radius: height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -12
        gradient: Gradient {
            GradientStop { position: 0; color: "#1a6a4c" }
            GradientStop { position: 0.55; color: "#124a36" }
            GradientStop { position: 1; color: "#0c3226" }
        }
        border.color: "#c9a22740"
        border.width: 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: height
            color: "transparent"
            border.color: "#00000022"
            border.width: 1
        }
    }

    // Top bar
    RowLayout {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12

        Text {
            text: "Tablić"
            color: T.cream
            font.family: T.displayFont
            font.pixelSize: 24
        }
        Item { Layout.fillWidth: true }
        Text {
            text: {
                if (!match)
                    return ""
                if (role === "ai")
                    return "You " + match.players[0].score + "  ·  PC " + match.players[1].score + "  →  101"
                return "P1 " + match.players[0].score + "  ·  P2 " + match.players[1].score + "  →  101"
            }
            color: T.inkSoft
            font.family: T.bodyFont
            font.pixelSize: 14
        }
        Button {
            text: "Menu"
            onClicked: root.menuRequested()
            contentItem: Text {
                text: parent.text
                color: T.cream
                font.family: T.bodyFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitWidth: 68
                implicitHeight: 32
                color: "transparent"
                border.color: T.line
                radius: 4
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topBar.bottom
        anchors.topMargin: 2
        text: {
            if (!match)
                return ""
            if (match.phase === "over")
                return match.message
            if (match.phase === "scoring")
                return match.message + "  ·  Continue for next deal"
            var who = match.turn === localSeat
                ? "Your turn"
                : (role === "ai" ? "PC thinking…" : "Opponent's turn")
            var tabla = match.message.indexOf("Tabla") >= 0 ? "  ·  Tabla!" : ""
            return who + "  ·  stock " + match.stock.length + tabla
        }
        color: T.brassHot
        font.family: T.bodyFont
        font.pixelSize: 13
    }

    // Opponent backs
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 62
        spacing: -40
        Repeater {
            model: oppHandCount
            TablicCard {
                faceDown: true
                scale: 0.7
                dealIndex: index
                enabled: false
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 56
        text: (tick, match)
            ? ("captured " + match.players[oppSeat].captured.length + " · T" + match.roundTablas[oppSeat])
            : ""
        color: "#c4b8a870"
        font.family: T.bodyFont
        font.pixelSize: 11
    }

    // Table cards on felt
    Flow {
        id: tableFlow
        anchors.centerIn: felt
        width: Math.min(felt.width - 56, 480)
        spacing: 12
        Repeater {
            model: tableCount
            TablicCard {
                // dealGen forces re-deal animation on new rounds
                dealIndex: (dealGen * 8 + index) % 12
                card: match.table[index]
                marked: root.isMarked(match.table[index].id)
                dimmed: root.selectedCardId >= 0 && !marked && currentOptions.length > 0
                onClicked: root.toggleTableCard(match.table[index].id)
            }
        }
        Text {
            visible: match && tableCount === 0 && match.phase === "play"
            text: "Table clear — drop a card"
            color: T.cream
            opacity: 0.55
            font.family: T.bodyFont
            font.pixelSize: 14
            width: tableFlow.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: 36
        }
    }

    // Action strip
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: handRow.top
        anchors.bottomMargin: 14
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
                color: T.cream
                font.family: T.bodyFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 36
                implicitWidth: 90
                color: "#143528"
                radius: 4
            }
        }
        Button {
            visible: currentOptions.length > 1
            text: "Next take"
            onClicked: root.cycleOption()
            contentItem: Text {
                text: parent.text
                color: T.cream
                font.family: T.bodyFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 36
                implicitWidth: 90
                color: "#143528"
                radius: 4
            }
        }
        Button {
            text: selectedCapture.length ? "Take" : "Drop"
            onClicked: root.commitPlay()
            contentItem: Text {
                text: parent.text
                color: T.ink
                font.family: T.bodyFont
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitHeight: 36
                implicitWidth: 96
                color: T.brass
                radius: 4
            }
        }
    }

    // Scoring / over
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        visible: match && (match.phase === "scoring" || match.phase === "over")
        z: 5

        Rectangle {
            width: 340
            height: 168
            radius: 8
            color: T.panel
            border.color: "#c9a22755"
            Column {
                anchors.centerIn: parent
                spacing: 10
                width: parent.width - 36
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: match ? match.message : ""
                    color: T.cream
                    font.family: T.displayFont
                    font.pixelSize: 17
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: match && match.phase === "scoring"
                    text: match
                        ? ("Cards " + match.players[0].roundCards + "–" + match.players[1].roundCards
                           + "  ·  Tablas " + match.roundTablas[0] + "–" + match.roundTablas[1])
                        : ""
                    color: T.inkSoft
                    font.family: T.bodyFont
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
                        color: T.ink
                        font.family: T.bodyFont
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitHeight: 38
                        implicitWidth: 148
                        color: T.brass
                        radius: 4
                    }
                }
            }
        }
    }

    // Own hand — slight fan
    Row {
        id: handRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: -6
        Repeater {
            model: myHand.length
            TablicCard {
                card: myHand[index]
                dealIndex: index
                selected: selectedCardId === myHand[index].id
                dimmed: !myTurn
                enabled: myTurn
                rotation: (index - (myHand.length - 1) / 2) * 3.5
                transformOrigin: Item.Bottom
                onClicked: root.selectHandCard(myHand[index].id)
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        text: match
            ? ("you captured " + match.players[viewSeat].captured.length + " · T" + match.roundTablas[viewSeat])
            : ""
        color: "#c4b8a870"
        font.family: T.bodyFont
        font.pixelSize: 11
    }
}
