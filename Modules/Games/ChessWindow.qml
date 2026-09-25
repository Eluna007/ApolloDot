import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "Chess/Chess.js" as Chess
import "Chess/Engine.js" as Engine
import "Chess/Model.js" as Model

// Chess: play a local opponent or the built-in engine, with chess.com ratings
// alongside when a username is configured.
//
// Rules, search and parsing are in Chess/*.js, which carry no QML. This file
// is presentation, input and the save files.
PanelWindow {
    id: root

    required property var targetScreen

    readonly property real cellPx: 41

    // ── Palette ─────────────────────────────────────────────────────────
    readonly property color darkSquare: Appearance.colors.colLayer2
    readonly property color lightSquare: Appearance.colors.colLayer4
    readonly property color surfaceColor: Appearance.colors.colLayer2
    readonly property color hoverColor: Appearance.colors.colLayer3
    readonly property color textColor: Appearance.colors.colOnSurface
    readonly property color mutedColor: Appearance.colors.colSubtext
    readonly property color supportingColor: Appearance.colors.colOnSurfaceVariant
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color errorColor: Appearance.colors.colError
    readonly property color successColor: Appearance.colors.colTertiary

    // ── Game state ──────────────────────────────────────────────────────
    property var pos: Chess.startPosition()
    property string startFen: Chess.START_FEN
    property var sans: []
    property var moveLog: []          // {from, to, promotion}, for replay on load
    property var keys: []             // position keys, for threefold repetition
    property int selected: -1
    property var destinations: []
    property int lastFrom: -1
    property int lastTo: -1
    property bool flipped: false
    property string mode: "engine"    // "engine" | "human"
    property int engineColor: Chess.BLACK
    property int level: 3
    property string outcome: ""
    property bool loaded: false
    property var stats: Model.emptyStats()
    property bool statsLoaded: false
    property bool resultRecorded: false

    // Promotion needs an answer before the move can be made, so the move is
    // held here while the picker is up.
    property int promoFrom: -1
    property int promoTo: -1
    readonly property bool promoting: promoFrom >= 0

    property var searchState: null
    property bool thinking: false

    readonly property bool humanToMove: outcome === "" && !thinking && (mode === "human" || pos.turn
                                                                         !== engineColor)

    function levelName(n) {
        switch (Math.max(1, Math.min(5, n | 0))) {
        case 1:
            return qsTr("Beginner");
        case 2:
            return qsTr("Casual");
        case 3:
            return qsTr("Club");
        case 4:
            return qsTr("Strong");
        default:
            return qsTr("Best");
        }
    }

    function outcomeText() {
        switch (root.outcome) {
        case "checkmate":
            // The side to move is the side that has been mated.
            return root.pos.turn === Chess.WHITE ? qsTr("Black wins by checkmate") : qsTr(
                                                       "White wins by checkmate");
        case "stalemate":
            return qsTr("Stalemate");
        case "fifty":
            return qsTr("Draw by the fifty-move rule");
        case "repetition":
            return qsTr("Draw by threefold repetition");
        case "insufficient":
            return qsTr("Draw by insufficient material");
        default:
            return "";
        }
    }

    function statusText() {
        if (root.outcome !== "")
            return root.outcomeText();
        if (root.thinking)
            return qsTr("Thinking…");
        if (root.promoting)
            return qsTr("Choose a piece");
        const white = root.pos.turn === Chess.WHITE;
        if (Chess.inCheck(root.pos))
            return white ? qsTr("Check — white to move") : qsTr("Check — black to move");
        return white ? qsTr("White to move") : qsTr("Black to move");
    }

    function ratingLabel(kind) {
        switch (kind) {
        case "bullet":
            return qsTr("Bullet");
        case "blitz":
            return qsTr("Blitz");
        case "rapid":
            return qsTr("Rapid");
        case "daily":
            return qsTr("Daily");
        default:
            return kind;
        }
    }

    // White uses the outline glyphs and Black the solid ones, both drawn in the
    // foreground colour, which stays legible whatever the palette does.
    function pieceGlyph(piece) {
        if (piece === Chess.EMPTY)
            return "";
        const base = Chess.colorOf(piece) === Chess.WHITE ? 0x2654 : 0x265A;
        // King=6 maps to offset 0, Pawn=1 to offset 5
        return String.fromCodePoint(base + (6 - Chess.typeOf(piece)));
    }

    function isOurs(sq) {
        const p = pos.board[sq];
        return p !== Chess.EMPTY && Chess.colorOf(p) === pos.turn;
    }

    // Board index for a visual cell, honouring the flip.
    function squareFor(cellIndex) {
        let file = cellIndex % 8;
        let rank = 7 - Math.floor(cellIndex / 8);
        if (flipped) {
            file = 7 - file;
            rank = 7 - rank;
        }
        return rank * 16 + file;
    }

    // ── Moves ───────────────────────────────────────────────────────────
    function selectSquare(sq) {
        if (!humanToMove || promoting)
            return;

        if (selected >= 0 && destinations.indexOf(sq) !== -1) {
            // A pawn reaching the last rank needs a piece chosen first.
            const moving = pos.board[selected];
            const lastRank = Chess.colorOf(moving) === Chess.WHITE ? 7 : 0;
            if (Chess.typeOf(moving) === Chess.PAWN && Math.floor(sq / 16) === lastRank) {
                promoFrom = selected;
                promoTo = sq;
                return;
            }
            applyMove(selected, sq, 0);
            return;
        }

        if (isOurs(sq)) {
            selected = sq;
            destinations = Chess.destinations(pos, sq);
        } else {
            selected = -1;
            destinations = [];
        }
    }

    function applyMove(from, to, promotion) {
        // Play the move on a copy and assign that: Chess.make mutates, and QML
        // emits no change signal when a property is assigned the object it
        // already holds.
        const next = Chess.clone(pos);
        const m = Chess.findMove(next, from, to, promotion || 0);
        if (!m)
            return;

        const san = Chess.toSan(next, m);      // before the move: SAN describes it
        Chess.make(next, m);

        sans = sans.concat([san]);
        moveLog = moveLog.concat([{
                                      "from": from,
                                      "to": to,
                                      "promotion": m.promotion || 0
                                  }]);
        keys = keys.concat([Chess.positionKey(next)]);
        lastFrom = from;
        lastTo = to;
        selected = -1;
        destinations = [];
        promoFrom = -1;
        promoTo = -1;
        pos = next;

        refreshOutcome();
        persist();
        maybeStartEngine();
    }

    function refreshOutcome() {
        outcome = Chess.outcome(pos, keys);
        if (outcome !== "" && !resultRecorded) {
            resultRecorded = true;
            if (mode === "engine") {
                const result = Model.isDraw(outcome) ? "drawn" : (pos.turn === engineColor ? "won" : "lost");
                stats = Model.recordResult(stats, level, result);
                saveStats();
            }
        }
    }

    function undo() {
        if (thinking)
            stopEngine();
        if (moveLog.length === 0)
            return;
        // Undoing a single ply against the engine would just hand the move
        // back to it, so take the pair.
        const drop = (mode === "engine" && moveLog.length >= 2) ? 2 : 1;
        rebuild(startFen, moveLog.slice(0, moveLog.length - drop));
        persist();
    }

    // Replay from the start rather than unmaking: the move list is the record,
    // and this keeps SAN, repetition keys and the board in step by construction.
    function rebuild(fen, replay) {
        const p = Chess.loadFen(fen) || Chess.startPosition();
        const newSans = [];
        const newKeys = [];
        const applied = [];
        for (let i = 0; i < replay.length; i++) {
            const r = replay[i];
            const m = Chess.findMove(p, r.from, r.to, r.promotion || 0);
            if (!m)
                break;          // a corrupt save stops here rather than throwing
            newSans.push(Chess.toSan(p, m));
            Chess.make(p, m);
            newKeys.push(Chess.positionKey(p));
            applied.push({
                             "from": r.from,
                             "to": r.to,
                             "promotion": m.promotion || 0
                         });
        }
        pos = p;
        sans = newSans;
        keys = newKeys;
        moveLog = applied;
        const last = applied.length > 0 ? applied[applied.length - 1] : null;
        lastFrom = last ? last.from : -1;
        lastTo = last ? last.to : -1;
        selected = -1;
        destinations = [];
        promoFrom = -1;
        promoTo = -1;
        resultRecorded = false;
        refreshOutcome();
    }

    function newGame() {
        stopEngine();
        startFen = Chess.START_FEN;
        rebuild(startFen, []);
        persist();
        maybeStartEngine();
    }

    // ── Engine ──────────────────────────────────────────────────────────
    function maybeStartEngine() {
        if (mode !== "engine" || outcome !== "" || !root.visible)
            return;
        if (pos.turn !== engineColor)
            return;
        searchState = Engine.createSearch(pos, level);
        thinking = true;
    }

    function stopEngine() {
        thinking = false;
        searchState = null;
    }

    // ── Persistence ─────────────────────────────────────────────────────
    function persist() {
        if (!GameService.storeReady)
            return;
        saveFile.setText(Model.serialize({
                                             "fen": Chess.toFen(pos),
                                             "startFen": startFen,
                                             "sans": sans,
                                             "moves": moveLog,
                                             "keys": keys,
                                             "mode": mode,
                                             "engineColor": engineColor,
                                             "level": level,
                                             "flipped": flipped,
                                             "elapsedMs": 0
                                         }));
    }

    function saveStats() {
        if (GameService.storeReady)
            statsFile.setText(Model.serializeStats(stats));
    }

    screen: targetScreen
    visible: GameService.activeGame === "chess" && targetScreen && targetScreen.name
             === GameService.targetScreenName
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: 396
    implicitHeight: card.implicitHeight
    WlrLayershell.namespace: "apollo-shell-games"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus(Qt.OtherFocusReason);
            openAnimation.restart();
            // Resume a game saved on the engine's turn. Doing it here rather
            // than on load means the move happens while you are looking.
            maybeStartEngine();
        } else {
            stopEngine();
            persist();
        }
    }

    // One bounded slice per tick. The search shares the shell's UI thread, so
    // it is never allowed to run to completion in one go.
    Timer {
        interval: 16
        repeat: true
        running: root.thinking
        onTriggered: {
            if (!root.searchState) {
                root.thinking = false;
                return;
            }
            // The unit of work is one root move, ~800 nodes a slice.
            if (Engine.step(root.searchState, 800)) {
                const best = root.searchState.best;
                root.thinking = false;
                root.searchState = null;
                if (best)
                    root.applyMove(best.from, best.to, best.promotion || 0);
            }
        }
    }

    FileView {
        id: saveFile

        path: GameService.storeReady ? GameService.saveDir + "/chess.json" : ""
        printErrors: false
        onLoaded: {
            if (root.loaded)
                return;
            root.loaded = true;
            const st = Model.parse(text());
            if (!st)
                return;
            root.mode = st.mode;
            root.engineColor = st.engineColor;
            root.level = st.level;
            root.flipped = st.flipped;
            root.startFen = st.startFen || Chess.START_FEN;
            root.rebuild(root.startFen, st.moves);
        }
        onLoadFailed: root.loaded = true
    }

    FileView {
        id: statsFile

        path: GameService.storeReady ? GameService.saveDir + "/chess-stats.json" : ""
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
            if (event.key === Qt.Key_Escape)
                GameService.close();
            else if (event.key === Qt.Key_U)
                root.undo();
            else if (event.key === Qt.Key_F)
                root.flipped = !root.flipped;
            else if (event.key === Qt.Key_N)
                root.newGame();
            else
                return;
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
                    text: "chess"
                    iconSize: Metrics.iconS
                    color: root.accent
                }

                Text {
                    text: qsTr("Chess")
                    color: root.textColor
                    font.family: Typography.titleSmall.family
                    font.pixelSize: Typography.titleSmall.pixelSize
                    font.weight: Font.Medium
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.mode === "engine" ? root.levelName(root.level) : qsTr("Two players")
                    color: root.mutedColor
                    font.family: Fonts.ui
                    font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.statusText()
                color: root.outcome !== "" ? root.successColor : Chess.inCheck(root.pos) ? root.errorColor :
                                                                                           root.supportingColor
                font.family: Fonts.ui
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }

            // ── Board ───────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: root.cellPx * 8
                implicitHeight: root.cellPx * 8

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: "transparent"
                    clip: true

                    Grid {
                        columns: 8

                        Repeater {
                            model: 64

                            delegate: Rectangle {
                                id: cell

                                required property int index
                                readonly property int sq: root.squareFor(index)
                                readonly property int piece: root.pos.board[sq]
                                readonly property bool light: ((index % 8) + Math.floor(index / 8)) % 2 === 0
                                readonly property bool isSelected: root.selected === sq
                                readonly property bool isTarget: root.destinations.indexOf(sq) !== -1
                                readonly property bool isLast: sq === root.lastFrom || sq === root.lastTo

                                width: root.cellPx
                                height: root.cellPx
                                color: isSelected ? Appearance.applyAlpha(root.accent, 0.45) : isLast
                                                    ? Appearance.mix(root.accent, light ? root.lightSquare :
                                                                                          root.darkSquare, 0.3) :
                                                      light ? root.lightSquare : root.darkSquare

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animation.expressiveFastEffects.duration
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: cell.piece !== Chess.EMPTY
                                    textFormat: Text.PlainText
                                    text: root.pieceGlyph(cell.piece)
                                    color: root.textColor
                                    font.family: "DejaVu Sans"
                                    font.pixelSize: Math.round(root.cellPx * 0.72)
                                }

                                // A dot for a quiet move, a ring for a capture.
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: cell.isTarget && cell.piece === Chess.EMPTY
                                    width: root.cellPx * 0.26
                                    height: width
                                    radius: width / 2
                                    color: Appearance.applyAlpha(root.accent, 0.7)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: cell.isTarget && cell.piece !== Chess.EMPTY
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Appearance.applyAlpha(root.errorColor, 0.75)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: root.humanToMove ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.selectSquare(cell.sq)
                                }
                            }
                        }
                    }
                }

                // Promotion picker, over the board so the choice is unmissable.
                Rectangle {
                    anchors.fill: parent
                    visible: root.promoting
                    radius: Appearance.rounding.small
                    color: Appearance.applyAlpha(Appearance.colors.colSurfaceContainerLow, 0.9)

                    Row {
                        anchors.centerIn: parent
                        spacing: Metrics.spacingS

                        Repeater {
                            model: [Chess.QUEEN, Chess.ROOK, Chess.BISHOP, Chess.KNIGHT]

                            delegate: Rectangle {
                                required property int modelData

                                width: 52
                                height: 52
                                radius: Appearance.rounding.normal
                                color: promoMouse.containsMouse ? root.hoverColor : root.surfaceColor

                                Text {
                                    anchors.centerIn: parent
                                    textFormat: Text.PlainText
                                    text: root.pieceGlyph(Chess.pieceOf(root.pos.turn, modelData))
                                    color: root.textColor
                                    font.family: "DejaVu Sans"
                                    font.pixelSize: 30
                                }

                                MouseArea {
                                    id: promoMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyMove(root.promoFrom, root.promoTo, modelData)
                                }
                            }
                        }
                    }
                }
            }

            // ── Move list ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Appearance.rounding.small
                color: root.surfaceColor
                visible: root.sans.length > 0

                ListView {
                    anchors {
                        fill: parent
                        margins: Metrics.spacingS
                    }
                    orientation: ListView.Horizontal
                    spacing: Metrics.spacingM
                    clip: true
                    model: Model.movePairs(root.sans)
                    // Follow the game rather than making you scroll for it.
                    onCountChanged: positionViewAtEnd()

                    delegate: Row {
                        required property var modelData

                        spacing: Metrics.spacingXS
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        Text {
                            text: modelData.number + "."
                            color: root.mutedColor
                            font.family: Fonts.mono
                            font.pixelSize: 12
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: modelData.white
                            color: root.textColor
                            font.family: Fonts.mono
                            font.pixelSize: 12
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: modelData.black
                            color: root.supportingColor
                            font.family: Fonts.mono
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // ── Controls ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXXS

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "restart_alt"
                    tooltipText: qsTr("New game (N)")
                    onClicked: root.newGame()
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "undo"
                    tooltipText: qsTr("Undo (U)")
                    enabled: root.moveLog.length > 0
                    onClicked: root.undo()
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: "swap_vert"
                    tooltipText: qsTr("Flip board (F)")
                    selected: root.flipped
                    onClicked: root.flipped = !root.flipped
                }

                IconButton {
                    controlSize: Metrics.controlHeightS
                    iconSize: 20
                    iconName: root.mode === "engine" ? "smart_toy" : "group"
                    tooltipText: root.mode === "engine" ? qsTr("Playing the engine; switch to two players") :
                                                          qsTr("Two players; switch to the engine")
                    selected: root.mode === "human"
                    onClicked: {
                        root.stopEngine();
                        root.mode = root.mode === "engine" ? "human" : "engine";
                        root.persist();
                        root.maybeStartEngine();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: 5

                    delegate: Rectangle {
                        id: levelChip

                        required property int index
                        readonly property int lv: index + 1

                        visible: root.mode === "engine"
                        implicitWidth: 24
                        implicitHeight: 26
                        radius: Appearance.rounding.small
                        color: root.level === lv ? Appearance.colors.colSecondaryContainer : levelMouse.containsMouse
                                                   ? root.hoverColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: levelChip.lv
                            color: root.level === levelChip.lv ? Appearance.colors.colOnSecondaryContainer :
                                                                 root.mutedColor
                            font.family: Fonts.numeric
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: levelMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.level = levelChip.lv;
                                root.persist();
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: levelMouse.containsMouse
                            text: root.levelName(levelChip.lv)
                        }
                    }
                }
            }

            // ── Record against the engine ───────────────────────────────
            Text {
                Layout.fillWidth: true
                visible: root.stats.played > 0
                textFormat: Text.PlainText
                text: qsTr("%1 won · %2 lost · %3 drawn against the engine").arg(root.stats.won).arg(
                          root.stats.lost).arg(root.stats.drawn)
                color: root.mutedColor
                font.family: Fonts.ui
                font.pixelSize: 11
            }

            // ── chess.com ratings ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: Appearance.rounding.small
                color: root.surfaceColor
                visible: GameService.ratingsEnabled && GameService.chessStats.ok
                implicitHeight: ratingsColumn.implicitHeight + Metrics.spacingS * 2

                ColumnLayout {
                    id: ratingsColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Metrics.spacingS
                    }
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            textFormat: Text.PlainText
                            text: qsTr("%1 on chess.com").arg(GameService.chessUsername)
                            color: root.supportingColor
                            font.family: Fonts.ui
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: GameService.chessStats.puzzleRating > 0
                            textFormat: Text.PlainText
                            text: qsTr("Puzzles %1").arg(GameService.chessStats.puzzleRating)
                            color: root.mutedColor
                            font.family: Fonts.ui
                            font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: Model.ratingRows(GameService.chessStats)

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true

                            Text {
                                Layout.preferredWidth: 52
                                textFormat: Text.PlainText
                                text: root.ratingLabel(modelData.kind)
                                color: root.mutedColor
                                font.family: Fonts.ui
                                font.pixelSize: 11
                            }

                            Text {
                                Layout.preferredWidth: 42
                                textFormat: Text.PlainText
                                text: modelData.rating
                                color: root.accent
                                font.family: Fonts.numeric
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                textFormat: Text.PlainText
                                text: qsTr("%1  %2%").arg(modelData.record).arg(modelData.winRate)
                                color: root.mutedColor
                                font.family: Fonts.numeric
                                font.pixelSize: 11
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Shown only when a username is set but nothing came back, so a
            // network failure is visible rather than looking like no account.
            Text {
                Layout.fillWidth: true
                visible: GameService.ratingsEnabled && GameService.ratingsTried && !GameService.chessStats.ok
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: qsTr("Could not reach chess.com for %1").arg(GameService.chessUsername)
                color: root.mutedColor
                font.family: Fonts.ui
                font.pixelSize: 11
            }
        }
    }
}
