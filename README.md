# Tablić

Serbian fishing card game for **Logos Basecamp** (`ui_qml` module). Capture cards from the table, score to **101**. Play against **PC** or **online host/join** via Logos `delivery_module`.

## Stack

| File | Role |
| --- | --- |
| `metadata.json` | Module identity (`type: ui_qml`, `view: qml/Main.qml`) |
| `flake.nix` | Nix build via `mkLogosQmlModule` |
| `qml/Main.qml` | Lobby + table root |
| `qml/TablicNet.qml` | Online host/join over `logos.callModule` / `onModuleEvent` |
| `qml/js/Game.js` | Deal, play, scoring |
| `qml/js/Capture.js` | Legal capture combinations |
| `qml/js/Ai.js` | PC opponent moves |
| `qml/js/Theme.js` | Felt / ivory / brass visual system |
| `qml/TablicCard.qml` | Premium card face & back |

## Rules (2 players)

- 52-card deck. Values: K=14, Q=13, J=12, pip face value, Ace = 1 or 11.
- Deal 4 face-up to the table, then 6 each (two rounds of three). Fresh 6 each when hands empty (four deals total).
- Play one card: capture a table card or disjoint sets that each sum to your card’s value — or drop it on the table.
- Clearing the table is a **tabla** (+1). Leftover table at the end of the deck goes to the last capturer (no tabla).
- Scoring per deal: each A/K/Q/J = 1; tens = 1 (10♦ = 2); 2♣ = 1; most cards = 3 (tie → none); each tabla = 1.
- First to **101** (or more) after a completed deal wins. Tie at 101+ → another deal.

## Run locally

```bash
nix run
# or without Nix:
./tools/run-preview.sh
```

```bash
node tests/game.test.mjs
```

## Play

1. **Take:** tap table cards to mark a capture set, then tap a hand card that matches — cards fly into your capture stack.
2. **Drop:** tap a hand card first, then **Drop** (or tap the table to switch into take mode instead). Ace: **Ace as 1/11** before dropping.
3. **Stacks:** tap **your** pile (bottom-left) anytime to inspect. The PC/opponent pile shows count only (face-down — contents stay hidden). Captures still fly into the correct pile.
4. Table layout is a **2-column grid** (reads as 2×2 with four cards). Opponent/PC **drops** animate onto the table.
5. **Scoreboard** (top): live match points toward 101, plus **Tablas** this deal for each seat (**1 tabla = 1 point** at scoring).

| Mode | Notes |
| --- | --- |
| Play against PC | You are seat 0; PC plays the other |
| Host / Join | Two Basecamp apps; room code over `delivery_module` |

## Install in Logos Basecamp

Paste repository URL:

```text
https://raw.githubusercontent.com/uNexpectedR/tablic/main/logos-repo.json
```

1. **Settings → Package Repositories → Add repository** (or refresh if already added).
2. Package Manager → **Tablić** `0.6.2` → Install (allow unsigned if prompted).
3. Open Tablić from the sidebar.
4. For online play: load **delivery_module** (Module Inspector) if Host/Join errors.

`trustedSigners` is empty (unsigned packages).

