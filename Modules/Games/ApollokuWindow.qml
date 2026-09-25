import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "Apolloku/Sudoku.js" as Sudoku
import "Apolloku/Model.js" as Model

// Apolloku — a sudoku window.
//
// The puzzle logic lives in Apolloku/Sudoku.js and Apolloku/Model.js, which
// are plain ECMAScript with no QML. This file is presentation, input and the
// save files.
PanelWindow {
    id: root

    required property var targetScreen

    // Cell edge in pixels. The board delegates, the 3x3 rules and the confetti
    // launch points all derive from this.
    readonly property real cellPx: 36

    // ── Palette ─────────────────────────────────────────────────────────
    readonly property color cellColor: Appearance.colors.colLayer2
    readonly property color cellPeerColor: Appearance.colors.colLayer3
    readonly property color textColor: Appearance.colors.colOnSurface
    readonly property color mutedColor: Appearance.colors.colSubtext
    readonly property color supportingColor: Appearance.colors.colOnSurfaceVariant
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color errorColor: Appearance.colors.colError
    readonly property color successColor: Appearance.colors.colTertiary
    readonly property color notesColor: Appearance.colors.colSecondary

    // ── Game state ──────────────────────────────────────────────────────
    // `difficulty` and `rating` hold the protocol values Easy/Medium/Hard/
    // Expert; difficultyName() is what is shown.
    property string difficulty: "Medium"
    property string rating: ""
    property var puzzle: Sudoku.emptyGrid()
    property var solution: Sudoku.emptyGrid()
    property var cells: Sudoku.emptyGrid()
    property var notes: Sudoku.emptyNotes()
    property int selected: 40
    property bool notesMode: false
    property bool solved: false
    property bool paused: false
    property bool started: false
    property int hintsUsed: 0
    property var undoStack: []
    property var redoStack: []
    property var stats: Model.emptyStats()
    property bool statsLoaded: false
    property bool saveLoaded: false

    readonly property var conflicts: Sudoku.conflicts(cells)
    readonly property var digitCounts: Sudoku.digitCounts(cells)
    readonly property int filled: Sudoku.filledCount(cells)
    readonly property bool playable: started && !solved && !paused && !generating

    // ── Clock ───────────────────────────────────────────────────────────
    property real accumulatedMs: 0
    property real runningSince: 0
    property int tick: 0
    // `tick` is referenced so the binding re-evaluates every half second;
    // Date.now() is not a property and would otherwise never invalidate it.
    readonly property real elapsedMs: {
        tick;
        return accumulatedMs + (runningSince > 0 ? (Date.now() - runningSince) : 0);
    }

    // ── Celebration ─────────────────────────────────────────────────────
    // One NumberAnimation drives every piece through arithmetic on a single
    // progress value, rather than ~320 Rectangles each animating themselves.
    property bool celebrating: false
    property bool celebrateDone: false
    property real celebrateProgress: 0
    property var confetti: []
    readonly property real pieceLife: 0.28
    // Taken from the theme, so the confetti follows the wallpaper palette.
    readonly property var confettiColors: [Appearance.colors.colPrimary, Appearance.colors.colTertiary,
        Appearance.colors.colSecondary, Appearance.colors.colPrimaryFixedDim,
        Appearance.colors.colTertiaryFixedDim]

    // ── Generation, one attempt per frame ───────────────────────────────
    // Carving a rated puzzle can take a few hundred milliseconds and runs on
    // the shell's UI thread, so it is spread across frames.
    property var generator: null
    property bool generating: false
    property real genProgress: 0

    function difficultyName(level) {
        switch (level) {
        case "Easy":
            return qsTr("Easy");
        case "Medium":
            return qsTr("Medium");
        case "Hard":
            return qsTr("Hard");
        case "Expert":
            return qsTr("Expert");
        default:
            return level;
        }
    }

    function statusText() {
        if (root.generating)
            return qsTr("Generating %1%").arg(Math.round(root.genProgress * 100));
        if (!root.started)
            return qsTr("Choose a difficulty");
        if (root.solved)
            return root.hintsUsed > 0 ? qsTr("Solved with %n hint(s)", "", root.hintsUsed) : qsTr("Solved");
        if (root.paused)
            return qsTr("Paused");
        if (root.notesMode)
            return qsTr("Pencil marks");
        const left = 81 - root.filled;
        return left === 0 ? qsTr("Check your work") : qsTr("%n to go", "", left);
    }

    function isGiven(i) {
        return puzzle[i] !== 0;
    }

    function startClock() {
        if (runningSince <= 0)
            runningSince = Date.now();
    }

    function stopClock() {
        if (runningSince > 0) {
            accumulatedMs += Date.now() - runningSince;
            runningSince = 0;
        }
    }

    function buildCelebration() {
        const order = [];
        for (let i = 0; i < 81; i++)
            order.push(i);
        for (let j = order.length - 1; j > 0; j--) {
            const k = Math.floor(Math.random() * (j + 1));
            const swap = order[j];
            order[j] = order[k];
            order[k] = swap;
        }
        const pieces = [];
        const window = 1.0 - pieceLife;
        for (let n = 0; n < 81; n++) {
            const index = order[n];
            const delay = window * (n / 80);
            const cx = (index % 9) * (cellPx + 1) + cellPx / 2;
            const cy = Math.floor(index / 9) * (cellPx + 1) + cellPx / 2;
            for (let q = 0; q < 4; q++) {
                const angle = Math.random() * Math.PI * 2;
                const speed = cellPx * (0.6 + Math.random() * 1.1);
                pieces.push({
                                "delay": delay,
                                "x0": cx,
                                "y0": cy,
                                "vx": Math.cos(angle) * speed,
                                "vy": Math.sin(angle) * speed - cellPx * 0.5,
                                "spin": (Math.random() * 2 - 1) * 540,
                                "size": Math.max(2, Math.round(cellPx * (0.10 + Math.random() * 0.09))),
                                "hue": Math.floor(Math.random() * confettiColors.length)
                            });
            }
        }
        confetti = pieces;
    }

    function startCelebration() {
        if (!started || !solved)
            return;
        buildCelebration();
        celebrateDone = false;
        celebrateProgress = 0;
        celebrating = true;
        popAnimation.restart();
    }

    function endCelebration() {
        holdTimer.stop();
        popAnimation.stop();
        celebrating = false;
        celebrateDone = false;
        celebrateProgress = 0;
        confetti = [];
    }

    function newGame(level) {
        endCelebration();
        const want = Model.normalizeDifficulty(level, difficulty);
        // Abandoning a game in progress breaks the streak; starting from an
        // idle or finished board does not.
        if (started && !solved)
            stats = Model.recordAbandon(stats);
        difficulty = want;
        rating = "";
        generator = Sudoku.createGenerator(want);
        genProgress = 0;
        generating = true;
        stopClock();
        accumulatedMs = 0;
        runningSince = 0;
    }

    function applyGenerated(g) {
        puzzle = g.puzzle;
        solution = g.solution;
        cells = g.puzzle.slice();
        notes = Sudoku.emptyNotes();
        rating = g.rating || g.difficulty;
        selected = firstEmptyCell();
        notesMode = false;
        solved = false;
        paused = false;
        started = true;
        hintsUsed = 0;
        undoStack = [];
        redoStack = [];
        stats = Model.recordStart(stats, difficulty, false);
        saveStats();
        accumulatedMs = 0;
        startClock();
        persist();
    }

    function firstEmptyCell() {
        for (let i = 0; i < 81; i++) {
            if (cells[i] === 0)
                return i;
        }
        return 40;
    }

    // ── Moves ───────────────────────────────────────────────────────────
    function snapshot() {
        return {
            "cells": cells.slice(),
            "notes": notes.slice(),
            "selected": selected
        };
    }

    function pushUndo() {
        const stack = undoStack.slice();
        stack.push(snapshot());
        if (stack.length > 200)
            stack.shift();
        undoStack = stack;
        redoStack = [];
    }

    function undo() {
        if (undoStack.length === 0)
            return;
        const stack = undoStack.slice();
        const prev = stack.pop();
        const redoList = redoStack.slice();
        redoList.push(snapshot());
        undoStack = stack;
        redoStack = redoList;
        cells = prev.cells;
        notes = prev.notes;
        selected = prev.selected;
        solved = Sudoku.isComplete(cells);
        persist();
    }

    function redo() {
        if (redoStack.length === 0)
            return;
        const redoList = redoStack.slice();
        const next = redoList.pop();
        const stack = undoStack.slice();
        stack.push(snapshot());
        redoStack = redoList;
        undoStack = stack;
        cells = next.cells;
        notes = next.notes;
        selected = next.selected;
        solved = Sudoku.isComplete(cells);
        persist();
    }

    function setDigit(digit) {
        if (!playable || isGiven(selected))
            return;
        if (notesMode) {
            toggleNote(selected, digit);
            return;
        }
        pushUndo();
        const next = cells.slice();
        // Tapping the digit already in the cell clears it, so the pad can both
        // place and erase.
        next[selected] = (next[selected] === digit) ? 0 : digit;
        cells = next;
        if (next[selected] !== 0)
            notes = Sudoku.clearPeerNotes(notes, selected, digit);
        refreshSolved();
        persist();
    }

    function clearCell() {
        if (!playable || isGiven(selected))
            return;
        pushUndo();
        const next = cells.slice();
        next[selected] = 0;
        cells = next;
        const n = notes.slice();
        n[selected] = 0;
        notes = n;
        solved = false;
        persist();
    }

    function toggleNote(index, digit) {
        if (!playable || isGiven(index) || cells[index] !== 0)
            return;
        pushUndo();
        const n = notes.slice();
        n[index] = Sudoku.toggleNote(n[index], digit);
        notes = n;
        persist();
    }

    function fillNotes() {
        if (!playable)
            return;
        pushUndo();
        notes = Sudoku.fillAllNotes(cells);
        persist();
    }

    function hint() {
        if (!playable)
            return;
        // Fill the selected cell when it is wrong or empty, otherwise the
        // first cell that needs help — so a hint is never a no-op.
        let target = -1;
        if (!isGiven(selected) && cells[selected] !== solution[selected])
            target = selected;
        if (target === -1) {
            for (let i = 0; i < 81; i++) {
                if (cells[i] !== solution[i]) {
                    target = i;
                    break;
                }
            }
        }
        if (target === -1)
            return;
        pushUndo();
        const next = cells.slice();
        next[target] = solution[target];
        cells = next;
        notes = Sudoku.clearPeerNotes(notes, target, solution[target]);
        selected = target;
        hintsUsed++;
        refreshSolved();
        persist();
    }

    function refreshSolved() {
        const done = Sudoku.isComplete(cells);
        const newlySolved = done && !solved;
        if (newlySolved) {
            stopClock();
            stats = Model.recordSolve(stats, difficulty, elapsedMs, hintsUsed);
            saveStats();
        }
        solved = done;
        // After `solved` is set, not before: startCelebration checks it.
        if (newlySolved)
            startCelebration();
    }

    function moveCursor(dx, dy) {
        const r = Math.floor(selected / 9) + dy;
        const c = (selected % 9) + dx;
        if (r < 0 || r > 8 || c < 0 || c > 8)
            return;
        selected = r * 9 + c;
    }

    function togglePause() {
        if (!started || solved || generating)
            return;
        paused = !paused;
        if (paused)
            stopClock();
        else
            startClock();
        persist();
    }

    // ── Persistence ─────────────────────────────────────────────────────
    function persist() {
        if (!started || !GameService.storeReady)
            return;
        saveFile.setText(Model.serialize({
                                             "difficulty": difficulty,
                                             "puzzle": puzzle,
                                             "solution": solution,
                                             "cells": cells,
                                             "notes": notes,
                                             "elapsedMs": elapsedMs,
                                             "hintsUsed": hintsUsed,
                                             "selected": selected,
                                             "notesMode": notesMode,
                                             "solved": solved
                                         }));
    }

    function saveStats() {
        if (GameService.storeReady)
            statsFile.setText(Model.serializeStats(stats));
    }

    screen: targetScreen
    visible: GameService.activeGame === "apolloku" && targetScreen && targetScreen.name
             === GameService.targetScreenName
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: 372
    implicitHeight: card.implicitHeight
    WlrLayershell.namespace: "apollo-shell-games"
    WlrLayershell.layer: WlrLayer.Top
    // Digits and arrows have to reach the board rather than the focused window.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The elapsed time is the only thing that changes continuously, so it is
    // persisted on close rather than on every frame.
    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus(Qt.OtherFocusReason);
            openAnimation.restart();
        } else {
            endCelebration();
            stopClock();
            persist();
        }
    }

    Timer {
        interval: 500
        running: root.runningSince > 0 && root.visible
        repeat: true
        onTriggered: root.tick++
    }

    NumberAnimation {
        id: popAnimation

        target: root
        property: "celebrateProgress"
        from: 0
        to: 1
        duration: 2600
        onFinished: {
            root.celebrateDone = true;
            holdTimer.restart();
        }
    }

    Timer {
        id: holdTimer

        interval: 5000
        onTriggered: root.endCelebration()
    }

    Timer {
        interval: 16
        repeat: true
        running: root.generating
        onTriggered: {
            if (!root.generator) {
                root.generating = false;
                return;
            }
            if (Sudoku.step(root.generator)) {
                root.applyGenerated(root.generator.result);
                root.generator = null;
                root.generating = false;
                root.genProgress = 1;
            } else {
                root.genProgress = Sudoku.progress(root.generator);
            }
        }
    }

    FileView {
        id: saveFile

        path: GameService.storeReady ? GameService.saveDir + "/apolloku.json" : ""
        printErrors: false
        onLoaded: {
            if (root.saveLoaded)
                return;
            root.saveLoaded = true;
            const st = Model.parse(text());
            if (!st)
                return;
            root.difficulty = st.difficulty;
            root.puzzle = st.puzzle;
            root.solution = st.solution;
            root.cells = st.cells;
            root.notes = st.notes;
            root.selected = st.selected;
            root.notesMode = st.notesMode;
            root.solved = st.solved;
            root.hintsUsed = st.hintsUsed;
            root.accumulatedMs = st.elapsedMs;
            root.started = true;
            // Resume paused: the clock should not have run while the shell was
            // closed, and adding that time would poison every best time.
            root.paused = !st.solved;
        }
        onLoadFailed: root.saveLoaded = true
    }

    FileView {
        id: statsFile

        path: GameService.storeReady ? GameService.saveDir + "/apolloku-stats.json" : ""
        printErrors: false
        onLoaded: {
            if (root.statsLoaded)
                return;
            root.statsLoaded = true;
            root.stats = Model.parseStats(text());
        }
        onLoadFailed: root.statsLoaded = true
    }

    Rectangle {
        id: card

        anchors.fill: parent
        implicitHeight: content.implicitHeight + Metrics.spacingL * 2
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(Appearance.colors.colLayer0)
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        transformOrigin: Item.Center
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.celebrating)
                    root.endCelebration();
                else
                    GameService.close();
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                root.setDigit(event.key - Qt.Key_0);
            } else if (event.key === Qt.Key_0 || event.key === Qt.Key_Delete || event.key
                       === Qt.Key_Backspace) {
                root.clearCell();
            } else if (event.key === Qt.Key_Left) {
                root.moveCursor(-1, 0);
            } else if (event.key === Qt.Key_Right) {
                root.moveCursor(1, 0);
            } else if (event.key === Qt.Key_Up) {
                root.moveCursor(0, -1);
            } else if (event.key === Qt.Key_Down) {
                root.moveCursor(0, 1);
            } else if (event.key === Qt.Key_N) {
                root.notesMode = !root.notesMode;
            } else if (event.key === Qt.Key_H) {
                root.hint();
            } else if (event.key === Qt.Key_U) {
                root.undo();
            } else if (event.key === Qt.Key_R) {
                root.redo();
            } else if (event.key === Qt.Key_F) {
                root.fillNotes();
            } else if (event.key === Qt.Key_Space) {
                root.togglePause();
            } else {
                return;
            }
            event.accepted = true;
        }

        ParallelAnimation {
            id: openAnimation

            NumberAnimation {
                target: card
                property: "scale"
                from: 0.92
                to: 1
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }

            NumberAnimation {
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animation.expressiveSlowEffects.duration
                easing.type: Appearance.animation.expressiveSlowEffects.type
                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
            }
        }

        ColumnLayout {
            id: content

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Metrics.spacingL
            }
            spacing: Metrics.spacingS

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS

                MaterialSymbol {
                    text: "grid_on"
                    iconSize: Metrics.iconS
                    color: root.accent
                }

                Text {
                    text: qsTr("Apolloku")
                    color: root.textColor
                    font.family: Typography.titleSmall.family
                    font.pixelSize: Typography.titleSmall.pixelSize
                    font.weight: Font.Medium
                }

                Item {
                    Layout.fillWidth: true
                }

                // Shows what the puzzle measured as, and says so when that
                // differs from what was asked for.
                Text {
                    text: !root.started ? "" : root.rating !== "" && root.rating !== root.difficulty
                                          ? qsTr("%1 → %2").arg(root.difficultyName(root.difficulty)).arg(
                                                root.difficultyName(root.rating)) : root.difficultyName(
                                                root.difficulty)
                    color: root.mutedColor
                    font.family: Fonts.ui
                    font.pixelSize: 11
                }

                Text {
                    text: root.started ? Model.formatTime(root.elapsedMs) : ""
                    color: root.paused ? root.mutedColor : root.accent
                    font.family: Fonts.numeric
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.statusText()
                color: root.solved ? root.successColor : root.supportingColor
                font.family: Fonts.ui
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }

            // ── Board ───────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: board.width
                implicitHeight: board.height

                Grid {
                    id: board

                    columns: 9
                    spacing: 1

                    Repeater {
                        model: 81

                        delegate: Rectangle {
                            id: cell

                            required property int index
                            readonly property int value: root.cells[index]
                            readonly property bool given: root.isGiven(index)
                            readonly property bool isSelected: root.selected === index
                            readonly property bool bad: root.conflicts[index]
                            readonly property bool peer: !isSelected && (Sudoku.rowOf(index) === Sudoku.rowOf(
                                                                             root.selected) || Sudoku.colOf(
                                                                             index) === Sudoku.colOf(
                                                                             root.selected) || Sudoku.boxOf(
                                                                             index) === Sudoku.boxOf(
                                                                             root.selected))
                            readonly property bool sameDigit: value !== 0 && value === root.cells[root.selected]
                                                              && !isSelected

                            width: root.cellPx
                            height: root.cellPx
                            radius: Appearance.rounding.extraSmall
                            color: root.paused ? root.cellColor : bad ? Appearance.applyAlpha(root.errorColor, 0.28) :
                                                                        isSelected ? Appearance.applyAlpha(
                                                                                         root.accent, 0.30) :
                                                                                     sameDigit
                                                                                     ? Appearance.applyAlpha(
                                                                                           root.accent, 0.14) :
                                                                                       peer ? root.cellPeerColor :
                                                                                              root.cellColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveFastEffects.duration
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cell.value !== 0 && !root.paused
                                text: cell.value
                                color: cell.bad ? root.errorColor : cell.given ? root.textColor : root.accent
                                font.family: Fonts.numeric
                                font.pixelSize: 17
                                font.bold: cell.given
                            }

                            // Pencil marks, in their natural 3x3 positions so a
                            // 5 always sits in the middle.
                            Grid {
                                anchors.centerIn: parent
                                columns: 3
                                visible: cell.value === 0 && root.notes[cell.index] !== 0 && !root.paused

                                Repeater {
                                    model: 9

                                    delegate: Text {
                                        required property int index

                                        width: 11
                                        height: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: Sudoku.hasNote(root.notes[cell.index], index + 1) ? String(index
                                                                                                         + 1) : ""
                                        color: root.mutedColor
                                        font.family: Fonts.numeric
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.paused || root.generating)
                                        return;
                                    root.selected = cell.index;
                                }
                            }
                        }
                    }
                }

                // The 3x3 box separators, drawn over a plain uniform grid.
                Repeater {
                    model: 2

                    delegate: Rectangle {
                        required property int index

                        x: (index + 1) * ((root.cellPx + 1) * 3) - 2
                        width: 2
                        height: board.height
                        color: Appearance.applyAlpha(root.textColor, 0.25)
                    }
                }

                Repeater {
                    model: 2

                    delegate: Rectangle {
                        required property int index

                        y: (index + 1) * ((root.cellPx + 1) * 3) - 2
                        width: board.width
                        height: 2
                        color: Appearance.applyAlpha(root.textColor, 0.25)
                    }
                }

                // Confetti: every piece is arithmetic on celebrateProgress.
                Item {
                    anchors.fill: parent
                    visible: root.celebrating
                    z: 10

                    Repeater {
                        model: root.confetti

                        delegate: Rectangle {
                            required property var modelData
                            readonly property real t: Math.max(0, Math.min(1, (root.celebrateProgress
                                                                               - modelData.delay) / root.pieceLife))

                            visible: t > 0 && t < 1
                            width: modelData.size
                            height: modelData.size
                            radius: modelData.size > 4 ? 1 : 0
                            color: root.confettiColors[modelData.hue]
                            opacity: 1 - t * t
                            rotation: modelData.spin * t
                            x: modelData.x0 + modelData.vx * t - width / 2
                            // t² is gravity: the pieces arc rather than drift.
                            y: modelData.y0 + modelData.vy * t + root.cellPx * 3.2 * t * t - height / 2
                        }
                    }
                }

                // The result, once the confetti has settled.
                Item {
                    anchors.fill: parent
                    visible: root.celebrating
                    z: 11

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.86
                        height: resultColumn.implicitHeight + Metrics.spacingXL
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainerHigh
                        border.width: 1
                        border.color: Appearance.applyAlpha(root.accent, 0.35)
                        opacity: root.celebrateDone ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 260
                            }
                        }

                        Column {
                            id: resultColumn

                            readonly property var best: root.stats.byDifficulty[root.difficulty]
                            readonly property bool personalBest: best && best.bestMs > 0 && Math.round(
                                                                     root.elapsedMs) <= best.bestMs

                            anchors.centerIn: parent
                            spacing: Metrics.spacingXS

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.hintsUsed > 0 ? qsTr("Solved") : qsTr("Solved clean")
                                color: root.successColor
                                font.family: Typography.titleMedium.family
                                font.pixelSize: Typography.titleMedium.pixelSize
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("%1 in %2").arg(root.difficultyName(root.rating !== "" ? root.rating :
                                                                                                    root.difficulty)).arg(
                                          Model.formatTime(root.elapsedMs))
                                color: root.supportingColor
                                font.family: Fonts.ui
                                font.pixelSize: 12
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !!resultColumn.best && resultColumn.best.bestMs > 0
                                text: resultColumn.personalBest ? qsTr("New personal best") : visible ? qsTr(
                                                                                                            "Best %1").arg(
                                                                                                            Model.formatTime(
                                                                                                                resultColumn.best.bestMs)) :
                                                                                                        ""
                                color: resultColumn.personalBest ? root.notesColor : root.mutedColor
                                font.family: Fonts.ui
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.hintsUsed > 0
                                text: qsTr("%n hint(s)", "", root.hintsUsed)
                                color: root.mutedColor
                                font.family: Fonts.ui
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Click anywhere to dismiss rather than waiting it out.
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.celebrating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.endCelebration()
                    }
                }

                // Paused / idle veil
                Rectangle {
                    anchors.fill: parent
                    visible: root.paused || !root.started || root.generating
                    color: Appearance.applyAlpha(Appearance.colors.colSurfaceContainerLow, 0.9)
                    radius: Appearance.rounding.small

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        visible: root.generating
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !root.generating
                        text: root.paused ? "play_arrow" : "grid_on"
                        iconSize: 40
                        color: root.mutedColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.generating ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (root.generating)
                                return;
                            if (root.paused)
                                root.togglePause();
                            else if (!root.started)
                                root.newGame(root.difficulty);
                        }
                    }
                }
            }

            // ── Number pad ──────────────────────────────────────────────
            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 9
                spacing: 3

                Repeater {
                    model: 9

                    delegate: Rectangle {
                        id: padKey

                        required property int index
                        readonly property int digit: index + 1
                        // A digit placed nine times is finished; greying it
                        // out saves counting the board by eye.
                        readonly property bool exhausted: root.digitCounts[index] >= 9

                        width: 34
                        height: 32
                        radius: Appearance.rounding.small
                        color: padMouse.containsMouse && root.playable ? Appearance.applyAlpha(root.accent, 0.22) :
                                                                         root.cellColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: padKey.digit
                            color: padKey.exhausted ? root.mutedColor : root.notesMode ? root.notesColor :
                                                                                         root.textColor
                            font.family: Fonts.numeric
                            font.pixelSize: 15
                            font.bold: true
                        }

                        MouseArea {
                            id: padMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setDigit(padKey.digit)
                        }
                    }
                }
            }

            // ── Actions ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXXS

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "edit_note"
                    tooltipText: qsTr("Pencil marks (N)")
                    selected: root.notesMode
                    enabled: root.playable
                    onClicked: root.notesMode = !root.notesMode
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "undo"
                    tooltipText: qsTr("Undo (U)")
                    enabled: root.playable && root.undoStack.length > 0
                    onClicked: root.undo()
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "lightbulb"
                    tooltipText: qsTr("Hint (H)")
                    enabled: root.playable
                    onClicked: root.hint()
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: root.paused ? "play_arrow" : "pause"
                    tooltipText: root.paused ? qsTr("Resume (Space)") : qsTr("Pause (Space)")
                    selected: root.paused
                    enabled: root.started && !root.solved && !root.generating
                    onClicked: root.togglePause()
                }

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: ["Easy", "Medium", "Hard", "Expert"]

                    delegate: Rectangle {
                        id: levelChip

                        required property string modelData
                        readonly property bool current: root.difficulty === modelData

                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.small
                        color: levelChip.current ? Appearance.colors.colSecondaryContainer : levelMouse.containsMouse
                                                   ? root.cellPeerColor : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.difficultyName(levelChip.modelData).charAt(0)
                            color: levelChip.current ? Appearance.colors.colOnSecondaryContainer : root.mutedColor
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: levelMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.newGame(levelChip.modelData)
                        }

                        StyledToolTip {
                            extraVisibleCondition: levelMouse.containsMouse
                            text: qsTr("New %1 game").arg(root.difficultyName(levelChip.modelData))
                        }
                    }
                }
            }

            // ── Personal bests ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: root.cellColor
                visible: root.stats.solved > 0

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Metrics.spacingM
                        rightMargin: Metrics.spacingM
                    }
                    spacing: Metrics.spacingS

                    Text {
                        text: qsTr("%n solved", "", root.stats.solved)
                        color: root.supportingColor
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }

                    Text {
                        visible: root.stats.streak > 1
                        text: qsTr("%n streak", "", root.stats.streak)
                        color: root.successColor
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        readonly property var best: root.stats.byDifficulty[root.difficulty]

                        visible: !!best && best.bestMs > 0
                        text: visible ? qsTr("Best %1").arg(Model.formatTime(best.bestMs)) : ""
                        color: root.mutedColor
                        font.family: Fonts.ui
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
