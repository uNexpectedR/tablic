.pragma library

/*! Thin wrappers around logos.callModuleAsync → delivery_module. */

var MODULE = "delivery_module"
var EVENTS = ["messageReceived", "connectionStateChanged", "messageError", "nodeStarted"]

function available(logosApi) {
    return logosApi !== undefined && logosApi !== null
}

function parseResult(payload) {
    var result = null
    try {
        result = typeof payload === "string" ? JSON.parse(payload) : payload
    } catch (e) {
        return { ok: true, value: { raw: payload } }
    }
    if (result && typeof result === "object") {
        if (result.success === false)
            return { ok: false, error: result.error || result.message || "call failed" }
        if (result.error && result.success !== true && result.success !== undefined)
            return { ok: false, error: String(result.error) }
    }
    return { ok: true, value: result }
}

function isTruthyRunning(info) {
    if (info === true || info === "true")
        return true
    if (!info || typeof info !== "object")
        return false
    if (info.value !== undefined)
        return info.value === true || String(info.value) === "true"
    if (info.result !== undefined)
        return info.result === true || String(info.result) === "true"
    return false
}

function call(logosApi, method, args, onOk, onFail) {
    if (!available(logosApi)) {
        if (onFail)
            onFail("Logos bridge unavailable (run inside Basecamp)")
        return
    }
    logosApi.callModuleAsync(MODULE, method, args || [], function (payload) {
        var parsed = parseResult(payload)
        if (parsed.ok) {
            if (onOk)
                onOk(parsed.value)
        } else if (onFail) {
            onFail(parsed.error)
        }
    }, function (err) {
        if (onFail)
            onFail(err ? String(err) : "delivery_module call failed")
    })
}

function armEvents(logosApi) {
    if (!available(logosApi))
        return false
    for (var i = 0; i < EVENTS.length; i++)
        logosApi.onModuleEvent(MODULE, EVENTS[i])
    return true
}

/*! Create+start logos.dev node, or adopt one already running. */
function bringUp(logosApi, configJson, onDone) {
    function finish(ok, note) {
        if (onDone)
            onDone(ok, note || "")
    }

    call(logosApi, "getNodeInfo", ["IsRunning"], function (info) {
        if (isTruthyRunning(info)) {
            finish(true, "Delivery node already running")
            return
        }
        createThenStart(logosApi, configJson, finish)
    }, function () {
        createThenStart(logosApi, configJson, finish)
    })
}

function createThenStart(logosApi, configJson, finish) {
    call(logosApi, "createNode", [configJson], function () {
        call(logosApi, "start", [], function () {
            finish(true, "Connected to logos.dev")
        }, function () {
            // start is often async; nodeStarted event covers the rest
            finish(true, "Node starting…")
        })
    }, function (err) {
        if (String(err).toLowerCase().indexOf("already") >= 0) {
            call(logosApi, "start", [], function () {
                finish(true, "Joined existing delivery node")
            }, function () {
                finish(true, "Using existing delivery node")
            })
        } else {
            finish(false, err)
        }
    })
}

function eventPayload(data) {
    // messageReceived: [hash, topic, payload, source, ts]
    return {
        topic: data && data.length > 1 ? data[1] : "",
        payload: data && data.length > 2 ? data[2] : "",
        errorText: data && data.length > 2 ? String(data[2]) : "",
        linkState: data && data.length ? String(data[0]) : ""
    }
}
