.pragma library
.import "Cards.js" as Cards
.import "Capture.js" as Capture

/*! Two-player Serbian Tablić — deal, play, score to 101. */

var TARGET = 101
var HAND_SIZE = 6
var TABLE_OPEN = 4

function emptyPlayer() {
    return {
        hand: [],
        captured: [],
        tablas: 0,
        score: 0,
        roundCards: 0,
        roundPoints: 0
    }
}

function createMatch(seed) {
    return {
        seed: seed >>> 0,
        dealSeed: seed >>> 0,
        dealer: 0,
        turn: 1,
        phase: "play", // play | scoring | over
        stock: [],
        table: [],
        players: [emptyPlayer(), emptyPlayer()],
        lastCaptureSeat: -1,
        handIndex: 0,
        message: "",
        winner: -1,
        roundTablas: [0, 0]
    }
}

function dealHand(match) {
    // Two rounds of three cards each (Serbian deal), anticlockwise from dealer’s right.
    // Seat order for 2p: non-dealer first, then dealer.
    var order = [(match.dealer + 1) % 2, match.dealer]
    var dealt = 0
    for (var batch = 0; batch < 2; batch++) {
        for (var oi = 0; oi < order.length; oi++) {
            var p = order[oi]
            for (var k = 0; k < 3; k++) {
                if (!match.stock.length)
                    break
                match.players[p].hand.push(match.stock.shift())
                dealt++
            }
        }
    }
    if (!dealt)
        return false
    match.handIndex++
    return true
}

function startRound(match) {
    var deck = Cards.shuffle(Cards.makeDeck(), match.dealSeed)
    match.stock = deck
    match.table = []
    match.players[0].hand = []
    match.players[1].hand = []
    match.players[0].captured = []
    match.players[1].captured = []
    match.players[0].tablas = 0
    match.players[1].tablas = 0
    match.roundTablas = [0, 0]
    match.lastCaptureSeat = -1
    match.handIndex = 0
    match.phase = "play"
    match.message = ""
    match.winner = -1

    for (var i = 0; i < TABLE_OPEN; i++)
        match.table.push(match.stock.shift())
    dealHand(match)
    match.turn = (match.dealer + 1) % 2
    match.message = "Player " + (match.turn + 1) + " leads"
}

function newMatch(seed) {
    var m = createMatch(seed === undefined ? Date.now() : seed)
    startRound(m)
    return m
}

function handsEmpty(match) {
    return match.players[0].hand.length === 0 && match.players[1].hand.length === 0
}

function cardPoints(card) {
    if (card.rank === "A" || card.rank === "K" || card.rank === "Q" || card.rank === "J")
        return 1
    if (card.rank === "10" && card.suit === "d")
        return 2
    if (card.rank === "10")
        return 1
    if (card.rank === "2" && card.suit === "c")
        return 1
    return 0
}

function scorePile(cards) {
    var pts = 0
    for (var i = 0; i < cards.length; i++)
        pts += cardPoints(cards[i])
    return pts
}

function endRound(match) {
    // Leftover table → last capturer (Serbian rule); no tabla for this pickup.
    if (match.table.length && match.lastCaptureSeat >= 0) {
        var seat = match.lastCaptureSeat
        match.players[seat].captured = match.players[seat].captured.concat(match.table)
        match.table = []
    } else if (match.table.length) {
        // No captures all round — rare; give to dealer
        match.players[match.dealer].captured =
            match.players[match.dealer].captured.concat(match.table)
        match.table = []
    }

    var c0 = match.players[0].captured.length
    var c1 = match.players[1].captured.length
    var p0 = scorePile(match.players[0].captured) + match.roundTablas[0]
    var p1 = scorePile(match.players[1].captured) + match.roundTablas[1]
    if (c0 > c1)
        p0 += 3
    else if (c1 > c0)
        p1 += 3

    match.players[0].roundCards = c0
    match.players[1].roundCards = c1
    match.players[0].roundPoints = p0
    match.players[1].roundPoints = p1
    match.players[0].score += p0
    match.players[1].score += p1
    match.players[0].tablas = match.roundTablas[0]
    match.players[1].tablas = match.roundTablas[1]

    match.phase = "scoring"
    match.message = "Round: " + p0 + "–" + p1
        + "  ·  Total: " + match.players[0].score + "–" + match.players[1].score

    if (match.players[0].score >= TARGET || match.players[1].score >= TARGET) {
        match.phase = "over"
        if (match.players[0].score === match.players[1].score) {
            // Play another hand to break the tie
            match.phase = "scoring"
            match.message += "  ·  Tie at " + TARGET + "+ — deal again"
        } else {
            match.winner = match.players[0].score > match.players[1].score ? 0 : 1
            match.message = "Player " + (match.winner + 1) + " wins "
                + match.players[0].score + "–" + match.players[1].score
        }
    }
}

function nextAfterPlay(match) {
    if (!handsEmpty(match)) {
        match.turn = (match.turn + 1) % 2
        return
    }
    if (match.stock.length >= 2) {
        dealHand(match)
        match.turn = (match.dealer + 1) % 2
        match.message = "Fresh deal"
        return
    }
    endRound(match)
}

function playMove(match, seat, cardId, captureIds, aceAs) {
    if (match.phase !== "play")
        return { ok: false, error: "not playing" }
    if (seat !== match.turn)
        return { ok: false, error: "not your turn" }

    var hand = match.players[seat].hand
    var card = Cards.findById(hand, cardId)
    if (!card)
        return { ok: false, error: "card not in hand" }

    var ids = captureIds || []
    if (ids.length) {
        var as = card.rank === "A" ? (aceAs === 11 ? 11 : 1) : 1
        var opts = Capture.optionsFor(card, match.table, as)
        var ok = false
        var key = ids.slice().sort(function (a, b) { return a - b }).join(",")
        for (var i = 0; i < opts.length; i++) {
            var k = opts[i].captureIds.slice().sort(function (a, b) { return a - b }).join(",")
            if (k === key) {
                ok = true
                break
            }
        }
        if (!ok)
            return { ok: false, error: "illegal capture" }

        Cards.removeById(hand, cardId)
        var taken = [card]
        for (var t = 0; t < match.table.length; t++) {
            if (ids.indexOf(match.table[t].id) >= 0)
                taken.push(match.table[t])
        }
        Cards.removeMany(match.table, ids)
        match.players[seat].captured = match.players[seat].captured.concat(taken)
        match.lastCaptureSeat = seat

        if (match.table.length === 0) {
            match.roundTablas[seat]++
            match.message = "Tabla!"
        } else {
            match.message = "Captured " + ids.length
        }
    } else {
        Cards.removeById(hand, cardId)
        match.table.push(card)
        match.message = "On the table"
    }

    nextAfterPlay(match)
    return { ok: true }
}

function continueMatch(match) {
    if (match.phase !== "scoring")
        return
    match.dealer = (match.dealer + 1) % 2
    match.dealSeed = (match.dealSeed + 9973) >>> 0
    startRound(match)
}

function legalCaptures(match, seat, cardId, aceAs) {
    var card = Cards.findById(match.players[seat].hand, cardId)
    if (!card)
        return []
    var as = card.rank === "A" ? (aceAs === 11 ? 11 : 1) : 1
    return Capture.optionsFor(card, match.table, as)
}

function suggestCapture(match, seat, cardId) {
    var card = Cards.findById(match.players[seat].hand, cardId)
    if (!card)
        return { aceAs: 1, option: null }
    var aceAs = Capture.bestAceAs(card, match.table)
    return { aceAs: aceAs, option: Capture.bestOption(card, match.table, aceAs) }
}
