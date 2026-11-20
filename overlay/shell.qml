// Gus: pops up from the bottom edge of your screen. Click him and he toots.
// The gus app starts and stops this overlay and writes the settings it reads.
// Run by hand: qs -p <this folder>      Quit: qs kill -p <this folder>
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Defaults, replaced by ~/.config/gus/settings.json whenever the app saves it.
    // How long Gus waits below the screen edge between visits (ms).
    property int minWait: 6000
    property int maxWait: 20000
    // How long he hangs around if you ignore him (ms).
    property int stayTime: 6000
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
        if (typeof s.stay === "number") stayTime = s.stay * 1000;
        if (typeof s.sound === "boolean") sound = s.sound;
        if (typeof s.volume === "number") volume = Math.max(0, Math.min(1, s.volume / 100));
        if (Array.isArray(s.toots)) enabledToots = s.toots;
        // A shorter wait applies to the visit already scheduled, not only the next one.
        if (gus.state === "down" && nextVisit.running && nextVisit.interval > maxWait) {
            nextVisit.interval = rnd(minWait, maxWait);
            nextVisit.restart();
        }
    }

    readonly property var popLines: [
        "Psst. Down here.", "Don't click me.", "I had the chili.", "Pull my... no, just click.",
        "Who, me?", "Working hard?", "Three bean salad. Three.", "Hey neighbor!",
        "Nice tabs.", "Smells fine down here."
    ]
    readonly property var afterLines: ["Excuse me!", "Pardon!", "Better out than in.", "Oops.", "That one had a name.", "Ahh. Relief."]
    readonly property var words: ["PFFFRRT!", "BRAAAP!", "TOOT!", "PFFT!", "BLORP!", "FRRAPP!"]
    readonly property var toots: [
        { id: "tuba", puffs: 10, size: 1.2, len: 1300 },
        { id: "squeaker", puffs: 5, size: 0.7, len: 700 },
        { id: "machinegun", puffs: 12, size: 0.8, len: 950 },
        { id: "wetflap", puffs: 8, size: 1.0, len: 600 },
        { id: "question", puffs: 7, size: 0.9, len: 950 },
        { id: "opera", puffs: 11, size: 1.1, len: 1900 },
        { id: "sbd", puffs: 18, size: 1.7, len: 1600, sbd: true }
    ]
    property string lastToot: ""

    function pick(list) { return list[Math.floor(Math.random() * list.length)]; }
    function rnd(a, b) { return a + Math.random() * (b - a); }

    Process { id: player }

    // From a terminal: qs ipc -p <this folder> call gus summon   (or: toot)
    IpcHandler {
        target: "gus"
        function summon(): void { if (gus.state === "down") { nextVisit.stop(); root.popUp(); } }
        function toot(): void { root.toot(); }
    }

    PanelWindow {
        id: win
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 560
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "gus"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Only Gus himself catches clicks; everything else passes through to your apps.
        mask: Region { item: gus }

        Item {
            id: gus
            width: 220; height: 300
            x: 200
            y: win.height + 20
            state: "down"   // down | up | tooting
            property string face: "gus.svg"

            Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

            Image {
                id: art
                anchors.fill: parent
                source: Qt.resolvedUrl(gus.face)
                sourceSize: Qt.size(220, 300)
                smooth: true
                transformOrigin: Item.Bottom
            }

            SequentialAnimation {
                id: wiggle
                loops: 4
                NumberAnimation { target: art; property: "rotation"; to: -5; duration: 80 }
                NumberAnimation { target: art; property: "rotation"; to: 5; duration: 160 }
                NumberAnimation { target: art; property: "rotation"; to: 0; duration: 80 }
            }
            SequentialAnimation {
                id: sway
                loops: 2
                NumberAnimation { target: art; property: "rotation"; to: -2; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { target: art; property: "rotation"; to: 2; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { target: art; property: "rotation"; to: 0; duration: 300 }
            }

            // Speech bubble
            Rectangle {
                id: bubble
                property alias text: bubbleText.text
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 10
                width: Math.min(240, bubbleText.implicitWidth + 28)
                height: bubbleText.implicitHeight + 20
                radius: 16
                color: "#fffaf0"
                border.color: "#2b1838"; border.width: 3
                opacity: 0; scale: 0.6
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom; anchors.topMargin: -8
                    border.color: "#2b1838"; border.width: 3
                    z: -1
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toot()
            }
        }

        Timer { id: nextVisit; onTriggered: root.popUp() }
        Timer { id: idle; onTriggered: root.duck() }
        Timer { id: bubbleTimer; onTriggered: { bubble.opacity = 0; bubble.scale = 0.6; } }
        Timer { id: afterTimer; property string line; onTriggered: root.say(line, 1400) }
        Timer { id: endToot; property bool sbd; onTriggered: { gus.face = "gus.svg"; duckLater.start(); } }
        Timer { id: duckLater; interval: 700; onTriggered: root.duck() }

        Component {
            id: puffComp
            Rectangle {
                id: puff
                property real dx: 0
                property real dy: 0
                property real grow: 2
                property int life: 2000
                property int delay: 0
                radius: width / 2
                color: "#b5dc4f"
                border.color: "#7fae2c"; border.width: 3
                opacity: 0; scale: 0.3
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: puff.delay }
                    ParallelAnimation {
                        NumberAnimation { target: puff; property: "x"; to: puff.x + puff.dx; duration: puff.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: puff; property: "y"; to: puff.y + puff.dy; duration: puff.life; easing.type: Easing.OutCubic }
                        NumberAnimation { target: puff; property: "scale"; to: puff.grow; duration: puff.life; easing.type: Easing.OutCubic }
                        SequentialAnimation {
                            NumberAnimation { target: puff; property: "opacity"; to: 0.85; duration: puff.life * 0.2 }
                            NumberAnimation { target: puff; property: "opacity"; to: 0; duration: puff.life * 0.8 }
                        }
                    }
                    ScriptAction { script: puff.destroy() }
                }
            }
        }

        Component {
            id: wordComp
            Text {
                id: word
                font.pixelSize: 52; font.weight: Font.Black; font.family: "sans-serif"
                color: "#ff5d8f"
                style: Text.Outline; styleColor: "#2b1838"
                scale: 0.2; opacity: 0
                SequentialAnimation {
                    running: true
                    ParallelAnimation {
                        NumberAnimation { target: word; property: "scale"; to: 1.15; duration: 180; easing.type: Easing.OutBack }
                        NumberAnimation { target: word; property: "opacity"; to: 1; duration: 120 }
                    }
                    NumberAnimation { target: word; property: "scale"; to: 1; duration: 120 }
                    PauseAnimation { duration: 600 }
                    ParallelAnimation {
                        NumberAnimation { target: word; property: "y"; to: word.y - 40; duration: 400 }
                        NumberAnimation { target: word; property: "opacity"; to: 0; duration: 400 }
                    }
                    ScriptAction { script: word.destroy() }
                }
            }
        }
    }

    function say(text, ms) {
        bubble.text = text;
        bubble.opacity = 1; bubble.scale = 1;
        bubbleTimer.interval = ms || 2200;
        bubbleTimer.restart();
    }

    function popUp() {
        gus.face = "gus.svg";
        art.rotation = 0;
        gus.x = rnd(40, Math.max(41, win.width - gus.width - 40));
        gus.y = win.height - 238;   // his hands grip the bottom edge of the screen
        gus.state = "up";
        if (Math.random() < 0.7) say(pick(popLines));
        idle.interval = stayTime;
        idle.restart();
    }

    function duck() {
        idle.stop();
        gus.state = "down";
        gus.y = win.height + 20;
        bubble.opacity = 0; bubble.scale = 0.6;
        nextVisit.interval = rnd(minWait, maxWait);
        nextVisit.restart();
    }

    function toot() {
        if (gus.state !== "up") return;
        gus.state = "tooting";
        idle.stop();
        // Only the toots ticked in the app; all of them if none are.
        let pool = toots.filter(x => enabledToots.indexOf(x.id) >= 0);
        if (pool.length === 0) pool = toots;
        let i = Math.floor(Math.random() * pool.length);
        if (pool.length > 1 && pool[i].id === lastToot) i = (i + 1) % pool.length;
        const t = pool[i];
        lastToot = t.id;

        if (sound) {
            player.running = false;
            player.command = ["pw-play", "--volume=" + volume.toFixed(2),
                              Qt.resolvedUrl("sounds/" + t.id + ".wav").toString().replace("file://", "")];
            player.running = true;
        }

        gus.face = t.sbd ? "gus-sbd.svg" : "gus-toot.svg";
        if (t.sbd) { sway.restart(); say("Wasn't me.", 2400); }
        else { wiggle.restart(); afterTimer.line = pick(afterLines); afterTimer.interval = 700; afterTimer.restart(); }

        const side = Math.random() < 0.5 ? -1 : 1;
        const ox = gus.x + (side < 0 ? gus.width * 0.15 : gus.width * 0.85);
        const oy = win.height - 20;
        for (let n = 0; n < t.puffs; n++) {
            const s = rnd(40, 80) * t.size;
            puffComp.createObject(win.contentItem, {
                width: s, height: s, x: ox - s / 2, y: oy - s / 2,
                dx: side * rnd(20, 160) * t.size, dy: -rnd(40, 220) * t.size,
                grow: rnd(1.6, 2.6), life: rnd(1600, 2600) * (t.sbd ? 1.4 : 1),
                delay: n * (t.sbd ? 90 : 45)
            });
        }
        if (!t.sbd) {
            const w = wordComp.createObject(win.contentItem, { text: pick(words), rotation: side * rnd(6, 14) });
            let wx = ox + side * 40 - (side < 0 ? w.implicitWidth : 0);
            w.x = Math.max(8, Math.min(win.width - w.implicitWidth - 8, wx));
            w.y = win.height - 200;
        }

        endToot.interval = Math.max(1200, t.len + 300);
        endToot.restart();
    }

    Component.onCompleted: { nextVisit.interval = 1500; nextVisit.start(); }
}
