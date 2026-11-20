// Gus, drawn as a rig of shaded vector parts so every limb can move.
// He is drawn facing right in a 200 × 300 box with his feet at the bottom
// centre; `facing: -1` mirrors him. shell.qml drives the walk and the moods.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: g
    width: 200
    height: 300

    // Driven from outside.
    property real walkPhase: 0      // radians; one full turn is two steps
    property real stride: 0         // 0 standing still … 1 full walk
    property real facing: 1
    property real lean: 0           // degrees forward, for bending over
    property real jitter: 0         // small shake while tooting
    property real time: 0           // seconds, for breathing
    property string mood: "normal"  // normal | toot | sbd | relief | whistle | surprised
    property string view: "side"    // side (walking) | back (mooning you)
    property real turn: 1           // horizontal squeeze while he turns round
    property real pantsDown: 0      // 0 belted … 1 round his ankles
    property real bend: 0           // 0 upright … 1 bent over
    property real swell: 0          // 0 normal … 1 about to burst
    property real hang: 0           // 0 arms down … 1 arms up, legs dangling (rope, parachute, jumps)
    property real shadowOpacity: 1  // his own ground shadow, hidden while he's in the air
    property int badge: 0           // how many times he's been clicked, on his shirt
    property real buttPuff: 0       // 0 normal … 1 swollen mid-toot

    // Colours
    readonly property color ink: "#2b1838"
    readonly property color skin: "#ffc797"
    readonly property color skinLight: "#ffe6cc"
    readonly property color skinShade: "#e09566"
    readonly property color shirt: "#ff6f91"
    readonly property color shirtLight: "#ffb0c4"
    readonly property color shirtShade: "#c63c66"

    // Walk cycle. Legs swing like pendulums; the hips drop as they spread so
    // the feet stay planted on the ground.
    readonly property real legSwing: stride * 30 * Math.sin(walkPhase) * (1 - hang) + hang * 14 * Math.sin(time * 5)
    readonly property real armSwing: stride * 32 * Math.sin(walkPhase) * (1 - hang)
    // Arms thrown up (and flailing a little) while hanging or jumping.
    readonly property real armUp: hang * (-150 + 14 * Math.sin(time * 7))
    readonly property real hipDrop: 78 * (1 - Math.cos(legSwing * Math.PI / 180))
    readonly property real breath: (1 - stride) * Math.sin(time * 2.4)
    readonly property real squash: 1 + stride * 0.04 * Math.cos(2 * walkPhase) + breath * 0.014
    readonly property real headLag: stride * 3 * Math.sin(2 * walkPhase + 0.7)
    readonly property real hairWiggle: stride * 10 * Math.sin(2 * walkPhase + 1.4) + jitter * 4

    property real eyesOpen: 1
    readonly property bool squinting: mood === "toot"
    readonly property bool eyesClosed: mood === "relief"
    readonly property real pupilX: mood === "sbd" || mood === "whistle" ? -2 : mood === "surprised" ? 0 : 3
    readonly property real pupilY: mood === "sbd" || mood === "whistle" ? -5 : 0
    readonly property real browLift: mood === "surprised" ? -8 : mood === "sbd" || mood === "whistle" ? -4 : 0
    readonly property real blush: mood === "toot" ? 0.95 : mood === "relief" ? 0.6 : 0.35

    // Blinks every few seconds, like a person.
    Timer {
        interval: 2600 + Math.random() * 2400
        running: true; repeat: true
        onTriggered: { interval = 2000 + Math.random() * 3500; if (!g.squinting && !g.eyesClosed) blink.restart(); }
    }
    SequentialAnimation {
        id: blink
        NumberAnimation { target: g; property: "eyesOpen"; to: 0.08; duration: 70 }
        NumberAnimation { target: g; property: "eyesOpen"; to: 1; duration: 110 }
    }

    // Soft ground shadow; it shrinks a little as he rises mid-step.
    Shape {
        id: shadow
        opacity: g.shadowOpacity
        x: 40; y: 240
        width: 120; height: 120
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.x: 60; origin.y: 60; yScale: 0.16; xScale: 0.95 + g.hipDrop / 60 }
        ShapePath {
            strokeWidth: -1; strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 60; centerY: 60; centerRadius: 60; focalX: 60; focalY: 60
                GradientStop { position: 0; color: Qt.rgba(0.08, 0.02, 0.1, 0.45) }
                GradientStop { position: 1; color: Qt.rgba(0.08, 0.02, 0.1, 0) }
            }
            PathSvg { path: "M0 60 A60 60 0 1 0 120 60 A60 60 0 1 0 0 60 Z" }
        }
    }

    // Seen from behind, for the main event: trousers down, aimed at you.
    Item {
        id: backRig
        visible: g.view === "back"
        width: 200; height: 300
        transform: [
            Rotation { origin.x: 100; origin.y: 300; angle: g.jitter },
            Scale { origin.x: 100; xScale: g.turn }
        ]
        readonly property real waist: 214 + g.pantsDown * 60

        // Bare legs
        Rectangle {
            x: 74; y: 224; width: 24; height: 64; radius: 10
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: g.skinShade } GradientStop { position: 0.6; color: g.skin } GradientStop { position: 1; color: g.skinShade } }
            border.color: g.ink; border.width: 3.5
        }
        Rectangle {
            x: 102; y: 224; width: 24; height: 64; radius: 10
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: g.skinShade } GradientStop { position: 0.4; color: g.skin } GradientStop { position: 1; color: g.skinShade } }
            border.color: g.ink; border.width: 3.5
        }
        // Heels
        Rectangle { x: 70; y: 280; width: 32; height: 18; radius: 9; color: "#3a281e"; border.color: g.ink; border.width: 3.5 }
        Rectangle { x: 98; y: 280; width: 32; height: 18; radius: 9; color: "#3a281e"; border.color: g.ink; border.width: 3.5 }

        // The cheeks, which wobble as he lets rip. Once the trousers are down
        // they're drawn over the shirt tail: he's bent over, pointing them at you.
        Item {
            width: 200; height: 300
            z: 2
            transform: Scale {
                origin.x: 100; origin.y: 250
                xScale: 1 + g.buttPuff * 0.5 + Math.abs(g.jitter) * 0.025
                yScale: 1 + g.buttPuff * 0.32 - Math.abs(g.jitter) * 0.02
            }
            Repeater {
                model: [58, 98]
                Rectangle {
                    required property int modelData
                    x: modelData - 2; y: 208; width: 50; height: 60; radius: 25
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffe0cc" }
                        GradientStop { position: 0.55; color: "#ffc0a0" }
                        GradientStop { position: 1; color: "#e8906c" }
                    }
                    border.color: g.ink; border.width: 4
                    Rectangle {
                        x: modelData < 90 ? parent.width - 16 : 2; y: 6; width: 14; height: parent.height - 14; radius: 7
                        color: "#c9654a"; opacity: 0.35
                    }
                    Rectangle { x: modelData < 90 ? 9 : 22; y: 14; width: 16; height: 10; radius: 5; color: "white"; opacity: 0.7; rotation: -25 }
                    Rectangle { x: modelData < 90 ? 8 : 30; y: 28; width: 5; height: 5; radius: 2.5; color: "white"; opacity: 0.6 }
                    Rectangle { x: modelData < 90 ? 22 : 8; y: 40; width: 14; height: 8; radius: 4; color: "#ff6f7f"; opacity: 0.45 }
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: g.ink; strokeWidth: 3.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathSvg { path: "M100 220 Q102 244 100 262" }
                }
            }
        }

        // Trousers: one piece while belted, then bunched round the ankles.
        Rectangle {
            visible: height > 6
            z: 2.5
            x: 56; y: backRig.waist; width: 88; height: Math.max(0, 258 - backRig.waist); radius: 10
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#1d4466" } GradientStop { position: 0.5; color: "#3b80bd" } GradientStop { position: 1; color: "#1d4466" } }
            border.color: g.ink; border.width: 3.5
        }
        Repeater {
            model: [70, 101]
            Rectangle {
                required property int modelData
                z: 2.5
                visible: g.pantsDown < 0.85
                readonly property real cuff: Math.min(Math.max(backRig.waist, 250), 266)
                x: modelData; y: cuff; width: 30; height: 290 - cuff; radius: 9
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#24527a" } GradientStop { position: 1; color: "#3b80bd" } }
                border.color: g.ink; border.width: 3.5
                // Folds once they're down
                Rectangle { visible: g.pantsDown > 0.6; x: 4; y: 7; width: 22; height: 3; radius: 1.5; color: "#183a5a" }
            }
        }
        Rectangle {
            z: 2.6
            visible: g.pantsDown < 0.85
            x: 54; y: Math.min(backRig.waist - 4, 262); width: 92; height: 11; radius: 5
            color: "#3d2618"; border.color: g.ink; border.width: 3
        }
        // Round his ankles
        Item {
            z: 2.6
            visible: g.pantsDown >= 0.85
            x: 58; y: 260; width: 84; height: 30
            Rectangle {
                anchors.fill: parent; radius: 13
                gradient: Gradient {
                    GradientStop { position: 0; color: "#3b80bd" }
                    GradientStop { position: 1; color: "#1d4466" }
                }
                border.color: g.ink; border.width: 3.5
            }
            Repeater {
                model: [[10, 9, 22], [36, 6, 18], [58, 11, 16], [20, 18, 26]]
                Rectangle {
                    required property var modelData
                    x: modelData[0]; y: modelData[1]; width: modelData[2]; height: 3; radius: 1.5
                    color: "#163552"
                }
            }
            Rectangle { x: -2; y: -3; width: 88; height: 9; radius: 4.5; color: "#3d2618"; border.color: g.ink; border.width: 2.5 }
            Rectangle { x: 50; y: -5; width: 12; height: 12; radius: 3; color: "transparent"; border.color: "#ffcf40"; border.width: 3 }
        }

        // Upper body, bending over as the trousers come down.
        Item {
            width: 200; height: 300
            z: g.pantsDown < 0.4 ? 3 : 1
            y: g.bend * 8
            transform: Scale { origin.x: 100; origin.y: 120; yScale: 1 - g.bend * 0.1 }

            // Arms hang at his sides.
            Rectangle {
                x: 36; y: 150; width: 16; height: 56; radius: 8; rotation: 10
                color: g.skin; border.color: g.ink; border.width: 3
                Rectangle { x: -4; y: 46; width: 22; height: 22; radius: 11; color: g.skin; border.color: g.ink; border.width: 3.5 }
            }
            Rectangle {
                x: 148; y: 150; width: 16; height: 56; radius: 8; rotation: -10
                color: g.skin; border.color: g.ink; border.width: 3
                Rectangle { x: -2; y: 46; width: 22; height: 22; radius: 11; color: g.skin; border.color: g.ink; border.width: 3.5 }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: g.ink; strokeWidth: 4; joinStyle: ShapePath.RoundJoin
                    fillGradient: RadialGradient {
                        centerX: 100; centerY: 170; centerRadius: 100; focalX: 92; focalY: 150
                        GradientStop { position: 0; color: g.shirtLight }
                        GradientStop { position: 0.5; color: g.shirt }
                        GradientStop { position: 1; color: g.shirtShade }
                    }
                    // Shorter than from the side: the shirt has ridden up.
                    PathSvg { path: "M100 134 C144 134 164 172 162 200 C160 224 136 232 100 232 C64 232 40 224 38 200 C36 172 56 134 100 134 Z" }
                }
            }
            Masked {
                clipPath: "M100 134 C144 134 164 172 162 200 C160 224 136 232 100 232 C64 232 40 224 38 200 C36 172 56 134 100 134 Z"
                Blob { x: -40; y: 140; w: 100; h: 130; c: g.shirtShade; o: 0.5 }
                Blob { x: 140; y: 140; w: 100; h: 130; c: g.shirtShade; o: 0.5 }
                Blob { x: 50; y: 210; w: 100; h: 40; c: "#7a1f45"; o: 0.3 }
                Blob { x: 62; y: 128; w: 76; h: 28; c: "#7a1f45"; o: 0.35 }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#9c2a52"; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M100 150 Q96 180 100 214 M64 176 Q74 190 70 208 M136 176 Q126 190 130 208" }
                    }
                }
            }
            Flower { x: 58; y: 162 }
            Text {
                z: 1
                x: 100 - width / 2; y: 150
                text: g.badge
                font.pixelSize: 46; font.weight: Font.Black
                color: "#fffaf0"
                style: Text.Outline; styleColor: g.ink
            }
            Flower { x: 120; y: 176; s: 1.2 }
            Flower { x: 84; y: 200; s: 0.85 }
            Flower { x: 132; y: 146; s: 0.75 }
            Leaf { x: 96; y: 160; rotation: -30 }
            Leaf { x: 146; y: 206; rotation: 50 }

            // Back of the head
            Item {
                width: 200; height: 300
                y: g.bend * 8
                Rectangle { x: 88; y: 120; width: 24; height: 22; radius: 6; color: g.skinShade; border.color: g.ink; border.width: 3 }
                Rectangle { x: 34; y: 74; width: 24; height: 32; radius: 12; color: g.skin; border.color: g.ink; border.width: 3.5 }
                Rectangle { x: 142; y: 74; width: 24; height: 32; radius: 12; color: g.skin; border.color: g.ink; border.width: 3.5 }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4
                        fillGradient: RadialGradient {
                            centerX: 92; centerY: 70; centerRadius: 74; focalX: 86; focalY: 56
                            GradientStop { position: 0; color: g.skinLight }
                            GradientStop { position: 0.55; color: g.skin }
                            GradientStop { position: 1; color: g.skinShade }
                        }
                        PathSvg { path: "M46 86 A54 58 0 1 1 154 86 A54 58 0 1 1 46 86 Z" }
                    }
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M80 128 Q100 136 120 128 M86 136 Q100 141 114 136" }
                    }
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M92 31 C86 14 96 8 100 -2 M102 30 C104 14 116 12 114 -4 M110 33 C118 21 130 23 130 9" }
                    }
                }
                Masked {
                    clipPath: "M46 86 A54 58 0 1 1 154 86 A54 58 0 1 1 46 86 Z"
                    Blob { x: 14; y: 104; w: 172; h: 120; c: "#c9754a"; o: 0.35 }
                    Rectangle {
                        x: 46; y: 22; width: 112; height: 120; radius: 58
                        color: "transparent"; border.color: "#fff1dc"; border.width: 5; opacity: 0.45
                        transform: Translate { x: 5; y: 5 }
                    }
                }
                Rectangle { x: 66; y: 40; width: 34; height: 14; radius: 7; rotation: -22; color: "white"; opacity: 0.55 }
            }
        }
    }

    Item {
        id: rig
        visible: g.view === "side"
        width: 200; height: 300
        transform: [
            Rotation { origin.x: 100; origin.y: 300; angle: g.lean + g.jitter },
            Scale { origin.x: 100; xScale: g.facing * g.turn }
        ]

        Item {
            id: bodyGroup
            width: 200; height: 300
            y: g.hipDrop

            Limb { pivotX: 92; pivotY: 150; swing: g.armSwing + g.armUp; isArm: true; far: true }
            Limb { pivotX: 92; pivotY: 222; swing: -g.legSwing; far: true }
            Limb { pivotX: 106; pivotY: 222; swing: g.legSwing }

            // Torso: a pear-shaped Hawaiian shirt with a belt under the belly.
            Item {
                id: torso
                width: 200; height: 300
                transform: Scale { origin.x: 100; origin.y: 252; yScale: g.squash; xScale: 2 - g.squash }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4; joinStyle: ShapePath.RoundJoin
                        fillGradient: RadialGradient {
                            centerX: 92; centerY: 175; centerRadius: 105; focalX: 84; focalY: 160
                            GradientStop { position: 0; color: g.shirtLight }
                            GradientStop { position: 0.5; color: g.shirt }
                            GradientStop { position: 1; color: g.shirtShade }
                        }
                        PathSvg { path: "M100 132 C142 132 162 172 160 205 C158 240 134 252 100 252 C66 252 42 240 40 205 C38 172 58 132 100 132 Z" }
                    }
                }
                Flower { x: 62; y: 160; s: 1.0 }
                Flower { x: 112; y: 190; s: 1.15 }
                Flower { x: 74; y: 208; s: 0.9 }
                Flower { x: 128; y: 150; s: 0.8 }
                Flower { x: 132; y: 214; s: 0.75 }
                Leaf { x: 94; y: 160; rotation: 30 }
                Leaf { x: 58; y: 190; rotation: -40 }
                Leaf { x: 140; y: 186; rotation: 70 }

                Masked {
                    clipPath: "M100 132 C142 132 162 172 160 205 C158 240 134 252 100 252 C66 252 42 240 40 205 C38 172 58 132 100 132 Z"
                    // Core shadow down his back and under the belly (light from the upper left).
                    Blob { x: -46; y: 156; w: 110; h: 150; c: g.shirtShade; o: 0.4 }
                    Blob { x: 56; y: 228; w: 120; h: 60; c: g.shirtShade; o: 0.35 }
                    // Shadow cast by his head and chin.
                    Blob { x: 70; y: 118; w: 90; h: 34; c: "#7a1f45"; o: 0.35 }
                    // Bounce light along the front, and a soft sheen on the chest.
                    Blob { x: 150; y: 160; w: 30; h: 70; c: "#ffd0dc"; o: 0.35 }
                    Blob { x: 64; y: 148; w: 52; h: 22; c: "white"; o: 0.28; rotation: -18 }
                    // Pocket
                    Rectangle {
                        x: 62; y: 150; width: 28; height: 24; radius: 5
                        color: g.shirtShade; opacity: 0.55
                        Rectangle { x: 0; y: 0; width: 28; height: 8; radius: 4; color: "#7a1f45"; opacity: 0.6 }
                    }
                    // Fabric folds, the button placket and its buttons.
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "#9c2a52"; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathSvg { path: "M56 182 Q70 192 66 214 M74 228 Q90 236 106 230 M136 168 Q128 184 134 200 M48 210 Q58 222 72 226" }
                        }
                        ShapePath {
                            strokeColor: g.ink; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathSvg { path: "M124 140 Q148 176 150 226" }
                        }
                    }
                    Repeater {
                        model: [[134, 160], [143, 184], [148, 208]]
                        Rectangle {
                            required property var modelData
                            x: modelData[0] - 4; y: modelData[1] - 4; width: 8; height: 8; radius: 4
                            color: "#fffaf0"; border.color: g.ink; border.width: 1.5
                        }
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4.5; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M100 132 C142 132 162 172 160 205 C158 240 134 252 100 252 C66 252 42 240 40 205 C38 172 58 132 100 132 Z" }
                    }
                }

                // Badge with his click count.
                Rectangle {
                    x: 106; y: 172; width: 38; height: 38; radius: 19
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffffff" }
                        GradientStop { position: 1; color: "#e9e2f2" }
                    }
                    border.color: g.ink; border.width: 3
                    Text {
                        anchors.centerIn: parent
                        // Read the right way round whichever way he faces.
                        transform: Scale { origin.x: width / 2; xScale: g.facing }
                        text: g.badge
                        font.pixelSize: g.badge > 99 ? 13 : 18; font.weight: Font.Black
                        color: g.ink
                    }
                }

                // Belt and buckle.
                Rectangle {
                    x: 47; y: 228; width: 106; height: 12; radius: 6
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#5a3a26" }
                        GradientStop { position: 1; color: "#2e1d13" }
                    }
                    border.color: g.ink; border.width: 3
                }
                Rectangle {
                    x: 128; y: 225; width: 18; height: 18; radius: 4
                    color: "transparent"; border.color: "#ffcf40"; border.width: 4
                    Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 5; color: "transparent"; border.color: g.ink; border.width: 1.5 }
                }

                // Collar.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillColor: "#fffaf0"
                        PathSvg { path: "M88 134 L104 160 L124 136 Q106 142 88 134 Z" }
                    }
                }
            }

            // In front of his face when it's up in the air.
            Limb { pivotX: 110; pivotY: 152; swing: -g.armSwing + g.armUp * 0.92; isArm: true; z: g.hang > 0.3 ? 5 : 0 }

            // Head, with a little lag behind the body as he walks.
            Item {
                id: head
                width: 200; height: 300
                y: g.breath * -1.2
                transform: Rotation { origin.x: 104; origin.y: 134; angle: g.headLag + g.lean * 0.3 }

                Rectangle {
                    x: 93; y: 120; width: 24; height: 22; radius: 6
                    color: g.skinShade; border.color: g.ink; border.width: 3
                }
                // Ear
                Rectangle {
                    x: 46; y: 72; width: 26; height: 34; radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0; color: g.skin }
                        GradientStop { position: 1; color: g.skinShade }
                    }
                    border.color: g.ink; border.width: 3.5
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // Skull
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4
                        fillGradient: RadialGradient {
                            centerX: 98; centerY: 74; centerRadius: 74; focalX: 92; focalY: 60
                            GradientStop { position: 0; color: g.skinLight }
                            GradientStop { position: 0.55; color: g.skin }
                            GradientStop { position: 1; color: g.skinShade }
                        }
                        PathSvg { path: "M52 86 A54 58 0 1 1 160 86 A54 58 0 1 1 52 86 Z" }
                    }
                    // Inner ear
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M56 82 Q66 89 58 98" }
                    }
                }
                Masked {
                    clipPath: "M52 86 A54 58 0 1 1 160 86 A54 58 0 1 1 52 86 Z"
                    // Jaw and back-of-skull shadow.
                    Blob { x: 96; y: 104; w: 110; h: 80; c: "#c9754a"; o: 0.45 }
                    Blob { x: 30; y: 70; w: 46; h: 100; c: "#c9754a"; o: 0.35 }
                    // Warm rim light round the back of his head.
                    Rectangle {
                        x: 52; y: 22; width: 112; height: 120; radius: 58
                        color: "transparent"; border.color: "#fff1dc"; border.width: 5; opacity: 0.5
                        transform: Translate { x: 6; y: 6 }
                    }
                    // Five o'clock shadow.
                    Repeater {
                        model: 46
                        Rectangle {
                            required property int index
                            readonly property real a: index * 2.39996
                            readonly property real d: Math.sqrt(index / 46)
                            x: 140 + Math.cos(a) * d * 26; y: 132 + Math.sin(a) * d * 11
                            width: 2.2; height: 2.2; radius: 1.1
                            color: g.ink; opacity: 0.28
                        }
                    }
                    // Wrinkle on the forehead.
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "#c9754a"; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathSvg { path: "M112 50 Q126 46 140 50" }
                        }
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4.5; fillColor: "transparent"
                        PathSvg { path: "M52 86 A54 58 0 1 1 160 86 A54 58 0 1 1 52 86 Z" }
                    }
                }

                // Shine on the bald head
                Rectangle {
                    x: 72; y: 40; width: 34; height: 14; radius: 7
                    rotation: -22; color: "white"; opacity: 0.55
                }
                Rectangle {
                    x: 110; y: 36; width: 8; height: 6; radius: 3
                    rotation: -10; color: "white"; opacity: 0.45
                }
                // Three proud hairs
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    transform: Rotation { origin.x: 108; origin.y: 32; angle: g.hairWiggle }
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M98 31 C92 14 102 8 106 -2 M108 30 C110 14 122 12 120 -4 M116 33 C124 21 136 23 136 9" }
                    }
                }
                // Cheek
                Rectangle {
                    x: 104; y: 98; width: 26; height: 22; radius: 11
                    color: "#ff4f6d"; opacity: g.blush
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Eyes
                Item {
                    visible: !g.squinting && !g.eyesClosed
                    Eye { cx: 122; cy: 82; r: 14 }
                    Eye { cx: 150; cy: 78; r: 10.5 }
                }
                Shape {
                    anchors.fill: parent
                    visible: g.squinting
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 5; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M110 72 L130 81 L110 90 M160 70 L144 78 L160 86" }
                    }
                }
                Shape {
                    anchors.fill: parent
                    visible: g.eyesClosed
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M110 84 Q122 74 134 84 M142 80 Q150 72 158 80" }
                    }
                }
                // Brows
                Shape {
                    anchors.fill: parent
                    y: g.browLift
                    preferredRendererType: Shape.CurveRenderer
                    Behavior on y { NumberAnimation { duration: 160 } }
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: g.squinting ? "M106 60 L134 68 M164 58 L142 66" : "M106 64 Q120 54 136 62 M142 60 Q152 53 164 59" }
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // Nose
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4
                        fillGradient: RadialGradient {
                            centerX: 162; centerY: 98; centerRadius: 20; focalX: 158; focalY: 93
                            GradientStop { position: 0; color: "#ffc2a8" }
                            GradientStop { position: 0.6; color: "#ff9c78" }
                            GradientStop { position: 1; color: "#e2714e" }
                        }
                        PathSvg { path: "M147 100 A17 14 0 1 1 181 100 A17 14 0 1 1 147 100 Z" }
                    }
                    // Mustache
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillGradient: LinearGradient {
                            x1: 150; y1: 106; x2: 150; y2: 130
                            GradientStop { position: 0; color: "#8a5230" }
                            GradientStop { position: 1; color: "#4a2612" }
                        }
                        PathSvg { path: "M158 112 C146 104 126 106 116 121 C128 131 146 128 158 119 C166 128 180 128 186 116 C180 106 168 104 158 112 Z" }
                    }
                }
                // Nose shine and nostril, mustache strands.
                Rectangle { x: 158; y: 90; width: 9; height: 6; radius: 3; color: "white"; opacity: 0.75; rotation: -20 }
                Rectangle { x: 155; y: 104; width: 7; height: 4; radius: 2; color: "#8c3a24"; opacity: 0.7; rotation: 15 }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#2e1608"; strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M126 118 Q136 114 146 116 M130 123 Q140 121 150 120 M164 116 Q172 114 178 116 M166 121 Q174 121 180 119" }
                    }
                    ShapePath {
                        strokeColor: "#b8774a"; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: "M134 111 Q146 108 154 112 M164 110 Q172 108 178 111" }
                    }
                }
                // Mouths
                Shape {
                    anchors.fill: parent
                    visible: g.mood === "normal" || g.mood === "relief"
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: g.ink; strokeWidth: 4.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathSvg { path: g.mood === "relief" ? "M130 132 Q148 148 164 130" : "M134 136 Q148 142 160 132" }
                    }
                }
                Rectangle {
                    visible: g.mood === "toot" || g.mood === "surprised"
                    x: 142; y: 128; width: 16; height: 18; radius: 8
                    color: "#7a2335"; border.color: g.ink; border.width: 3.5
                }
                Item {
                    visible: g.mood === "sbd" || g.mood === "whistle"
                    Rectangle { x: 155; y: 129; width: 11; height: 11; radius: 5.5; color: "#7a2335"; border.color: g.ink; border.width: 3 }
                    // A floating note while he whistles innocently.
                    Item {
                        x: 176
                        y: 84 - 6 * Math.abs(Math.sin(g.time * 3))
                        rotation: 10 * Math.sin(g.time * 2)
                        Rectangle { x: 0; y: 22; width: 13; height: 10; radius: 5; color: g.ink; rotation: -20 }
                        Rectangle { x: 10; y: -4; width: 3.5; height: 29; color: g.ink }
                        Rectangle { x: 10; y: -4; width: 12; height: 5; radius: 2; color: g.ink; rotation: 25; transformOrigin: Item.Left }
                    }
                }
            }
        }
    }

    // An arm or leg that swings from a pivot. The far one is drawn darker.
    component Limb: Item {
        property real pivotX
        property real pivotY
        property real swing
        property bool isArm: false
        property bool far: false
        readonly property color cloth: isArm ? (far ? g.shirtShade : g.shirt) : (far ? "#1d4466" : "#2a6496")
        readonly property color clothLight: isArm ? (far ? g.shirt : g.shirtLight) : (far ? "#2a5a85" : "#3b80bd")
        readonly property color flesh: far ? g.skinShade : g.skin
        x: pivotX - 11; y: pivotY - 6
        width: 22; height: isArm ? 70 : 78
        transform: Rotation { origin.x: 11; origin.y: 6; angle: swing }

        // Leg: trousers and a shoe pointing forward
        Rectangle {
            visible: !isArm
            width: 22; height: 62; radius: 10
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: clothLight }
                GradientStop { position: 1; color: cloth }
            }
            border.color: g.ink; border.width: 3.5
            Rectangle { x: 13; y: 6; width: 2; height: 46; color: "#163552"; opacity: 0.6 }
            Rectangle { x: 2; y: 48; width: 18; height: 7; radius: 3; color: "#163552"; opacity: 0.45 }
        }
        Rectangle {
            visible: !isArm
            x: -4; y: 58; width: 42; height: 19; radius: 9.5
            gradient: Gradient {
                GradientStop { position: 0; color: far ? "#4a3428" : "#6b4a36" }
                GradientStop { position: 1; color: "#2a1c14" }
            }
            border.color: g.ink; border.width: 3.5
            Rectangle { x: 24; y: 4; width: 10; height: 4; radius: 2; color: "white"; opacity: 0.45 }
            // Sole
            Rectangle { x: 3; y: 13; width: 36; height: 4; radius: 2; color: "#e8d9c4"; opacity: 0.9 }
            // Laces
            Rectangle { x: 10; y: 3; width: 9; height: 2; radius: 1; color: "white"; rotation: 20; opacity: 0.85 }
            Rectangle { x: 13; y: 6; width: 9; height: 2; radius: 1; color: "white"; rotation: -20; opacity: 0.85 }
        }
        // Arm: short sleeve, forearm and hand
        Rectangle {
            visible: isArm
            x: 3; y: 20; width: 17; height: 38; radius: 8.5
            color: flesh; border.color: g.ink; border.width: 3
        }
        Rectangle {
            visible: isArm
            x: -1; y: 50; width: 25; height: 25; radius: 12.5
            gradient: Gradient {
                GradientStop { position: 0; color: far ? g.skin : g.skinLight }
                GradientStop { position: 1; color: far ? g.skinShade : g.skin }
            }
            border.color: g.ink; border.width: 3.5
            // Thumb and knuckles
            Rectangle { x: 15; y: 4; width: 9; height: 12; radius: 4.5; color: flesh; border.color: g.ink; border.width: 2.5 }
            Rectangle { x: 5; y: 15; width: 10; height: 2; radius: 1; color: g.ink; opacity: 0.4 }
        }
        Rectangle {
            visible: isArm
            x: -5; y: -2; width: 32; height: 32; radius: 13
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: clothLight }
                GradientStop { position: 1; color: cloth }
            }
            border.color: g.ink; border.width: 3.5
        }
    }

    component Eye: Item {
        property real cx
        property real cy
        property real r
        x: cx - r; y: cy - r
        width: r * 2; height: r * 2
        transform: Scale { origin.y: r; yScale: g.eyesOpen }
        Rectangle {
            anchors.fill: parent; radius: r
            gradient: Gradient {
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 1; color: "#e6e1ef" }
            }
            border.color: g.ink; border.width: 3.5
        }
        Rectangle {
            id: iris
            width: r * 1.15; height: width; radius: width / 2
            x: r - width / 2 + g.pupilX * r / 14
            y: r - height / 2 + g.pupilY * r / 14
            gradient: Gradient {
                GradientStop { position: 0; color: "#7ec4ff" }
                GradientStop { position: 1; color: "#2a64c8" }
            }
            border.color: "#163a7a"; border.width: 1.5
            Behavior on x { NumberAnimation { duration: 120 } }
            Behavior on y { NumberAnimation { duration: 120 } }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.5; height: width; radius: width / 2; color: g.ink }
            Rectangle { x: parent.width * 0.5; y: parent.height * 0.1; width: parent.width * 0.32; height: width; radius: width / 2; color: "white" }
            Rectangle { x: parent.width * 0.22; y: parent.height * 0.62; width: parent.width * 0.14; height: width; radius: width / 2; color: "white"; opacity: 0.8 }
        }
        // Upper lid shadow and a thick lash line
        Rectangle {
            x: 3; y: 2; width: parent.width - 6; height: r * 0.45; radius: r * 0.22
            color: g.skinShade; opacity: 0.35
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: g.ink; strokeWidth: 4.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathSvg { path: "M" + (r * 0.12) + " " + (r * 0.8) + " A" + r + " " + r + " 0 0 1 " + (r * 1.88) + " " + (r * 0.8) }
            }
        }
    }

    // A flat, cel-shaded oval of colour, for shadows and highlights.
    component Blob: Rectangle {
        property real w
        property real h
        property color c
        property real o: 1
        width: w; height: h; radius: Math.min(w, h) / 2
        color: c; opacity: o
    }

    // Draws its children clipped to a path, so shading never spills past an outline.
    component Masked: Item {
        id: m
        property string clipPath
        default property alias content: inner.data
        width: 200; height: 300
        Item {
            id: inner
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.1
            }
        }
        Shape {
            id: maskShape
            anchors.fill: parent
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"; strokeWidth: -1; strokeColor: "transparent"
                PathSvg { path: m.clipPath }
            }
        }
    }

    component Flower: Item {
        property real s: 1
        width: 22; height: 22
        scale: s
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 10; height: 10; radius: 5
                color: "#ffe066"
                x: 6 + 6 * Math.cos(index * 2 * Math.PI / 5)
                y: 6 + 6 * Math.sin(index * 2 * Math.PI / 5)
            }
        }
        Rectangle { x: 7; y: 7; width: 8; height: 8; radius: 4; color: "#ff9f1c" }
    }

    component Leaf: Rectangle {
        width: 16; height: 7; radius: 3.5
        color: "#3fb8a0"
    }
}
