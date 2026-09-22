pragma Singleton

import QtQuick
import Quickshell
import Apollo.Media
import qs.Common

Singleton {
    id: root

    readonly property color primary: MediaPalettePlugin.primary
    readonly property color onPrimary: MediaPalettePlugin.onPrimary
    readonly property color track: MediaPalettePlugin.track

    function extract(artUrl, fallback) {
        const safeFallback = fallback === undefined || fallback === null ? Appearance.colors.colPrimary : fallback;
        MediaPalettePlugin.extract(artUrl || "", safeFallback);
    }
}
