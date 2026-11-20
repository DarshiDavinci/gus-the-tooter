import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 460
    height: 760
    minimumWidth: 400
    minimumHeight: 520
    visible: true
    title: "Gus"
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    readonly property var tootNames: ({
        "tuba": qsTr("The Tuba"),
        "squeaker": qsTr("The Squeaker"),
        "machinegun": qsTr("The Machine Gun"),
        "wetflap": qsTr("The Wet Flap"),
        "question": qsTr("The Question Mark"),
        "opera": qsTr("The Opera"),
        "sbd": qsTr("Silent But Deadly")
    })

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Esc"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggle() }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; onActivated: backend.summon() }
    Shortcut { sequence: "M"; context: Qt.ApplicationShortcut; onActivated: backend.sound = !backend.sound }
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; onActivated: backend.preview(backend.toots.length ? backend.toots[Math.floor(Math.random() * backend.toots.length)] : "tuba") }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ScrollView {
            id: scroller
            anchors.fill: parent
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scroller.availableWidth
                spacing: 18

                Item { Layout.preferredHeight: 6 }

                // Who Gus is and what he's doing right now.
                RowLayout {
                    Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 16
                    Image {
                        source: "qrc:/gus.svg"
                        sourceSize: Qt.size(72, 72)
                        Layout.preferredWidth: 72; Layout.preferredHeight: 72
                        opacity: backend.running ? 1 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Label { text: "Gus"; font.pixelSize: 30; font.weight: Font.Black }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: backend.running ? theme.accent : "#9a9aa2"
                            text: backend.running ? qsTr("Lurking at the bottom of your screen")
                                                  : qsTr("Off. Gus is at home.")
                        }
                    }
                }

                RowLayout {
                    Layout.leftMargin: 24; Layout.rightMargin: 24
                    spacing: 10
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        highlighted: !backend.running
                        font.pixelSize: 16
                        text: backend.running ? qsTr("Stop Gus") : qsTr("Start Gus")
                        onClicked: backend.toggle()
                    }
                    Button {
                        Layout.preferredHeight: 56
                        enabled: backend.running
                        flat: true
                        text: qsTr("Summon now")
                        onClicked: backend.summon()
                    }
                }

                Label {
                    visible: backend.error.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 24; Layout.rightMargin: 24
                    wrapMode: Text.WordWrap
                    color: "#ff6b6b"
                    text: backend.error
                }

                Section { title: qsTr("Timing") }

                Setting {
                    label: qsTr("Pops up every")
                    value: backend.minWait === backend.maxWait
                           ? qsTr("%n seconds", "", backend.minWait)
                           : qsTr("%1–%2 seconds").arg(backend.minWait).arg(backend.maxWait)
                    RangeSlider {
                        Layout.fillWidth: true
                        from: 3; to: 120; stepSize: 1; snapMode: RangeSlider.SnapAlways
                        first.value: backend.minWait
                        second.value: backend.maxWait
                        first.onMoved: backend.minWait = Math.round(first.value)
                        second.onMoved: backend.maxWait = Math.round(second.value)
                    }
                }

                Setting {
                    label: qsTr("Waits to be clicked for")
                    value: qsTr("%n seconds", "", backend.stay)
                    Slider {
                        Layout.fillWidth: true
                        from: 2; to: 30; stepSize: 1; snapMode: Slider.SnapAlways
                        value: backend.stay
                        onMoved: backend.stay = Math.round(value)
                    }
                }

                Section { title: qsTr("Sound") }

                RowLayout {
                    Layout.leftMargin: 24; Layout.rightMargin: 16
                    Label { text: qsTr("Sound"); Layout.fillWidth: true; font.pixelSize: 15 }
                    Switch {
                        checked: backend.sound
                        onToggled: backend.sound = checked
                    }
                }

                Setting {
                    enabled: backend.sound
                    opacity: enabled ? 1 : 0.4
                    label: qsTr("Volume")
                    value: Number(backend.volume).toLocaleString(Qt.locale(), 'f', 0) + " %"
                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 5
                        value: backend.volume
                        onMoved: backend.volume = Math.round(value)
                    }
                }

                Section { title: qsTr("Toots he can do") }

                Repeater {
                    model: backend.allToots
                    delegate: RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 14; Layout.rightMargin: 16
                        spacing: 4
                        CheckBox {
                            Layout.fillWidth: true
                            text: win.tootNames[modelData]
                            checked: backend.toots.indexOf(modelData) >= 0
                            onToggled: backend.setTootEnabled(modelData, checked)
                        }
                        Button {
                            flat: true
                            enabled: backend.sound
                            text: qsTr("Play")
                            onClicked: backend.preview(modelData)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24; Layout.rightMargin: 24
                    Layout.bottomMargin: 20
                    wrapMode: Text.WordWrap
                    color: "#7c7c86"
                    font.pixelSize: 13
                    text: qsTr("Gus keeps lurking after you close this window. Press ? for shortcuts.")
                }
            }
        }

        // Shortcut overlay
        Rectangle {
            anchors.fill: parent
            visible: win.helpVisible
            color: "#e60e0e10"
            MouseArea { anchors.fill: parent; onClicked: win.helpVisible = false }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                Label { text: qsTr("Shortcuts"); font.pixelSize: 22; font.weight: Font.Bold }
                GridLayout {
                    columns: 2
                    columnSpacing: 24; rowSpacing: 8
                    Repeater {
                        model: [
                            ["Space", qsTr("Start or stop Gus")],
                            ["S", qsTr("Summon Gus now")],
                            ["M", qsTr("Sound on or off")],
                            ["P", qsTr("Play a toot")],
                            ["?", qsTr("Show or hide shortcuts")],
                            ["Q", qsTr("Quit (Gus keeps running)")]
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.columnSpan: 2
                            spacing: 24
                            Rectangle {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 28
                                radius: Math.min(4, theme.radius)
                                color: "#1d1d22"; border.color: "#3a3a44"
                                Label { anchors.centerIn: parent; text: modelData[0]; font.family: "monospace" }
                            }
                            Label { text: modelData[1] }
                        }
                    }
                }
            }
        }
    }

    component Section: Label {
        property string title
        text: title
        Layout.leftMargin: 24
        Layout.topMargin: 8
        font.pixelSize: 12
        font.weight: Font.Bold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: theme.accent
    }

    component Setting: ColumnLayout {
        property string label
        property string value
        default property alias content: holder.data
        Layout.fillWidth: true
        Layout.leftMargin: 24; Layout.rightMargin: 24
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Label { text: label; font.pixelSize: 15; Layout.fillWidth: true }
            Label { text: value; color: "#b4b4bc"; font.pixelSize: 14; font.features: { "tnum": 1 } }
        }
        RowLayout { id: holder; Layout.fillWidth: true; Layout.leftMargin: -6; Layout.rightMargin: -6 }
    }
}
