.pragma library
.import "Cards.js" as Cards

/*!
  Find capture options for a played card against the table.
  Each option is { captureIds: number[], groups: number[][] }.
  Groups are disjoint subsets of table cards that each sum to the play value.
*/

function subsetSums(table, target) {
    var n = table.length
    var results = []

    function walk(start, remaining, chosen, aceModes) {
        if (remaining === 0) {
            results.push({ ids: chosen.slice(), aces: aceModes.slice() })
            return
        }
        if (remaining < 0 || start >= n)
            return
        for (var i = start; i < n; i++) {
            var card = table[i]
            var vals = Cards.valuesOf(card)
            for (var v = 0; v < vals.length; v++) {
                if (vals[v] > remaining)
                    continue
                chosen.push(card.id)
                aceModes.push(card.rank === "A" ? vals[v] : 0)
                walk(i + 1, remaining - vals[v], chosen, aceModes)
                chosen.pop()
                aceModes.pop()
            }
        }
    }

    walk(0, target, [], [])
    return results
}

function disjointCombos(subsets) {
    var out = []

    function overlaps(a, b) {
        var set = {}
        for (var i = 0; i < a.length; i++)
            set[a[i]] = true
        for (var j = 0; j < b.length; j++) {
            if (set[b[j]])
                return true
        }
        return false
    }

    function walk(start, usedIds, groups) {
        out.push({
            captureIds: usedIds.slice(),
            groups: groups.map(function (g) { return g.slice() })
        })
        for (var i = start; i < subsets.length; i++) {
            var ids = subsets[i].ids
            if (overlaps(usedIds, ids))
                continue
            for (var k = 0; k < ids.length; k++)
                usedIds.push(ids[k])
            groups.push(ids)
            walk(i + 1, usedIds, groups)
            groups.pop()
            usedIds.length -= ids.length
        }
    }

    walk(0, [], [])
    // drop the empty seed entry — caller may still choose to capture nothing
    return out.filter(function (o) { return o.captureIds.length > 0 })
}

function dedupeOptions(options) {
    var seen = {}
    var out = []
    for (var i = 0; i < options.length; i++) {
        var key = options[i].captureIds.slice().sort(function (a, b) { return a - b }).join(",")
        if (seen[key])
            continue
        seen[key] = true
        out.push(options[i])
    }
    return out
}

/*! All non-empty capture options for playing `card` (aceAs = 1 or 11 when rank is A). */
function optionsFor(card, table, aceAs) {
    var targets = []
    if (card.rank === "A") {
        targets = [aceAs === 11 ? 11 : 1]
    } else {
        targets = Cards.valuesOf(card)
    }
    var all = []
    for (var t = 0; t < targets.length; t++) {
        var subsets = subsetSums(table, targets[t])
        var combos = disjointCombos(subsets)
        for (var c = 0; c < combos.length; c++)
            all.push(combos[c])
    }
    return dedupeOptions(all)
}

/*! Prefer tabla (all table cards), then most cards captured. */
function bestOption(card, table, aceAs) {
    var opts = optionsFor(card, table, aceAs)
    if (!opts.length)
        return null
    opts.sort(function (a, b) {
        var aAll = a.captureIds.length === table.length ? 1 : 0
        var bAll = b.captureIds.length === table.length ? 1 : 0
        if (aAll !== bAll)
            return bAll - aAll
        return b.captureIds.length - a.captureIds.length
    })
    return opts[0]
}

function bestAceAs(card, table) {
    if (card.rank !== "A")
        return 1
    var a1 = bestOption(card, table, 1)
    var a11 = bestOption(card, table, 11)
    var n1 = a1 ? a1.captureIds.length : 0
    var n11 = a11 ? a11.captureIds.length : 0
    if (n11 > n1)
        return 11
    if (n1 > n11)
        return 1
    // prefer tabla
    if (a11 && a11.captureIds.length === table.length)
        return 11
    if (a1 && a1.captureIds.length === table.length)
        return 1
    return 11
}
