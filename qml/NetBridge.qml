import QtQuick 2.15
import "js/Net.js" as Net
import "js/Delivery.js" as Delivery

/*! Room host/join over Logos delivery_module. UI state only — IPC in Delivery.js. */
Item {
    id: root

    property string role: "none"   // none | local | host | guest
    property string roomCode: ""
    property string senderId: ""
    property string status: "idle"
    property string detail: ""
    property bool nodeReady: false
    property bool roomReady: false
    property bool peerPresent: false
    property int localSeat: 0
    property int matchSeed: 0
    property bool matchStarted: false
    property bool logosAvailable: false

    readonly property string topic: roomCode ? Net.topicForRoom(roomCode) : ""
    readonly property var logosApi: typeof logos !== "undefined" ? logos : null

    signal matchReady(int seed)
    signal remoteMove(var msg)
    signal netError(string message)

    function setStatus(s, d) {
        status = s
        detail = d || ""
    }

    function callDelivery(method, args, onOk, onFail) {
        Delivery.call(logosApi, method, args, onOk, function (err) {
            if (onFail)
                onFail(err)
            else
                root.netError(err)
        })
    }

    function ensureNode(done) {
        if (!Delivery.available(logosApi)) {
            setStatus("error", "Online play needs Logos Basecamp with delivery_module")
            if (done)
                done(false)
            return
        }
        Delivery.armEvents(logosApi)
        logosAvailable = true
        setStatus("connecting", "Starting Logos delivery node (logos.dev)…")
        Delivery.bringUp(logosApi, Net.nodeConfigJson(), function (ok, note) {
            if (!ok) {
                setStatus("error", note)
                root.netError(note)
                if (done)
                    done(false)
                return
            }
            nodeReady = true
            setStatus("online", note)
            if (done)
                done(true)
        })
    }

    function subscribeRoom(done) {
        callDelivery("subscribe", [topic], function () {
            roomReady = true
            setStatus("room", "Room " + roomCode + " — waiting for peer")
            if (done)
                done(true)
        }, function (e) {
            setStatus("error", "Subscribe failed: " + e)
            if (done)
                done(false)
        })
    }

    function send(obj) {
        if (!topic)
            return
        obj.sid = senderId
        obj.room = roomCode
        callDelivery("send", [topic, Net.encodeMessage(obj)], function () {}, function (e) {
            setStatus("warn", "Send failed: " + e)
        })
    }

    function startLocal() {
        role = "local"
        roomCode = ""
        roomReady = false
        peerPresent = false
        matchStarted = false
        localSeat = 0
        setStatus("local", "Hotseat — pass the device")
    }

    function hostGame() {
        role = "host"
        localSeat = 0
        senderId = "host-" + Math.floor(Math.random() * 1e6)
        roomCode = Net.makeRoomCode(Date.now() % 1e9)
        matchSeed = Math.floor(Math.random() * 1000)
        matchStarted = false
        peerPresent = false
        ensureNode(function (ok) {
            if (!ok)
                return
            subscribeRoom(function (ok2) {
                if (!ok2)
                    return
                send({ t: "hello", role: "host", seed: matchSeed })
                setStatus("room", "Share code " + roomCode + " — waiting for guest")
            })
        })
    }

    function joinGame(code) {
        role = "guest"
        localSeat = 1
        senderId = "guest-" + Math.floor(Math.random() * 1e6)
        roomCode = Net.normalizeCode(code)
        matchStarted = false
        peerPresent = false
        if (roomCode.length < 4) {
            setStatus("error", "Enter a valid room code")
            return
        }
        ensureNode(function (ok) {
            if (!ok)
                return
            subscribeRoom(function (ok2) {
                if (!ok2)
                    return
                send({ t: "hello", role: "guest" })
                setStatus("room", "Joined " + roomCode + " — waiting for host")
            })
        })
    }

    function broadcastMove(msg) {
        if (role !== "local" && msg)
            send(msg)
    }

    function startMatchAsHost() {
        send({ t: "start", seed: matchSeed })
        matchStarted = true
        matchReady(matchSeed)
    }

    function onHello(msg) {
        peerPresent = true
        if (role === "host" && msg.role === "guest") {
            setStatus("room", "Guest joined — starting match")
            startMatchAsHost()
        } else if (role === "guest" && msg.role === "host") {
            if (msg.seed !== undefined)
                matchSeed = msg.seed
            setStatus("room", "Host found — waiting for start")
            send({ t: "hello", role: "guest" })
        }
    }

    function handleIncoming(rawTopic, rawPayload) {
        if (topic && rawTopic && String(rawTopic) !== topic)
            return
        var msg = Net.decodeMessage(rawPayload)
        if (!msg || !msg.t || Net.isOwnEcho(msg, senderId))
            return
        if (msg.t === "hello")
            onHello(msg)
        else if (msg.t === "start") {
            if (msg.seed !== undefined)
                matchSeed = msg.seed
            matchStarted = true
            setStatus("play", "Online match live")
            matchReady(matchSeed)
        } else if (msg.t === "move" || msg.t === "next") {
            remoteMove(msg)
        }
    }

    Connections {
        target: root.logosApi
        ignoreUnknownSignals: true
        function onModuleEventReceived(moduleName, eventName, data) {
            if (moduleName !== "delivery_module")
                return
            var ev = Delivery.eventPayload(data)
            if (eventName === "connectionStateChanged" && ev.linkState)
                root.setStatus(root.roomReady ? "room" : "online", "Link: " + ev.linkState)
            else if (eventName === "messageReceived")
                root.handleIncoming(ev.topic, ev.payload)
            else if (eventName === "messageError")
                root.setStatus("warn", ev.errorText || "message error")
            else if (eventName === "nodeStarted")
                root.nodeReady = true
        }
    }

    Component.onCompleted: {
        logosAvailable = Delivery.available(logosApi)
        if (logosAvailable)
            Delivery.armEvents(logosApi)
    }
}
