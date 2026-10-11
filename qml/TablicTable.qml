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

    // none | table (take) | hand (drop)
    property string selectMode: "none"
    property int selectedCardId: -1
    property var selectedCapture: []
    property int aceAs: 11
    property int tick: 0
    property int dealGen: 0
    property int pileOpen: -1 // seat whose captured pile is open, or -1

    readonly property int viewSeat: localSeat
    readonly property int aiSeat: 1
    readonly property bool myTurn: match && match.phase === "play" && match.turn === localSeat
    readonly property bool aiTurn: role === "ai" && match && match.phase === "play" && match.turn === aiSeat
    readonly property var myHand: (tick, match && match.players) ? match.players[viewSeat].hand : []
    readonly property int oppHandCount: (tick, match && match.players) ? match.players[oppSeat].hand.length : 0
    readonly property int tableCount: (tick, match) ? match.table.length : 0
    readonly property var oppSeat: viewSeat === 0 ? 1 : 0
    readonly property var myCaptured: (tick, match && match.players) ? match.players[viewSeat].captured : []
    readonly property var oppCaptured: (tick, match && match.players) ? match.players[oppSeat].captured : []

    Timer {
        id: aiTimer
        interval: 520
        repeat: false
        onTriggered: root.playAiMove()
    }

    function scheduleAi(extraMs) {
        if (!aiTurn)
            return
        aiTimer.interval = 520 + (extraMs || 0)
        aiTimer.restart()
    }

    function gatherTakeCards(seat, cardId, captureIds) {
        var out = []
        var handCard = Cards.findById(match.players[seat].hand, cardId)
        if (handCard)
            out.push(Cards.cloneCard(handCard))
        var ids = captureIds || []
        for (var i = 0; i < ids.length; i++) {
            var c = Cards.findById(match.table, ids[i])
            if (c)
                out.push(Cards.cloneCard(c))
        }
        return out
    }

    function flyCapture(seat, cards) {
        if (!cards || !cards.length)
            return
        var pile = seat === viewSeat ? myPile : oppPile
        var sy = seat === viewSeat ? felt.height * 0.55 : felt.height * 0.38
        var start = felt.mapToItem(flyLayer, felt.width * 0.5, sy)
        var end = pile.mapToItem(flyLayer, pile.width * 0.5, pile.height * 0.5)
        for (var i = 0; i < cards.length; i++) {
            flyerComponent.createObject(flyLayer, {
                card: cards[i],
                startX: start.x - T.cardW * 0.35 + i * 12,
                startY: start.y - T.cardH * 0.35 + (i % 2) * 6,
                endX: end.x - T.cardW * 0.22 + i * 3,
                endY: end.y - T.cardH * 0.22,
                delayMs: i * 52,
                twist: seat === viewSeat ? -8 + i * 3 : 8 - i * 3
            })
        }
    }

    function playAiMove() {
        if (!aiTurn)
            return
        var mv = Ai.chooseMove(match, aiSeat)
        if (!mv)
            return
        var ids = mv.captureIds || []
        var flight = ids.length ? gatherTakeCards(aiSeat, mv.cardId, ids) : []
        var result = Game.playMove(match, aiSeat, mv.cardId, ids, mv.aceAs || 1)
        if (!result.ok)
            return
        if (flight.length)
            flyCapture(aiSeat, flight)
        clearSelection()
        bumpMatch()
        tick++
        scheduleAi(flight.length ? 420 : 0)
    }

    function restart(seed) {
        aiTimer.stop()
        match = Game.newMatch(seed === undefined ? Date.now() : seed)
        clearSelection()
        pileOpen = -1
        dealGen++
        tick++
        scheduleAi()
    }

    function clearSelection() {
        selectMode = "none"
        selectedCardId = -1
        selectedCapture = []
        aceAs = 11
    }

    function idsKey(ids) {
        return ids.slice().sort(function (a, b) { return a - b }).join(",")
    }

    function optionMatching(cardId, captureIds, asVal) {
        var opts = Game.legalCaptures(match, match.turn, cardId, asVal)
        var key = idsKey(captureIds)
        for (var i = 0; i < opts.length; i++) {
            if (idsKey(opts[i].captureIds) === key)
                return opts[i]
        }
        return null
    }

    function tryTakeWithHand(cardId) {
        if (!match || selectedCapture.length === 0)
            return false
        var card = Cards.findById(match.players[match.turn].hand, cardId)
        if (!card)
            return false

        var asVals = card.rank === "A" ? [aceAs, aceAs === 11 ? 1 : 11] : [1]
        for (var i = 0; i < asVals.length; i++) {
            if (optionMatching(cardId, selectedCapture, asVals[i])) {
                aceAs = asVals[i]
                selectedCardId = cardId
                selectMode = "table"
                commitPlay(selectedCapture.slice())
                return true
            }
        }
        // Hand card cannot take this set — select it for drop instead
        selectedCapture = []
        selectedCardId = cardId
        selectMode = "hand"
        if (card.rank === "A")
            aceAs = 11
        tick++
        return false
    }

    function selectHandCard(cardId) {
        if (!myTurn)
            return
        if (selectMode === "table" && selectedCapture.length > 0) {
            tryTakeWithHand(cardId)
            return
        }
        if (selectedCardId === cardId && selectMode === "hand") {
            clearSelection()
            tick++
            return
        }
        selectedCapture = []
        selectedCardId = cardId
        selectMode = "hand"
        var card = Cards.findById(match.players[match.turn].hand, cardId)
        if (card && card.rank === "A")
            aceAs = 11
        tick++
    }

    function toggleTableCard(cardId) {
        if (!myTurn)
            return
        if (selectMode === "hand") {
            selectedCardId = -1
            selectedCapture = []
            selectMode = "table"
        }
        if (selectMode === "none")
            selectMode = "table"

        var next = selectedCapture.slice()
        var idx = next.indexOf(cardId)
        if (idx >= 0)
            next.splice(idx, 1)
        else
            next.push(cardId)
        selectedCapture = next
        if (selectedCapture.length === 0) {
            selectMode = "none"
            selectedCardId = -1
        }
        tick++
    }

    function toggleAce() {
        if (selectedCardId < 0 || !match)
            return
        var card = Cards.findById(match.players[match.turn].hand, selectedCardId)
        if (!card || card.rank !== "A")
            return
        aceAs = aceAs === 11 ? 1 : 11
        tick++
    }

    function commitPlay(capture) {
        if (!match || !myTurn || selectedCardId < 0)
            return
        var ids = capture === undefined ? [] : capture
        if (selectMode === "hand")
            ids = []
        var seat = match.turn
        var flight = ids.length ? gatherTakeCards(seat, selectedCardId, ids) : []
        var msg = { t: "move", seat: seat, cardId: selectedCardId, captureIds: ids, aceAs: aceAs }
        var result = Game.playMove(match, seat, selectedCardId, ids, aceAs)
        if (!result.ok)
            return
        if (flight.length)
            flyCapture(seat, flight)
        clearSelection()
        bumpMatch()
        tick++
        moveIntent(msg)
        scheduleAi(flight.length ? 420 : 0)
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
        var ids = msg.captureIds || []
        var flight = ids.length ? gatherTakeCards(msg.seat, msg.cardId, ids) : []
        var result = Game.playMove(match, msg.seat, msg.cardId, ids, msg.aceAs || 1)
        if (result.ok) {
            if (flight.length)
                flyCapture(msg.seat, flight)
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

    function openPile(seat) {
        if (!match || !match.players[seat].captured.length)
            return
        pileOpen = seat
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
        id: statusLine
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
            if (myTurn && selectMode === "table" && selectedCapture.length)
                return "Table marked — tap a hand card to take"
            if (myTurn && selectMode === "hand")
                return "Drop this card, or tap the table to take instead"
            var who = match.turn === localSeat
                ? "Your turn — table first to take, or hand to drop"
                : (role === "ai" ? "PC thinking…" : "Opponent's turn")
            var tabla = match.message.indexOf("Tabla") >= 0 ? "  ·  Tabla!" : ""
            return who + "  ·  stock " + match.stock.length + tabla
        }
        color: T.brassHot
        font.family: T.bodyFont
        font.pixelSize: 13
    }

    // Opponent hand
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

    // Opponent capture stack (top-right)
    Item {
        id: oppPile
        width: 56
        height: 78
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 18
        anchors.topMargin: 70
        visible: match !== null
        opacity: oppCaptured.length ? 1 : 0.35

        Repeater {
            model: Math.min(3, oppCaptured.length)
            Rectangle {
                width: 48
                height: 68
                radius: 5
                x: index * 3
                y: index * 2
                color: T.feltMid
                border.color: T.brass
                border.width: 1
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1a6b4c" }
                    GradientStop { position: 1; color: "#0c3528" }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: oppCaptured.length ? String(oppCaptured.length) : "0"
            color: T.cream
            font.family: T.displayFont
            font.pixelSize: 16
            font.bold: true
            z: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            text: role === "ai" ? "PC" : "Opp"
            color: "#c4b8a870"
            font.family: T.bodyFont
            font.pixelSize: 10
        }
        MouseArea {
            anchors.fill: parent
            enabled: oppCaptured.length > 0
            onClicked: root.openPile(oppSeat)
        }
    }

    // Table cards — 2 columns (2×2 when four)
    Grid {
        id: tableGrid
        anchors.centerIn: felt
        columns: 2
        rowSpacing: 12
        columnSpacing: 14
        Repeater {
            model: tableCount
            TablicCard {
                dealIndex: (dealGen * 8 + index) % 12
                card: match.table[index]
                marked: root.isMarked(match.table[index].id)
                dimmed: selectMode === "hand"
                onClicked: root.toggleTableCard(match.table[index].id)
            }
        }
    }

    Text {
        anchors.centerIn: felt
        visible: match && tableCount === 0 && match.phase === "play"
        text: "Table clear — drop a card"
        color: T.cream
        opacity: 0.55
        font.family: T.bodyFont
        font.pixelSize: 14
        z: 1
    }

    // Drop / Ace strip (hand-first only)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: handRow.top
        anchors.bottomMargin: 14
        spacing: 8
        visible: match && match.phase === "play" && myTurn && selectMode === "hand" && selectedCardId >= 0

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
            text: "Drop"
            onClicked: root.commitPlay([])
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

    // Own hand
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

    // Your capture stack (bottom-left)
    Item {
        id: myPile
        width: 56
        height: 78
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        visible: match !== null
        opacity: myCaptured.length ? 1 : 0.35

        Repeater {
            model: Math.min(3, myCaptured.length)
            Rectangle {
                width: 48
                height: 68
                radius: 5
                x: index * 3
                y: -index * 2
                color: T.feltMid
                border.color: T.brass
                border.width: 1
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1a6b4c" }
                    GradientStop { position: 1; color: "#0c3528" }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: myCaptured.length ? String(myCaptured.length) : "0"
            color: T.cream
            font.family: T.displayFont
            font.pixelSize: 16
            font.bold: true
            z: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 2
            text: "You · T" + (match ? match.roundTablas[viewSeat] : 0)
            color: "#c4b8a870"
            font.family: T.bodyFont
            font.pixelSize: 10
        }
        MouseArea {
            anchors.fill: parent
            enabled: myCaptured.length > 0
            onClicked: root.openPile(viewSeat)
        }
    }

    // Capture fly layer (cards animate into the correct seat pile)
    Item {
        id: flyLayer
        anchors.fill: parent
        z: 15
    }

    Component {
        id: flyerComponent
        Item {
            id: flyer
            property var card: null
            property real startX: 0
            property real startY: 0
            property real endX: 0
            property real endY: 0
            property int delayMs: 0
            property real twist: 0

            width: T.cardW
            height: T.cardH
            x: startX
            y: startY
            opacity: 0
            scale: 0.82
            rotation: twist * 0.35
            transformOrigin: Item.Center

            TablicCard {
                anchors.fill: parent
                card: flyer.card
                dealIndex: 0
                enabled: false
            }

            SequentialAnimation {
                id: flightAnim
                PauseAnimation { duration: flyer.delayMs }
                ParallelAnimation {
                    NumberAnimation {
                        target: flyer
                        property: "opacity"
                        to: 1
                        duration: 70
                    }
                    NumberAnimation {
                        target: flyer
                        property: "x"
                        to: flyer.endX
                        duration: 420
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: flyer
                        property: "y"
                        to: flyer.endY
                        duration: 420
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: flyer
                        property: "scale"
                        to: 0.28
                        duration: 420
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: flyer
                        property: "rotation"
                        to: flyer.twist
                        duration: 420
                        easing.type: Easing.OutQuad
                    }
                }
                NumberAnimation {
                    target: flyer
                    property: "opacity"
                    to: 0
                    duration: 110
                }
                ScriptAction { script: flyer.destroy() }
            }

            Component.onCompleted: flightAnim.start()
        }
    }

    // Pile viewer overlay
    Rectangle {
        anchors.fill: parent
        color: "#06140fcc"
        visible: pileOpen >= 0
        z: 20
        MouseArea {
            anchors.fill: parent
            onClicked: root.pileOpen = -1
        }

        Rectangle {
            width: Math.min(parent.width - 48, 520)
            height: Math.min(parent.height - 80, 360)
            anchors.centerIn: parent
            radius: 10
            color: T.panel
            border.color: "#c9a22766"
            MouseArea { anchors.fill: parent } // swallow

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    width: parent.width
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (pileOpen < 0 || !match)
                                return ""
                            if (pileOpen === viewSeat)
                                return "Your captures (" + myCaptured.length + ")"
                            return (role === "ai" ? "PC" : "Opponent") + " captures (" + oppCaptured.length + ")"
                        }
                        color: T.cream
                        font.family: T.displayFont
                        font.pixelSize: 18
                    }
                    Button {
                        text: "Close"
                        onClicked: root.pileOpen = -1
                        contentItem: Text {
                            text: parent.text
                            color: T.cream
                            font.family: T.bodyFont
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitWidth: 72
                            implicitHeight: 32
                            color: "#143528"
                            radius: 4
                        }
                    }
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 52
                    contentWidth: width
                    contentHeight: pileFlow.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    Flow {
                        id: pileFlow
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: pileOpen === viewSeat ? myCaptured.length
                                 : (pileOpen === oppSeat ? oppCaptured.length : 0)
                            TablicCard {
                                card: pileOpen === viewSeat ? myCaptured[index] : oppCaptured[index]
                                dealIndex: 0
                                scale: 0.85
                                enabled: false
                            }
                        }
                    }
                }
            }
        }
    }
}
