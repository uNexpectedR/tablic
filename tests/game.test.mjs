import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import vm from "node:vm"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

function loadFile(rel, sandbox) {
  const code = fs
    .readFileSync(path.join(root, rel), "utf8")
    .replace(/^\.pragma library\s*/m, "")
    .replace(/^\.import .*$/gm, "")
  vm.runInNewContext(code, sandbox, { filename: rel })
}

function loadBundle() {
  const sandbox = { Math, console, Array, JSON, String, Date, parseInt }
  loadFile("qml/js/Cards.js", sandbox)
  sandbox.Cards = {
    makeDeck: sandbox.makeDeck,
    cloneCard: sandbox.cloneCard,
    cloneCards: sandbox.cloneCards,
    faceValue: sandbox.faceValue,
    valuesOf: sandbox.valuesOf,
    label: sandbox.label,
    isRed: sandbox.isRed,
    shuffle: sandbox.shuffle,
    findById: sandbox.findById,
    removeById: sandbox.removeById,
    removeMany: sandbox.removeMany,
    SUITS: sandbox.SUITS,
    RANKS: sandbox.RANKS,
  }
  loadFile("qml/js/Capture.js", sandbox)
  sandbox.Capture = {
    subsetSums: sandbox.subsetSums,
    optionsFor: sandbox.optionsFor,
    bestOption: sandbox.bestOption,
    bestAceAs: sandbox.bestAceAs,
  }
  loadFile("qml/js/Game.js", sandbox)
  sandbox.Game = {
    newMatch: sandbox.newMatch,
    playMove: sandbox.playMove,
    suggestCapture: sandbox.suggestCapture,
    cardPoints: sandbox.cardPoints,
    legalCaptures: sandbox.legalCaptures,
  }
  loadFile("qml/js/Ai.js", sandbox)
  return sandbox
}

const G = loadBundle()

// Deck size
{
  const deck = G.makeDeck()
  assert.equal(deck.length, 52)
}

// Capture: 9 takes 2+7 or 2+3+4, not both at once
{
  const table = [
    { id: 1, suit: "c", rank: "2" },
    { id: 2, suit: "d", rank: "3" },
    { id: 3, suit: "h", rank: "4" },
    { id: 4, suit: "s", rank: "7" },
  ]
  const nine = { id: 9, suit: "c", rank: "9" }
  const opts = G.optionsFor(nine, table, 1)
  const keys = opts.map((o) => o.captureIds.slice().sort((a, b) => a - b).join(",")).sort()
  assert.ok(keys.includes("1,2,3"))
  assert.ok(keys.includes("1,4"))
  assert.ok(!keys.includes("1,2,3,4"))
}

// Capture: multiple disjoint sets (A+8)+(3+6) with 9
{
  const table = [
    { id: 1, suit: "c", rank: "A" },
    { id: 2, suit: "d", rank: "3" },
    { id: 3, suit: "h", rank: "6" },
    { id: 4, suit: "s", rank: "7" },
    { id: 5, suit: "c", rank: "8" },
    { id: 6, suit: "d", rank: "Q" },
  ]
  const nine = { id: 9, suit: "h", rank: "9" }
  const opts = G.optionsFor(nine, table, 1)
  const has = opts.some((o) => {
    const s = o.captureIds.slice().sort((a, b) => a - b).join(",")
    return s === "1,2,3,5"
  })
  assert.ok(has, "should allow (A+8)+(3+6)")
}

// Scoring constants: 10♦=2, 2♣=1, face=1
{
  assert.equal(G.cardPoints({ suit: "d", rank: "10" }), 2)
  assert.equal(G.cardPoints({ suit: "c", rank: "10" }), 1)
  assert.equal(G.cardPoints({ suit: "c", rank: "2" }), 1)
  assert.equal(G.cardPoints({ suit: "h", rank: "2" }), 0)
  assert.equal(G.cardPoints({ suit: "s", rank: "A" }), 1)
}

// Full match seed is deterministic and deals 4+6+6
{
  const m = G.newMatch(42)
  assert.equal(m.table.length, 4)
  assert.equal(m.players[0].hand.length, 6)
  assert.equal(m.players[1].hand.length, 6)
  assert.equal(m.stock.length, 52 - 4 - 12)
  assert.equal(m.turn, 1) // non-dealer leads
}

// Drop then capture
{
  const m = G.newMatch(7)
  const seat = m.turn
  const card = m.players[seat].hand[0]
  const r = G.playMove(m, seat, card.id, [], 1)
  assert.ok(r.ok)
  assert.ok(m.table.some((c) => c.id === card.id))
}

// Tabla awards a point tally
{
  const m = G.createMatch(1)
  m.phase = "play"
  m.turn = 0
  m.dealer = 1
  m.stock = []
  m.table = [{ id: 10, suit: "c", rank: "5" }]
  m.players[0].hand = [{ id: 11, suit: "d", rank: "5" }]
  m.players[1].hand = []
  const r = G.playMove(m, 0, 11, [10], 1)
  assert.ok(r.ok)
  assert.equal(m.roundTablas[0], 1)
  assert.equal(m.table.length, 0)
}

// Leftover table goes to last capturer, not a tabla
{
  const m = G.createMatch(2)
  m.phase = "play"
  m.turn = 0
  m.dealer = 0
  m.stock = []
  m.table = [
    { id: 1, suit: "c", rank: "3" },
    { id: 2, suit: "d", rank: "4" },
  ]
  m.players[0].hand = [{ id: 3, suit: "h", rank: "2" }]
  m.players[1].hand = []
  m.lastCaptureSeat = 1
  m.roundTablas = [0, 0]
  G.playMove(m, 0, 3, [], 1) // drop, ends round
  assert.equal(m.phase, "scoring")
  assert.ok(m.players[1].captured.some((c) => c.id === 1))
  assert.equal(m.roundTablas[1], 0)
}

// One-deck mode: first completed deck ends the match
{
  const m = G.createMatch(4, "one")
  assert.equal(m.mode, "one")
  m.phase = "play"
  m.turn = 0
  m.dealer = 0
  m.stock = []
  m.table = []
  m.players[0].hand = [{ id: 3, suit: "h", rank: "2" }]
  m.players[1].hand = []
  m.players[0].captured = [{ id: 20, suit: "d", rank: "10" }] // 2 pts
  m.players[1].captured = [{ id: 21, suit: "c", rank: "A" }] // 1 pt
  m.lastCaptureSeat = 0
  m.roundTablas = [0, 0]
  G.playMove(m, 0, 3, [], 1)
  assert.equal(m.phase, "over")
  assert.equal(m.winner, 0)
}


// AI chooses a legal move
{
  const m = G.newMatch(99)
  const seat = m.turn
  const mv = G.chooseMove(m, seat)
  assert.ok(mv && mv.cardId !== undefined)
  const r = G.playMove(m, seat, mv.cardId, mv.captureIds || [], mv.aceAs || 1)
  assert.ok(r.ok, r.error)
}

console.log("game.test.mjs: ok")
