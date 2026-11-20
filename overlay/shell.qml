// Gus walks along the bottom of your screen. Click him and he turns round,
// drops his trousers and farts at you.
// The gus app starts and stops this overlay and writes the settings it reads.
// Run by hand: qs -p <this folder>      Quit: qs kill -p <this folder>
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Defaults, replaced by ~/.config/gus/settings.json whenever the app saves it.
    property int minWait: 6000        // ms between visits
    property int maxWait: 20000
    property int stayTime: 25000      // ms he wanders about before leaving
    property real speed: 90           // walking speed, px per second
    property bool sound: true
    property real volume: 0.8
    property var enabledToots: ["tuba", "squeaker", "machinegun", "wetflap", "question", "opera", "sbd"]

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    FileView {
        path: root.configHome + "/gus/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applySettings(text())
    }

    function applySettings(json) {
        let s;
        try { s = JSON.parse(json); } catch (e) { return; }
        if (typeof s.minWait === "number") minWait = s.minWait * 1000;
        if (typeof s.maxWait === "number") maxWait = Math.max(minWait, s.maxWait * 1000);
        if (typeof s.stay === "number") stayTime = Math.max(5, s.stay) * 1000;
        if (typeof s.speed === "number") speed = Math.max(20, s.speed);
        if (typeof s.sound === "boolean") sound = s.sound;
        if (typeof s.volume === "number") volume = Math.max(0, Math.min(1, s.volume / 100));
        if (Array.isArray(s.toots)) enabledToots = s.toots;
        // A shorter wait applies to the visit already scheduled, not only the next one.
        if (phase === "away" && nextVisit.running && nextVisit.interval > maxWait) {
            nextVisit.interval = rnd(minWait, maxWait);
            nextVisit.restart();
        }
    }

    readonly property var popLines: [
        "Just passing through.", "Don't mind me.", "I had the chili.", "Lovely desktop.",
        "Who, me?", "Working hard?", "Three bean salad. Three.", "Hey neighbour!",
        "Nice tabs.", "Is it warm in here?"
    ]
    readonly property var afterLines: ["Excuse me!", "Pardon!", "Better out than in.", "You're welcome.", "That one had a name.", "Ahh. Relief.", "Right in the face."]
    readonly property var words: ["PFFFRRT!", "BRAAAP!", "TOOT!", "PFFT!", "BLORP!", "FRRAPP!", "THBBBT!"]
    readonly property var toots: [
        { id: "tuba", puffs: 16, size: 1.3, len: 1500, big: true },
        { id: "squeaker", puffs: 8, size: 0.7, len: 800 },
        { id: "machinegun", puffs: 16, size: 0.9, len: 1100, big: true },
        { id: "wetflap", puffs: 12, size: 1.0, len: 800 },
        { id: "question", puffs: 10, size: 0.9, len: 1100 },
        { id: "opera", puffs: 18, size: 1.2, len: 2000, big: true },
        { id: "sbd", puffs: 24, size: 1.8, len: 1800, sbd: true }
    ]
    property string lastToot: ""

    function pick(list) { return list[Math.floor(Math.random() * list.length)]; }
    function rnd(a, b) { return a + Math.random() * (b - a); }

    // ---------- State ----------
    readonly property real sz: 0.72
    property real posX: -400          // window x of his feet
    property string phase: "away"     // away | walking | idle | tooting | leaving
    property real target: 0
    property real enteredAt: 0
    property real boostUntil: 0
    property string resumeTo: "walking"
    property int groundOffset: 0      // height of a bottom bar he walks on top of
    property var current: toots[0]
    readonly property real ground: win.height - groundOffset

    Process { id: player }

    // Walk on top of a bottom bar instead of behind it.
    Process {
        id: monitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: root.readMonitors(text) }
    }
    function readMonitors(json) {
        try {
            const list = JSON.parse(json);
            const name = win.screen ? win.screen.name : "";
            const m = list.find(x => x.name === name) || list.find(x => x.focused) || list[0];
            if (m && Array.isArray(m.reserved)) groundOffset = m.reserved[3] || 0;
        } catch (e) {}
    }

    // From a terminal: qs ipc -p <this folder> call gus summon   (or: toot)
    IpcHandler {
        target: "gus"
        function summon(): void { if (root.phase === "away") { nextVisit.stop(); root.enter(); } }
        function toot(): void { root.toot(); }
        // Where he is on screen, as "x,y,width,height" of his clickable box (for testing).
        function where(): string { return Math.round(hit.x) + "," + Math.round(hit.y) + "," + Math.round(hit.width) + "," + Math.round(hit.height) + "," + root.phase; }
    }

    PanelWindow {
        id: win
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 620
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gus"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Only Gus himself catches clicks; everything else passes through to your apps.
        mask: Region { item: hit }

        Item {
            id: world
            width: win.width; height: win.height

            Item {
                id: hit
                width: 200 * root.sz; height: 300 * root.sz
                x: root.posX - width / 2
                y: root.ground - height

                Gus {
                    id: gus
                    transform: Scale { xScale: root.sz; yScale: root.sz }
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#80000000"
                        shadowBlur: 0.5
                        shadowVerticalOffset: 4
                        shadowHorizontalOffset: 2
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toot()
                }
            }

            Item { id: fx; anchors.fill: parent }

            // Speech bubble that follows him around.
            Rectangle {
                id: bubble
                property alias text: bubbleText.text
                width: Math.min(240, bubbleText.implicitWidth + 28)
                height: bubbleText.implicitHeight + 20
                x: Math.max(8, Math.min(win.width - width - 8, hit.x + hit.width / 2 - width / 2))
                y: hit.y - height - 10
                radius: 16
                color: "#fffaf0"
                border.color: "#2b1838"; border.width: 3
                opacity: 0; scale: 0.6
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Text {
                    id: bubbleText
                    anchors.centerIn: parent
                    width: Math.min(212, implicitWidth)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 16; font.weight: Font.Black
                    color: "#2b1838"
                }
                Rectangle {
                    width: 14; height: 14; rotation: 45
                    color: "#fffaf0"
                    x: Math.max(10, Math.min(parent.width - 24, hit.x + hit.width / 2 - parent.x - 7))
                    anchors.top: parent.bottom; anchors.topMargin: -8
                    border.color: "#2b1838"; border.width: 3
                    z: -1
                }
            }
        }

        // ---------- Movement ----------
        FrameAnimation {
            running: root.phase !== "away"
            onTriggered: root.step(Math.min(frameTime, 0.05))
        }

        Timer { id: nextVisit; onTriggered: root.enter() }
        Timer { id: idleTimer; onTriggered: root.idleOver() }
        Timer { id: moodReset; onTriggered: if (root.phase !== "tooting") gus.mood = "normal" }
        Timer { id: lookBack; interval: 700; onTriggered: if (root.phase === "idle") gus.facing = -gus.facing }
        Timer { id: bubbleTimer; onTriggered: { bubble.opacity = 0; bubble.scale = 0.6; } }
        Timer {
            id: shaker
            interval: 35; repeat: true
            onTriggered: gus.jitter = (Math.random() * 2 - 1) * (root.current.sbd ? 0.8 : 2.6)
            onRunningChanged: if (!running) gus.jitter = 0
        }

        // ---------- The main event ----------
        SequentialAnimation {
            id: tootSeq
            property int holdFor: 1000
            ScriptAction { script: { gus.mood = "surprised"; bubble.opacity = 0; } }
            PauseAnimation { duration: 150 }
            // Turn round to face away from you.
            NumberAnimation { target: gus; property: "turn"; to: 0.05; duration: 110; easing.type: Easing.InQuad }
            ScriptAction { script: gus.view = "back" }
            NumberAnimation { target: gus; property: "turn"; to: 1; duration: 150; easing.type: Easing.OutBack }
            PauseAnimation { duration: 120 }
            // Trousers down, bend over.
            ParallelAnimation {
                NumberAnimation { target: gus; property: "pantsDown"; to: 1; duration: 320; easing.type: Easing.OutBounce }
                NumberAnimation { target: gus; property: "bend"; to: 1; duration: 300; easing.type: Easing.OutQuad }
            }
            PauseAnimation { duration: 220 }
            ScriptAction { script: root.blast(root.current) }
            PauseAnimation { duration: tootSeq.holdFor }
            ScriptAction { script: shaker.stop() }
            PauseAnimation { duration: 250 }
            // Trousers up, turn back round.
            ParallelAnimation {
                NumberAnimation { target: gus; property: "pantsDown"; to: 0; duration: 260; easing.type: Easing.OutBack }
                NumberAnimation { target: gus; property: "bend"; to: 0; duration: 260 }
            }
            NumberAnimation { target: gus; property: "turn"; to: 0.05; duration: 110; easing.type: Easing.InQuad }
            ScriptAction { script: { gus.view = "side"; gus.mood = root.current.sbd ? "sbd" : "relief"; } }
            NumberAnimation { target: gus; property: "turn"; to: 1; duration: 150; easing.type: Easing.OutBack }
            ScriptAction { script: root.afterToot() }
        }

        // ---------- Effects ----------
        Component {
            id: puffComp
            Shape {
                id: p
                property real s: 50
                property color c: "#b5dc4f"
                property real dx: 0
                property real dy: 0
                property real grow: 3
                property int life: 2000
                property int delay: 0
                width: s; height: s
                opacity: 0; scale: 0.2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: p.s / 2; centerY: p.s / 2; centerRadius: p.s / 2
                        focalX: p.s * 0.4; focalY: p.s * 0.36
                        GradientStop { position: 0; color: Qt.lighter(p.c, 1.3) }
                        GradientStop { position: 0.55; color: p.c }
                        GradientStop { position: 1; color: Qt.rgba(p.c.r, p.c.g, p.c.b, 0) }
                    }
                    PathSvg { path: "M0 " + p.s / 2 + " A" + p.s / 2 + " " + p.s / 2 + " 0 1 0 " + p.s + " " + p.s / 2 + " A" + p.s / 2 + " " + p.s / 2 + " 0 1 0 0 " + p.s / 2 + " Z" }
                }
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: p.delay }
                    ParallelAnimation {
                        NumberAnimation { target: p; property: "x"; to: p.x + p.dx; duration: p.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: p; property: "y"; to: p.y + p.dy; duration: p.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: p; property: "scale"; to: p.grow; duration: p.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: p; property: "rotation"; to: Math.random() * 120 - 60; duration: p.life }
                        SequentialAnimation {
                            NumberAnimation { target: p; property: "opacity"; to: 0.85; duration: p.life * 0.15 }
                            NumberAnimation { target: p; property: "opacity"; to: 0; duration: p.life * 0.85; easing.type: Easing.InQuad }
                        }
                    }
                    ScriptAction { script: p.destroy() }
                }
            }
        }

        // A green flash that blooms out of him toward the screen.
        Component {
            id: glowComp
            Shape {
                id: gl
                property real s: 400
                property int life: 900
                property color c: "#c8f060"
                width: s; height: s
                opacity: 0.7; scale: 0.15
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: gl.s / 2; centerY: gl.s / 2; centerRadius: gl.s / 2; focalX: gl.s / 2; focalY: gl.s / 2
                        GradientStop { position: 0; color: Qt.rgba(gl.c.r, gl.c.g, gl.c.b, 0.75) }
                        GradientStop { position: 0.45; color: Qt.rgba(gl.c.r, gl.c.g, gl.c.b, 0.3) }
                        GradientStop { position: 1; color: Qt.rgba(gl.c.r, gl.c.g, gl.c.b, 0) }
                    }
                    PathSvg { path: "M0 " + gl.s / 2 + " A" + gl.s / 2 + " " + gl.s / 2 + " 0 1 0 " + gl.s + " " + gl.s / 2 + " A" + gl.s / 2 + " " + gl.s / 2 + " 0 1 0 0 " + gl.s / 2 + " Z" }
                }
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: gl; property: "scale"; to: 1.3; duration: gl.life; easing.type: Easing.OutCubic }
                    NumberAnimation { target: gl; property: "opacity"; to: 0; duration: gl.life; easing.type: Easing.InQuad }
                    onFinished: gl.destroy()
                }
            }
        }

        // Shockwave ring
        Component {
            id: ringComp
            Rectangle {
                id: ring
                property real s: 40
                width: s; height: s; radius: s / 2
                color: "transparent"
                border.color: "#e2ff8a"; border.width: 5
                opacity: 0.9; scale: 0.3
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: ring; property: "scale"; to: 7; duration: 550; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 550; easing.type: Easing.InQuad }
                    NumberAnimation { target: ring; property: "border.width"; to: 1; duration: 550 }
                    onFinished: ring.destroy()
                }
            }
        }

        // Flying specks
        Component {
            id: speckComp
            Rectangle {
                id: sp
                property real dx: 0
                property real dy: 0
                property int life: 700
                width: 7; height: 7; radius: 3.5
                color: "#9cc93a"
                border.color: "#5d7e1c"; border.width: 1
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: sp; property: "x"; to: sp.x + sp.dx; duration: sp.life; easing.type: Easing.OutQuad }
                    NumberAnimation { target: sp; property: "y"; to: sp.y + sp.dy; duration: sp.life; easing.type: Easing.OutQuad }
                    NumberAnimation { target: sp; property: "scale"; to: 2.2; duration: sp.life }
                    NumberAnimation { target: sp; property: "opacity"; to: 0; duration: sp.life; easing.type: Easing.InCubic }
                    onFinished: sp.destroy()
                }
            }
        }

        // Wavy stink lines that rise and fade.
        Component {
            id: stinkComp
            Shape {
                id: st
                property int life: 2200
                property int delay: 0
                width: 20; height: 60
                opacity: 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "#8fb82c"; strokeWidth: 4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathSvg { path: "M10 60 C20 50 0 40 10 30 C20 20 0 10 10 0" }
                }
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: st.delay }
                    ParallelAnimation {
                        NumberAnimation { target: st; property: "y"; to: st.y - 90; duration: st.life; easing.type: Easing.OutSine }
                        SequentialAnimation {
                            NumberAnimation { target: st; property: "opacity"; to: 0.9; duration: st.life * 0.25 }
                            NumberAnimation { target: st; property: "opacity"; to: 0; duration: st.life * 0.75 }
                        }
                        SequentialAnimation {
                            loops: 3
                            NumberAnimation { target: st; property: "rotation"; to: 8; duration: st.life / 6 }
                            NumberAnimation { target: st; property: "rotation"; to: -8; duration: st.life / 6 }
                        }
                    }
                    ScriptAction { script: st.destroy() }
                }
            }
        }

        Component {
            id: wordComp
            Item {
                id: word
                property string text
                width: label.implicitWidth; height: label.implicitHeight
                scale: 0.2; opacity: 0
                Text {
                    x: 4; y: 5
                    text: word.text
                    font.pixelSize: 60; font.weight: Font.Black
                    color: "#2b1838"
                }
                Text {
                    id: label
                    text: word.text
                    font.pixelSize: 60; font.weight: Font.Black
                    color: "#ff5d8f"
                    style: Text.Outline; styleColor: "#2b1838"
                }
                SequentialAnimation {
                    running: true
                    ParallelAnimation {
                        NumberAnimation { target: word; property: "scale"; to: 1.25; duration: 180; easing.type: Easing.OutBack }
                        NumberAnimation { target: word; property: "opacity"; to: 1; duration: 120 }
                    }
                    NumberAnimation { target: word; property: "scale"; to: 1; duration: 140 }
                    PauseAnimation { duration: 700 }
                    ParallelAnimation {
                        NumberAnimation { target: word; property: "y"; to: word.y - 50; duration: 450 }
                        NumberAnimation { target: word; property: "opacity"; to: 0; duration: 450 }
                    }
                    ScriptAction { script: word.destroy() }
                }
            }
        }

        SequentialAnimation {
            id: worldShake
            loops: 6
            NumberAnimation { target: world; property: "x"; to: 7; duration: 30 }
            NumberAnimation { target: world; property: "x"; to: -6; duration: 40 }
            NumberAnimation { target: world; property: "x"; to: 0; duration: 30 }
        }
    }

    // ---------- Behaviour ----------
    function say(text, ms) {
        bubble.text = text;
        bubble.opacity = 1; bubble.scale = 1;
        bubbleTimer.interval = ms || 2200;
        bubbleTimer.restart();
    }

    function setFacingTo(x) { gus.facing = x >= posX ? 1 : -1; }

    function enter() {
        const fromLeft = Math.random() < 0.5;
        posX = fromLeft ? -120 : win.width + 120;
        gus.view = "side"; gus.turn = 1; gus.pantsDown = 0; gus.bend = 0; gus.mood = "normal";
        enteredAt = Date.now();
        pickTarget();
        if (Math.random() < 0.6) Qt.callLater(() => say(pick(popLines)));
    }

    function pickTarget() {
        const margin = 90, W = win.width;
        let t = posX;
        for (let i = 0; i < 8 && Math.abs(t - posX) < 180; i++) t = rnd(margin, Math.max(margin + 1, W - margin));
        target = t;
        setFacingTo(t);
        phase = "walking";
    }

    function leave() {
        target = posX < win.width / 2 ? -160 : win.width + 160;
        setFacingTo(target);
        phase = "leaving";
    }

    function arrive() {
        if (phase === "leaving") {
            phase = "away";
            posX = -400;
            bubble.opacity = 0;
            nextVisit.interval = rnd(minWait, maxWait);
            nextVisit.restart();
            return;
        }
        phase = "idle";
        const r = Math.random();
        if (r < 0.3) lookBack.restart();                                   // glance over his shoulder…
        else if (r < 0.5) { gus.mood = "whistle"; moodReset.interval = 1600; moodReset.restart(); }
        else if (r < 0.65) say(pick(popLines), 1800);
        idleTimer.interval = rnd(1200, 3200);
        idleTimer.restart();
    }

    function idleOver() {
        if (phase !== "idle") return;
        if (Date.now() - enteredAt > stayTime) leave();
        else pickTarget();
    }

    function step(dt) {
        gus.time += dt;
        const moving = phase === "walking" || phase === "leaving";
        const boost = Date.now() < boostUntil ? 1.9 : 1;
        const v = speed * boost;
        gus.stride += ((moving ? 1 : 0) - gus.stride) * Math.min(1, dt * 8);
        if (!moving) return;
        // One full cycle (two steps) covers about 150 px at his size.
        gus.walkPhase += dt * v * 2 * Math.PI / 150;
        const dx = target - posX, stepLen = v * dt;
        if (Math.abs(dx) <= stepLen) { posX = target; arrive(); }
        else posX += Math.sign(dx) * stepLen;
    }

    function toot() {
        if (phase === "away" || phase === "tooting") return;
        resumeTo = phase === "leaving" ? "leaving" : "walking";
        phase = "tooting";
        idleTimer.stop(); moodReset.stop(); lookBack.stop();
        // Only the toots ticked in the app; all of them if none are.
        let pool = toots.filter(x => enabledToots.indexOf(x.id) >= 0);
        if (pool.length === 0) pool = toots;
        let i = Math.floor(Math.random() * pool.length);
        if (pool.length > 1 && pool[i].id === lastToot) i = (i + 1) % pool.length;
        current = pool[i];
        lastToot = current.id;
        tootSeq.holdFor = current.len;
        tootSeq.restart();
    }

    function blast(t) {
        if (sound) {
            player.running = false;
            player.command = ["pw-play", "--volume=" + volume.toFixed(2),
                              Qt.resolvedUrl("sounds/" + t.id + ".wav").toString().replace("file://", "")];
            player.running = true;
        }
        gus.mood = "toot";
        shaker.start();

        // Straight out of his backside, toward you.
        const ox = hit.x + 100 * sz, oy = hit.y + 238 * sz;
        const gs = (t.sbd ? 520 : 360) * t.size;
        glowComp.createObject(fx, { s: gs, x: ox - gs / 2, y: oy - gs / 2, life: t.sbd ? 2200 : 900,
                                    c: t.sbd ? "#a8d040" : "#d4f070" });
        const colors = ["#b5dc4f", "#9cc93a", "#cfe86a", "#8fb82c", "#c4d860"];
        for (let n = 0; n < t.puffs; n++) {
            const s = rnd(28, 56) * t.size;
            const a = rnd(Math.PI * 0.95, Math.PI * 2.05);      // mostly sideways and up
            const d = rnd(30, 150) * t.size;
            puffComp.createObject(fx, {
                s: s, c: pick(colors), x: ox - s / 2 + rnd(-8, 8), y: oy - s / 2 + rnd(-6, 6),
                dx: Math.cos(a) * d, dy: Math.sin(a) * d * 0.8 - rnd(10, 50),
                grow: rnd(2.4, 4.4), life: rnd(1500, 2600) * (t.sbd ? 1.5 : 1),
                delay: n * (t.sbd ? 70 : t.id === "machinegun" ? 60 : 28)
            });
        }
        if (!t.sbd) {
            ringComp.createObject(fx, { x: ox - 20, y: oy - 20 });
            for (let n = 0; n < 18; n++) {
                const a = rnd(0, Math.PI * 2), d = rnd(60, 200);
                speckComp.createObject(fx, { x: ox, y: oy, dx: Math.cos(a) * d, dy: Math.sin(a) * d * 0.7 - 30, life: rnd(500, 900) });
            }
            const w = wordComp.createObject(fx, { text: pick(words), rotation: rnd(-12, 12) });
            w.x = Math.max(8, Math.min(win.width - w.width - 8, ox + (Math.random() < 0.5 ? -w.width - 50 : 50)));
            w.y = oy - 190;
            if (t.big) worldShake.restart();
        }
        const lines = t.sbd ? 6 : 2;
        for (let n = 0; n < lines; n++)
            stinkComp.createObject(fx, { x: ox + rnd(-70, 70), y: oy - rnd(20, 70), delay: n * 260 + (t.sbd ? 300 : 500) });
    }

    function afterToot() {
        if (current.sbd) say("Wasn't me.", 2400);
        else say(pick(afterLines), 1600);
        moodReset.interval = current.sbd ? 2400 : 1200;
        moodReset.restart();
        if (resumeTo === "leaving") { leave(); return; }
        if (!current.sbd) boostUntil = Date.now() + 1400;   // hurries off, a little embarrassed
        pickTarget();
    }

    Component.onCompleted: {
        monitors.running = true;
        nextVisit.interval = 1500;
        nextVisit.start();
    }
}
