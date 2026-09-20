import QtQuick
import QtTest
import "../../Common/functions/DockLayout.js" as DockLayout

TestCase {
    name: "DockLayout"

    function verifyOrdered(result) {
        let end = 0;
        result.slots.forEach(slot => {
            verify(isFinite(slot.start));
            verify(isFinite(slot.span));
            verify(slot.span > 0);
            verify(slot.start >= end - 0.0001);
            end = slot.start + slot.span;
        });
        verify(result.length >= end);
    }

    function test_fitsWithoutExceedingPreferredSize_data() {
        return [
                    {
                        tag: "single",
                        kinds: ["app"],
                        preferred: 48,
                        available: 240,
                        maximum: 2
                    },
                    {
                        tag: "mixed",
                        kinds: ["app", "app", "separator", "app", "app", "app"],
                        preferred: 64,
                        available: 600,
                        maximum: 2
                    },
                    {
                        tag: "compact",
                        kinds: ["app", "app", "app", "app", "app", "app"],
                        preferred: 80,
                        available: 600,
                        maximum: 1.5
                    },
                    {
                        tag: "large",
                        kinds: Array(16).fill("app"),
                        preferred: 80,
                        available: 1200,
                        maximum: 2
                    }
                ];
    }

    function test_fitsWithoutExceedingPreferredSize(data) {
        const resting = DockLayout.layout(data.kinds, data.preferred, data.available, data.maximum, 16, NaN);
        verify(!resting.overflow);
        verify(resting.size >= 32);
        verify(resting.size <= data.preferred);
        verify(resting.length <= data.available + 0.0001);
        verifyOrdered(resting);
        resting.slots.forEach(slot => {
            const hovered = DockLayout.layout(data.kinds, data.preferred, data.available, data.maximum, 16,
                                              slot.center);
            verify(hovered.length <= data.available + 0.0001);
            verify(!hovered.overflow);
            verifyOrdered(hovered);
        });
    }

    function test_shrinksUntilMinimumThenReportsOverflow() {
        const kinds = Array(6).fill("app");
        const spacious = DockLayout.layout(kinds, 80, 1200, 2, 16, NaN);
        const compact = DockLayout.layout(kinds, 80, 600, 2, 16, NaN);
        const crowded = DockLayout.layout(kinds, 80, 240, 2, 16, NaN);
        compare(spacious.size, 80);
        verify(compact.size < spacious.size);
        verify(compact.size > 32);
        verify(!compact.overflow);
        compare(crowded.size, 32);
        verify(crowded.overflow);
        verify(crowded.length > 240);
        verifyOrdered(crowded);
    }

    function test_overflowAccountsForHoverSpace() {
        const kinds = Array(6).fill("app");
        const resting = DockLayout.layout(kinds, 32, 300, 2, 16, NaN);
        verify(resting.baseLength < 300);
        verify(resting.overflow);
        const disabled = DockLayout.layout(kinds, 32, 300, 1, 16, NaN);
        verify(!disabled.overflow);
    }

    function test_pointerDoesNotMoveBaseCenters() {
        const kinds = ["app", "app", "separator", "app", "app"];
        const resting = DockLayout.layout(kinds, 48, 800, 1.75, 20, NaN);
        resting.slots.forEach(target => {
            const hovered = DockLayout.layout(kinds, 48, 800, 1.75, 20, target.center);
            compare(hovered.size, resting.size);
            compare(hovered.baseLength, resting.baseLength);
            hovered.slots.forEach((slot, index) => {
                compare(slot.center, resting.slots[index].center);
            });
            verifyOrdered(hovered);
        });
    }

    function test_hoverRespectsLimitsAndKeepsSeparatorSpacing() {
        const kinds = ["app", "separator", "app", "app", "app"];
        const resting = DockLayout.layout(kinds, 48, 800, 1.6, 24, NaN);
        const hovered = DockLayout.layout(kinds, 48, 800, 1.6, 24, resting.slots[2].center);
        verify(hovered.length > resting.length);
        compare(hovered.slots[1].span, resting.slots[1].span);
        hovered.slots.forEach((slot, index) => {
            if (kinds[index] === "separator")
                return;
            verify(slot.size >= resting.size);
            verify(slot.size <= resting.size * 1.6 + 0.0001);
            verify(hovered.slots[2].size >= slot.size);
        });
        const disabled = DockLayout.layout(kinds, 48, 800, 1, 24, resting.slots[2].center);
        compare(disabled.length, disabled.baseLength);
        disabled.slots.forEach((slot, index) => {
            if (kinds[index] !== "separator")
                compare(slot.size, disabled.size);
        });
    }

    function test_emptyAndSeparatorOnlyLayoutsStayFinite() {
        [[], ["separator"], ["separator", "separator"]].forEach(kinds => {
            const result = DockLayout.layout(kinds, 48, 600, 2, 16, 100);
            compare(result.slots.length, kinds.length);
            verify(isFinite(result.size));
            verify(isFinite(result.length));
            verify(!result.overflow);
            compare(result.length, result.baseLength);
            verifyOrdered(result);
        });
    }

    function test_insertionUsesVisualSlotMidpoints() {
        const slots = [
                  {
                      start: 10,
                      span: 20
                  },
                  {
                      start: 30,
                      span: 60
                  },
                  {
                      start: 90,
                      span: 20
                  }
              ];
        compare(DockLayout.insertionIndex(slots, -100), 0);
        compare(DockLayout.insertionIndex(slots, 19), 0);
        compare(DockLayout.insertionIndex(slots, 21), 1);
        compare(DockLayout.insertionIndex(slots, 59), 1);
        compare(DockLayout.insertionIndex(slots, 61), 2);
        compare(DockLayout.insertionIndex(slots, 99), 2);
        compare(DockLayout.insertionIndex(slots, 101), 3);
        compare(DockLayout.insertionIndex(slots, 1000), 3);
        compare(DockLayout.insertionIndex([], 100), 0);
    }

    function test_removalDistanceMeasuresInwardFromDockEdge() {
        const width = 1200;
        const height = 800;
        const offset = 40;
        compare(DockLayout.removalDistance("left", offset, 300, width, height, offset), 0);
        compare(DockLayout.removalDistance("right", width - offset, 300, width, height, offset), 0);
        compare(DockLayout.removalDistance("bottom", 300, height - offset, width, height, offset), 0);
        compare(DockLayout.removalDistance("left", offset + 100, 5, width, height, offset), 100);
        compare(DockLayout.removalDistance("left", offset + 100, 700, width, height, offset), 100);
        compare(DockLayout.removalDistance("right", width - offset - 100, 5, width, height, offset), 100);
        compare(DockLayout.removalDistance("right", width - offset - 100, 700, width, height, offset), 100);
        compare(DockLayout.removalDistance("bottom", 5, height - offset - 100, width, height, offset), 100);
        compare(DockLayout.removalDistance("bottom", 1100, height - offset - 100, width, height, offset),
                100);


        verify(DockLayout.removalDistance("left", 0, 300, width, height, offset) < 0);
        verify(DockLayout.removalDistance("right", width, 300, width, height, offset) < 0);
        verify(DockLayout.removalDistance("bottom", 300, height, width, height, offset) < 0);
    }
}
