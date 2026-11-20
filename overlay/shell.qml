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
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

    // ---------- The game ----------
    // Click him once per visit to save him. Every save in a row brings him back
    // 10 % faster next time; let him explode and he's back to his normal pace.
    property int clicks: 0            // every click ever, shown on his shirt
    property int streak: 0            // saves in a row
    property int best: 0
    property bool saved: false        // clicked during this visit

    Process { id: makeStateDir; command: ["mkdir", "-p", root.stateHome + "/gus"]; running: true }
    FileView {
        id: statsFile
        path: root.stateHome + "/gus/stats.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.clicks = d.clicks || 0; root.streak = d.streak || 0; root.best = d.best || 0;
            } catch (e) {}
        }
    }
    function saveStats() {
        statsFile.setText(JSON.stringify({ clicks: clicks, streak: streak, best: best }) + "\n");
    }

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
        if (typeof s.fuse === "number") fuseTime = Math.max(2, s.fuse) * 1000;
        if (typeof s.explodes === "boolean") {
            const changed = s.explodes !== explodes;
            explodes = s.explodes;
            // Takes effect on the visit in progress too.
            if (changed && phase !== "away" && phase !== "tooting" && phase !== "exploding") {
                if (explodes) armFuse(); else disarmFuse();
            }
        }
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
    readonly property var fastLines: ["Next time I'm faster!", "Can't catch me!", "Zoom zoom!", "Turbo beans!", "Saved! Again!"]
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
    property string phase: "away"     // away | arriving | walking | tooting | leaving | exploding
    property real target: 0
    property real enteredAt: 0
    property string resumeTo: "walking"
    property int groundOffset: 0      // height of a bottom bar he walks on top of
    property var current: toots[0]
    // Every click makes him faster for the rest of the visit.
    property real hype: 1
    property int fuseTime: 5000               // unclicked this long, he explodes
    property bool explodes: true
    property int warnFor: 1700
    readonly property real ground: win.height - groundOffset
    // Up in the air: jumps, ropes and parachutes.
    property real lift: 0             // px above the ground
    property real swing: 0            // degrees he sways while hanging
    property string arrival: ""       // rope | parachute while arriving
    property real arrivalT: 0
    property real arrivalDur: 1
    property real startLift: 0
    property real baseX: 0
    property real ropeEnd: 0          // y where the rope ends; 0 when there's no rope
    property real chuteOpen: 0        // 1 while the parachute is up
    property real chuteCollapse: 0
    property real jumpT: -1           // seconds into a jump, -1 when on the ground
    property real jumpDur: 0.6
    property real jumpH: 100
    property real nextJumpAt: 0

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
        function summon(): void { if (root.phase === "away") { nextVisit.stop(); root.enter(""); } }
        // summonBy rope | parachute | walk
        function summonBy(how: string): void { if (root.phase === "away") { nextVisit.stop(); root.enter(how); } }
        function toot(): void { root.toot(); }
        function explode(): void { root.explode(); }
        // Where he is on screen, as "x,y,width,height" of his clickable box (for testing).
        function stats(): string { return root.clicks + "," + root.streak + "," + root.best + "," + root.hype.toFixed(2); }
        function where(): string { return Math.round(hit.x) + "," + Math.round(hit.y) + "," + Math.round(hit.width) + "," + Math.round(hit.height) + "," + root.phase; }
    }

    PanelWindow {
        id: win
        // The whole screen, so he can drop in from the top. Clicks still only land on Gus.
        anchors { top: true; bottom: true; left: true; right: true }
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

            // Shadow on the ground while he's in the air, smaller the higher he is.
            Shape {
                visible: root.lift > 2 && root.phase !== "away"
                width: 120; height: 120
                x: root.posX - 60; y: root.ground - 64
                opacity: Math.max(0, 0.9 - root.lift / 500)
                scale: Math.max(0.3, 1 - root.lift / 700)
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { origin.x: 60; origin.y: 60; yScale: 0.16 }
                ShapePath {
                    strokeWidth: -1; strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 60; centerY: 60; centerRadius: 60; focalX: 60; focalY: 60
                        GradientStop { position: 0; color: Qt.rgba(0.08, 0.02, 0.1, 0.4) }
                        GradientStop { position: 1; color: Qt.rgba(0.08, 0.02, 0.1, 0) }
                    }
                    PathSvg { path: "M0 60 A60 60 0 1 0 120 60 A60 60 0 1 0 0 60 Z" }
                }
            }

            // The rope he's lowered on.
            Item {
                visible: root.ropeEnd > 1
                x: hit.x + hit.width / 2 - 3; y: 0
                width: 6; height: Math.max(0, root.ropeEnd)
                Rectangle {
                    anchors.fill: parent; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#8a6a3e" }
                        GradientStop { position: 0.5; color: "#e3c48e" }
                        GradientStop { position: 1; color: "#8a6a3e" }
                    }
                    border.color: "#2b1838"; border.width: 1.5
                }
                Repeater {
                    model: Math.max(0, Math.floor(root.ropeEnd / 14))
                    Rectangle { required property int index; x: 1; y: index * 14 + 4; width: 4; height: 2; rotation: 35; color: "#6e522e" }
                }
            }

            // The parachute, striped and swaying.
            Item {
                id: chute
                visible: root.chuteOpen > 0
                width: 260; height: 270
                x: hit.x + hit.width / 2 - 130 + root.chuteCollapse * 70
                y: hit.y + 108 - 270 + root.chuteCollapse * 60
                opacity: 1 - root.chuteCollapse
                rotation: root.swing * 0.6 + root.chuteCollapse * 50
                transformOrigin: Item.Bottom
                Shape {
                    anchors.fill: parent
                    visible: root.chuteCollapse < 0.05
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#2b1838"; strokeWidth: 2; fillColor: "transparent"
                        PathSvg { path: "M4 118 L100 268 M66 120 L112 266 M194 120 L148 266 M256 118 L160 268" }
                    }
                }
                Shape {
                    width: 260; height: 124
                    preferredRendererType: Shape.CurveRenderer
                    transform: Scale { origin.x: 130; origin.y: 120; yScale: 1 - root.chuteCollapse * 0.75 }
                    ShapePath {
                        strokeColor: "#2b1838"; strokeWidth: 4; joinStyle: ShapePath.RoundJoin
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 260; y2: 0
                            GradientStop { position: 0.0; color: "#ff4d6d" }
                            GradientStop { position: 0.199; color: "#ff4d6d" }
                            GradientStop { position: 0.2; color: "#fff4e0" }
                            GradientStop { position: 0.399; color: "#fff4e0" }
                            GradientStop { position: 0.4; color: "#ffcf40" }
                            GradientStop { position: 0.599; color: "#ffcf40" }
                            GradientStop { position: 0.6; color: "#fff4e0" }
                            GradientStop { position: 0.799; color: "#fff4e0" }
                            GradientStop { position: 0.8; color: "#ff4d6d" }
                            GradientStop { position: 1.0; color: "#ff4d6d" }
                        }
                        PathSvg { path: "M2 120 C2 40 62 2 130 2 C198 2 258 40 258 120 Q226 104 194 120 Q162 104 130 120 Q98 104 66 120 Q34 104 2 120 Z" }
                    }
                    // Shading: light on top, darker underneath.
                    ShapePath {
                        strokeWidth: -1; strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: 120
                            GradientStop { position: 0; color: "#55ffffff" }
                            GradientStop { position: 0.6; color: "#00ffffff" }
                            GradientStop { position: 1; color: "#40000000" }
                        }
                        PathSvg { path: "M2 120 C2 40 62 2 130 2 C198 2 258 40 258 120 Q226 104 194 120 Q162 104 130 120 Q98 104 66 120 Q34 104 2 120 Z" }
                    }
                }
            }

            Item {
                id: hit
                width: 200 * root.sz; height: 300 * root.sz
                x: root.posX - width / 2
                y: root.ground - height - root.lift

                Gus {
                    id: gus
                    shadowOpacity: Math.max(0, 1 - root.lift / 12)
                    transform: [
                        Rotation { origin.x: 100; origin.y: 0; angle: root.swing },
                        Scale { origin.x: 100; origin.y: 300; xScale: 1 + gus.swell * 0.5; yScale: 1 + gus.swell * 0.28 },
                        Scale { xScale: root.sz; yScale: root.sz }
                    ]
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        colorization: gus.swell * 0.55
                        colorizationColor: "#7ed321"
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

        Timer { id: nextVisit; onTriggered: root.enter("") }
        // The fuse: restarted by every click; the last stretch is the warning.
        Timer { id: fuse; onTriggered: root.explode() }
        Timer { id: fuseWarn; onTriggered: root.startSwelling() }
        NumberAnimation { id: swellUp; target: gus; property: "swell"; to: 1; easing.type: Easing.InQuad }
        NumberAnimation { id: swellDown; target: gus; property: "swell"; to: 0; duration: 250; easing.type: Easing.OutBack }
        Timer { id: comeBack; interval: 2600; onTriggered: root.vanish() }
        NumberAnimation { id: buttUp; target: gus; property: "buttPuff"; to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 3 }
        NumberAnimation { id: hangDown; target: gus; property: "hang"; to: 0; duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { id: ropeUp; target: root; property: "ropeEnd"; to: 0; duration: 550; easing.type: Easing.InQuad }
        SequentialAnimation {
            id: chuteDown
            NumberAnimation { target: root; property: "chuteCollapse"; to: 1; duration: 750; easing.type: Easing.InQuad }
            ScriptAction { script: { root.chuteOpen = 0; root.chuteCollapse = 0; } }
        }
        Timer { id: moodReset; onTriggered: if (root.phase !== "tooting") gus.mood = "normal" }
        Timer { id: bubbleTimer; onTriggered: { bubble.opacity = 0; bubble.scale = 0.6; } }
        Timer {
            id: shaker
            interval: 35; repeat: true
            onTriggered: gus.jitter = (Math.random() * 2 - 1) * (root.phase !== "tooting" ? 1 + gus.swell * 4 : root.current.sbd ? 0.8 : 2.6)
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
            NumberAnimation { target: gus; property: "buttPuff"; to: 0; duration: 260; easing.type: Easing.InOutQuad }
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
                property int delay: 0
                width: s; height: s
                opacity: 0; scale: 0.15
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
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: gl.delay }
                    PropertyAction { target: gl; property: "opacity"; value: 0.75 }
                    ParallelAnimation {
                        NumberAnimation { target: gl; property: "scale"; to: 1.3; duration: gl.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: gl; property: "opacity"; to: 0; duration: gl.life; easing.type: Easing.InQuad }
                    }
                    ScriptAction { script: gl.destroy() }
                }
            }
        }

        // Shockwave ring
        Component {
            id: ringComp
            Rectangle {
                id: ring
                property real s: 40
                property real reach: 7
                property int life: 550
                property int delay: 0
                width: s; height: s; radius: s / 2
                color: "transparent"
                border.color: "#e2ff8a"; border.width: 5
                opacity: 0; scale: 0.3
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: ring.delay }
                    PropertyAction { target: ring; property: "opacity"; value: 0.9 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; to: ring.reach; duration: ring.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; to: 0; duration: ring.life; easing.type: Easing.InQuad }
                        NumberAnimation { target: ring; property: "border.width"; to: 1; duration: ring.life }
                    }
                    ScriptAction { script: ring.destroy() }
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
            id: speedComp
            Rectangle {
                id: sl
                property real dir: -1
                height: 3; radius: 1.5
                color: "#ffffff"
                opacity: 0.55
                ParallelAnimation {
                    running: true
                    NumberAnimation { target: sl; property: "x"; to: sl.x + sl.dir * 60; duration: 280; easing.type: Easing.OutQuad }
                    NumberAnimation { target: sl; property: "opacity"; to: 0; duration: 280 }
                    NumberAnimation { target: sl; property: "width"; to: sl.width * 0.4; duration: 280 }
                    onFinished: sl.destroy()
                }
            }
        }

        Component {
            id: wordComp
            Item {
                id: word
                property string text
                property int size: 60
                width: label.implicitWidth; height: label.implicitHeight
                scale: 0.2; opacity: 0
                Text {
                    x: 4; y: 5
                    text: word.text
                    font.pixelSize: word.size; font.weight: Font.Black
                    color: "#2b1838"
                }
                Text {
                    id: label
                    text: word.text
                    font.pixelSize: word.size; font.weight: Font.Black
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
            id: bigShake
            loops: 16
            NumberAnimation { target: world; property: "x"; to: 14; duration: 30 }
            NumberAnimation { target: world; property: "x"; to: -12; duration: 40 }
            NumberAnimation { target: world; property: "x"; to: 0; duration: 30 }
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

    // He turns up a different way each visit: strolling in from the side,
    // lowered on a rope, or floating down under a parachute, each at a random spot.
    function enter(how) {
        gus.view = "side"; gus.turn = 1; gus.pantsDown = 0; gus.bend = 0; gus.mood = "normal";
        gus.swell = 0; gus.opacity = 1; gus.hang = 0;
        saved = false;
        hype = Math.min(Math.pow(1.1, streak), 5);
        gus.badge = clicks;
        lift = 0; swing = 0; jumpT = -1;
        nextJumpAt = Date.now() + rnd(1500, 4000);
        const r = Math.random();
        const mode = how || (r < 0.34 ? "walk" : r < 0.67 ? "rope" : "parachute");
        if (mode === "walk") {
            posX = Math.random() < 0.5 ? -120 : win.width + 120;
            enteredAt = Date.now();
            armFuse();
            pickTarget();
            if (Math.random() < 0.6) Qt.callLater(() => say(pick(popLines)));
            return;
        }
        baseX = rnd(140, Math.max(141, win.width - 140));
        posX = baseX;
        gus.facing = Math.random() < 0.5 ? 1 : -1;
        gus.hang = 1;
        startLift = ground + 40;          // just above the top of the screen
        lift = startLift;
        arrival = mode;
        arrivalT = 0;
        arrivalDur = mode === "rope" ? rnd(1.4, 2.0) : rnd(3.5, 4.5);
        if (mode === "parachute") { chuteCollapse = 0; chuteOpen = 1; }
        phase = "arriving";
    }

    function stepArrival(dt) {
        arrivalT += dt;
        const u = Math.min(1, arrivalT / arrivalDur);
        if (arrival === "rope") {
            lift = startLift * (1 - (1 - Math.pow(1 - u, 2)));     // fast, then easing to the ground
            swing = 7 * Math.sin(arrivalT * 5) * (1 - u);
            ropeEnd = hit.y + 40 * sz;
        } else {
            lift = startLift * (1 - Math.sin(u * Math.PI / 2));     // drifts down, slowing at the end
            posX = baseX + 45 * Math.sin(arrivalT * 1.3) * (1 - u * 0.7);
            swing = 10 * Math.sin(arrivalT * 1.3 + 0.6) * (1 - u);
        }
        if (u >= 1) land();
    }

    function land() {
        lift = 0; swing = 0;
        hangDown.restart();
        if (arrival === "rope") ropeUp.restart();
        else chuteDown.restart();
        arrival = "";
        // A little puff of dust where he lands.
        for (let n = 0; n < 6; n++) {
            const s = rnd(16, 26);
            puffComp.createObject(fx, { s: s, c: "#c9c2b8", x: posX - s / 2 + rnd(-20, 20), y: ground - s / 2 - 4,
                                        dx: (n % 2 ? 1 : -1) * rnd(30, 70), dy: -rnd(5, 25), grow: 2, life: 700 });
        }
        if (Math.random() < 0.5) say(pick(["Ta-da!", "Nailed it.", "Hello down here!", "Special delivery!"]), 1600);
        enteredAt = Date.now();
        armFuse();
        pickTarget();
    }

    function footDust() {
        const s = rnd(10, 16);
        puffComp.createObject(fx, { s: s, c: "#d8d0c4", x: posX - gus.facing * 18 - s / 2, y: ground - s / 2 - 3,
                                    dx: -gus.facing * rnd(15, 35), dy: -rnd(4, 14), grow: 1.8, life: 500 });
    }

    function speedLine() {
        const len = rnd(40, 110);
        const y = hit.y + rnd(0.15, 0.85) * hit.height;
        const x = gus.facing > 0 ? hit.x - len - rnd(0, 20) : hit.x + hit.width + rnd(0, 20);
        speedComp.createObject(fx, { x: x, y: y, width: len, dir: -gus.facing });
    }

    function startJump() {
        jumpT = 0;
        jumpDur = rnd(0.55, 0.8);
        jumpH = rnd(70, 160);
        if (Math.random() < 0.3) say(pick(["Wheee!", "Hup!", "Boing!"]), 900);
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
            disarmFuse();
            phase = "away";
            posX = -400;
            bubble.opacity = 0;
            nextVisit.interval = rnd(minWait, maxWait);
            nextVisit.restart();
            return;
        }
        // He never stands still: he turns and heads somewhere else, sometimes
        // whistling or chatting on the way.
        if (Date.now() - enteredAt > stayTime) { leave(); return; }
        const r = Math.random();
        if (r < 0.2) { gus.mood = "whistle"; moodReset.interval = 1600; moodReset.restart(); }
        else if (r < 0.32) say(pick(popLines), 1800);
        pickTarget();
    }

    function step(dt) {
        gus.time += dt;
        const moving = phase === "walking" || phase === "leaving";
        const boost = hype;
        const v = speed * boost;
        gus.stride += ((moving ? 1 : 0) - gus.stride) * Math.min(1, dt * 8);
        if (phase === "arriving") { stepArrival(dt); return; }

        // Jumps: a parabola up and back down, arms thrown up.
        if (jumpT >= 0) {
            jumpT += dt;
            const u = Math.min(1, jumpT / jumpDur);
            lift = jumpH * 4 * u * (1 - u);
            gus.hang = 0.75 * Math.sin(Math.PI * u);
            if (u >= 1) { jumpT = -1; lift = 0; gus.hang = 0; }
        } else if (moving && Date.now() > nextJumpAt) {
            if (Math.random() < 0.55) startJump();
            nextJumpAt = Date.now() + rnd(2000, 5500);
        }
        if (!moving) return;
        // One full cycle (two steps) covers about 150 px at his size.
        const before = Math.sin(gus.walkPhase);
        gus.walkPhase += dt * v * 2 * Math.PI / 150;
        // A puff of dust each time a foot comes down.
        if (lift === 0 && (before < 0) !== (Math.sin(gus.walkPhase) < 0))
            footDust();
        // Speed lines once he's faster than his normal pace.
        if (hype > 1.15 && Math.random() < dt * 14 * Math.min(3, hype - 1) * 2)
            speedLine();
        const dx = target - posX, stepLen = v * dt;
        if (Math.abs(dx) <= stepLen) { posX = target; arrive(); }
        else posX += Math.sign(dx) * stepLen;
    }

    function toot() {
        if (phase === "away" || phase === "tooting" || phase === "exploding" || phase === "arriving") return;
        disarmFuse();
        clicks += 1;
        // The first click of a visit saves him; after his toot he heads off.
        if (!saved) {
            saved = true;
            streak += 1;
            best = Math.max(best, streak);
        }
        saveStats();
        gus.badge = clicks;
        resumeTo = "leaving";
        phase = "tooting";
        moodReset.stop();
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
        buttUp.restart();

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
        else if (streak >= 3 && Math.random() < 0.6) say(pick(fastLines), 1600);
        else say(pick(afterLines), 1600);
        moodReset.interval = current.sbd ? 2400 : 1200;
        moodReset.restart();
        if (resumeTo === "leaving") { leave(); return; }
        pickTarget();
    }

    // ---------- The fuse ----------
    function armFuse() {
        disarmFuse();
        if (!explodes) return;
        fuse.interval = fuseTime;
        fuse.start();
        // The warning takes the last 1.7 s, or the last third of a short fuse.
        warnFor = Math.min(1700, fuseTime / 3);
        fuseWarn.interval = fuseTime - warnFor;
        fuseWarn.start();
    }

    function disarmFuse() {
        fuse.stop(); fuseWarn.stop(); swellUp.stop();
        if (gus.swell > 0) swellDown.restart();
        if (phase !== "tooting") shaker.stop();
    }

    function startSwelling() {
        if (phase === "tooting" || phase === "away") return;
        say(pick(["Uh oh…", "Hnnngh!", "Something's coming…", "Click me, quick!"]), 1600);
        gus.mood = "toot";
        swellUp.duration = warnFor;
        swellUp.restart();
        shaker.start();
    }

    function explode() {
        if (phase === "away" || phase === "tooting" || phase === "exploding" || phase === "arriving") return;
        disarmFuse();
        swellUp.stop();
        phase = "exploding";
        bubble.opacity = 0;
        streak = 0;
        saveStats();
        shaker.stop();
        if (sound) {
            player.running = false;
            player.command = ["pw-play", "--volume=" + volume.toFixed(2),
                              Qt.resolvedUrl("sounds/explosion.wav").toString().replace("file://", "")];
            player.running = true;
        }
        gus.opacity = 0;

        const ox = hit.x + hit.width / 2, oy = hit.y + hit.height * 0.6;
        glowComp.createObject(fx, { s: 1300, x: ox - 650, y: oy - 650, life: 2200, c: "#c8f060" });
        glowComp.createObject(fx, { s: 700, x: ox - 350, y: oy - 350, life: 1200, c: "#ffffff" });
        for (let n = 0; n < 3; n++)
            ringComp.createObject(fx, { x: ox - 20, y: oy - 20, reach: 18 + n * 6, life: 900 + n * 200, delay: n * 140 });
        const colors = ["#b5dc4f", "#9cc93a", "#cfe86a", "#8fb82c", "#c4d860", "#a3c23a"];
        for (let n = 0; n < 70; n++) {
            const s = rnd(60, 130);
            const a = rnd(0, Math.PI * 2);
            const d = rnd(60, 620);
            puffComp.createObject(fx, {
                s: s, c: pick(colors), x: ox - s / 2, y: oy - s / 2,
                dx: Math.cos(a) * d, dy: Math.sin(a) * d * 0.55 - rnd(0, 120),
                grow: rnd(3, 6), life: rnd(2600, 4200), delay: n * 10
            });
        }
        for (let n = 0; n < 60; n++) {
            const a = rnd(0, Math.PI * 2), d = rnd(150, 700);
            speckComp.createObject(fx, { x: ox, y: oy, dx: Math.cos(a) * d, dy: Math.sin(a) * d * 0.6 - 60, life: rnd(700, 1400) });
        }
        for (let n = 0; n < 12; n++)
            stinkComp.createObject(fx, { x: ox + rnd(-450, 450), y: oy - rnd(0, 120), delay: 600 + n * 150 });
        const w = wordComp.createObject(fx, { text: pick(["KA-BLAAAM!", "MEGA TOOT!", "BRAAAOOOM!"]), size: 110, rotation: rnd(-8, 8) });
        w.x = Math.max(8, Math.min(win.width - w.width - 8, ox - w.width / 2));
        w.y = Math.max(8, oy - 300);
        bigShake.restart();
        comeBack.restart();
    }

    function vanish() {
        phase = "away";
        posX = -400;
        lift = 0; swing = 0; jumpT = -1; ropeEnd = 0; chuteOpen = 0; gus.hang = 0;
        gus.swell = 0; gus.jitter = 0; gus.mood = "normal"; gus.opacity = 1;
        nextVisit.interval = rnd(minWait, maxWait);
        nextVisit.restart();
    }

    Component.onCompleted: {
        monitors.running = true;
        nextVisit.interval = 1500;
        nextVisit.start();
    }
}
