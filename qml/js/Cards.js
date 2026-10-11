.pragma library

/*! Standard 52-card deck helpers for Tablić. */

var SUITS = ["c", "d", "h", "s"]
var RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
var SUIT_LABEL = { c: "♣", d: "♦", h: "♥", s: "♠" }
var SUIT_RED = { c: false, d: true, h: true, s: false }

function makeDeck() {
    var deck = []
    var id = 0
    for (var s = 0; s < SUITS.length; s++) {
        for (var r = 0; r < RANKS.length; r++) {
            deck.push({
                id: id++,
                suit: SUITS[s],
                rank: RANKS[r]
            })
        }
    }
    return deck
}

function cloneCard(c) {
    return { id: c.id, suit: c.suit, rank: c.rank }
}

function cloneCards(list) {
    var out = []
    for (var i = 0; i < list.length; i++)
        out.push(cloneCard(list[i]))
    return out
}

function faceValue(rank) {
    if (rank === "A")
        return null
    if (rank === "J")
        return 12
    if (rank === "Q")
        return 13
    if (rank === "K")
        return 14
    return parseInt(rank, 10)
}

/*! Possible numeric values for a card during capture. Ace is 1 or 11. */
function valuesOf(card) {
    if (card.rank === "A")
        return [1, 11]
    return [faceValue(card.rank)]
}

function label(card) {
    return card.rank + SUIT_LABEL[card.suit]
}

function isRed(card) {
    return !!SUIT_RED[card.suit]
}

function mulberry32(seed) {
    var a = seed >>> 0
    return function () {
        a = (a + 0x6D2B79F5) >>> 0
        var t = a
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

function shuffle(deck, seed) {
    var rng = mulberry32(seed === undefined ? Date.now() : seed)
    var a = cloneCards(deck)
    for (var i = a.length - 1; i > 0; i--) {
        var j = Math.floor(rng() * (i + 1))
        var tmp = a[i]
        a[i] = a[j]
        a[j] = tmp
    }
    return a
}

function findById(list, id) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return list[i]
    }
    return null
}

function removeById(list, id) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) {
            list.splice(i, 1)
            return true
        }
    }
    return false
}

function removeMany(list, ids) {
    var set = {}
    for (var i = 0; i < ids.length; i++)
        set[ids[i]] = true
    for (var j = list.length - 1; j >= 0; j--) {
        if (set[list[j].id])
            list.splice(j, 1)
    }
}
