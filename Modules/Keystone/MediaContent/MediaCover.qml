import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property string artUrl
    required property bool playing
    required property bool spectrum
    required property color accentColor
    property bool active: visible
    readonly property bool spectrumActive: active && spectrum && playing
    readonly property string spectrumToken: "keystone-media-cover-" + root

    function syncSpectrum() {
        if (root.spectrumActive)
            AudioSpectrum.acquire(root.spectrumToken);
        else
            AudioSpectrum.release(root.spectrumToken);
    }

    onSpectrumActiveChanged: syncSpectrum()
    Component.onCompleted: syncSpectrum()
    Component.onDestruction: AudioSpectrum.release(root.spectrumToken)

    RadialSpectrum {
        anchors.fill: parent
        visible: root.spectrum
        values: root.spectrumActive ? AudioSpectrum.values : []
        barCount: AudioSpectrum.bars
        innerRadius: width / 3
        maxMagnitude: width * 0.14
        strokeWidth: 3
        strokeColor: root.accentColor
        valueScale: 1.08
        opacity: root.spectrumActive && AudioSpectrum.available ? 1 : 0.35
    }

    Item {
        id: scaleWrapper
        anchors.centerIn: parent
        width: root.spectrum ? root.width * 0.6 : root.width
        height: width
        scale: root.spectrum || root.playing ? 1 : 0.8

        Behavior on scale {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutQuint
            }
        }

        DropShadow {
            anchors.fill: coverContainer
            source: coverContainer
            visible: !root.spectrum
            color: Appearance.applyAlpha(Appearance.colors.colScrim, 0.85)
            radius: 24
            samples: 49
            verticalOffset: 8
            opacity: root.playing ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutQuint
                }
            }
        }

        Item {
            id: coverContainer
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: root.spectrum ? width / 2 : 16
                color: Appearance.colors.colLayer3
                visible: rawImg.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: "music_note"
                    color: Appearance.colors.colOnLayer3
                    font.family: Fonts.materialSymbolsOutlined
                    font.pixelSize: parent.width * 0.47
                }
            }

            Image {
                id: rawImg
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(240, 240)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Rectangle {
                id: maskRect
                anchors.fill: parent
                radius: root.spectrum ? width / 2 : 16
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: rawImg
                maskSource: maskRect
                visible: rawImg.status === Image.Ready
            }
        }
    }
}
