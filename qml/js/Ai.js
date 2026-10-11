.pragma library
.import "Cards.js" as Cards
.import "Game.js" as Game

/*! Simple Tablić opponent: prefer tabla, then richest capture, else drop junk. */

function cardDanger(card) {
    // Prefer dropping low non-scoring cards when nothing captures.
    var pts = Game.cardPoints(card)
    if (pts > 0)
        return 10 + pts
    if (card.rank === "A")
        return 8
    var v = Cards.faceValue(card.rank)
    return v === null ? 5 : v
}

function scoreOption(tableLen, option, takenExtra) {
    if (!option)
        return -1
    var n = option.captureIds.length
    var tabla = n === tableLen ? 1000 : 0
    return tabla + n * 20 + (takenExtra || 0)
}

/*! Return { cardId, captureIds, aceAs } for seat, or null if no hand. */
function chooseMove(match, seat) {
    if (!match || match.phase !== "play" || match.turn !== seat)
        return null
    var hand = match.players[seat].hand
    if (!hand.length)
        return null

    var best = null
    var bestScore = -1

    for (var i = 0; i < hand.length; i++) {
        var card = hand[i]
        var sug = Game.suggestCapture(match, seat, card.id)
        if (sug.option) {
            var bonus = 0
            for (var c = 0; c < sug.option.captureIds.length; c++) {
                var tc = Cards.findById(match.table, sug.option.captureIds[c])
                if (tc)
                    bonus += Game.cardPoints(tc) * 3
            }
            bonus += Game.cardPoints(card) * 2
            var sc = scoreOption(match.table.length, sug.option, bonus)
            if (sc > bestScore) {
                bestScore = sc
                best = {
                    cardId: card.id,
                    captureIds: sug.option.captureIds.slice(),
                    aceAs: sug.aceAs
                }
            }
        }
    }

    if (best)
        return best

    // No capture — drop the least dangerous card
    var drop = hand[0]
    var danger = cardDanger(drop)
    for (var j = 1; j < hand.length; j++) {
        var d = cardDanger(hand[j])
        if (d < danger) {
            danger = d
            drop = hand[j]
        }
    }
    return { cardId: drop.id, captureIds: [], aceAs: 1 }
}
