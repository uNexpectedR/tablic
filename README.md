# Tablić

Serbian fishing card game for **Logos Basecamp** (`ui_qml` module). Capture cards from the table, score to **101**. Local hotseat or **online host/join** via Logos `delivery_module`.

## Stack

| File | Role |
| --- | --- |
| `metadata.json` | Module identity (`type: ui_qml`, `view: qml/Main.qml`) |
| `flake.nix` | Nix build via `mkLogosQmlModule` |
| `qml/Main.qml` | Lobby + table root |
| `qml/NetBridge.qml` | Online host/join over `logos.callModule` / `onModuleEvent` |
| `qml/js/Game.js` | Deal, play, scoring |
| `qml/js/Capture.js` | Legal capture combinations |

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

1. Select a card in your hand (suggested capture is pre-selected).
2. Optionally click table cards to adjust the take, **Next take** to cycle options, or **Ace as 1/11**.
3. **Take** to capture, or **Drop** to leave your card on the table.

| Mode | Notes |
| --- | --- |
| Local hotseat | Same device; hand flips with the turn |
| Host / Join | Two Basecamp apps; room code over `delivery_module` |

## Install in Logos Basecamp

### Local package (ready now)

```bash
git clone https://github.com/uNexpectedR/tablic.git
cd tablic
nix build .#lgx
```

Package Manager → **Install Local Package** → select the `.lgx` (allow unsigned). For online play, load **delivery_module**.

### Catalog (after publishing a release)

```text
https://raw.githubusercontent.com/uNexpectedR/tablic/main/logos-repo.json
```

Add that URL under Package Repositories, then install **Tablić**. The rolling `index` release must include `tablic` (run the module release Action, then rebuild index).

`trustedSigners` is empty (unsigned packages). Catalog URL uses this repository’s `logos-repo.json`.
