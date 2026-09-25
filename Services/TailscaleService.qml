pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/functions/TailscaleStatus.js" as TailscaleStatus

// Tailscale state and actions, through the `tailscale` CLI.
//
// Changing settings needs tailscaled to accept this user. Rather than prompt
// for a password on every action, Apollo relies on Tailscale's operator mode:
// `tailscale set --operator=$USER`, granted once through polkit with
// grantOperator(). After that, up/down/set run as the user with no prompt.
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER") || ""

    // Consumers that want fresh data (the details page) take a lease; the tile
    // alone only needs the slow poll.
    property var watchers: ({})
    readonly property bool watched: Object.keys(root.watchers).length > 0

    property bool available: false
    property bool probed: false
    property var status: TailscaleStatus.emptyStatus()
    property var prefs: TailscaleStatus.emptyPrefs()

    readonly property string backendState: root.status.backendState
    readonly property bool connected: root.backendState === "Running"
    readonly property bool needsLogin: root.backendState === "NeedsLogin" || root.backendState
                                       === "NeedsMachineAuth"
    readonly property var self: root.status.self
    readonly property var peers: root.status.peers
    readonly property var exitNodeOptions: root.peers.filter(peer => peer.exitNodeOption)
    readonly property var currentExitNode: root.peers.find(peer => peer.exitNode) || null
    readonly property int onlinePeerCount: root.peers.filter(peer => peer.online).length

    // Unknown until prefs have been read once; only then is "not operator" a
    // real answer rather than a guess.
    readonly property bool isOperator: root.prefs.ok && root.userName !== "" && root.prefs.operatorUser
                                       === root.userName
    readonly property bool needsOperator: root.available && root.prefs.ok && !root.isOperator
                                          || root.permissionDenied

    property bool permissionDenied: false
    property bool busy: false
    property string lastError: ""

    property bool openAuthUrlWhenReady: false
    readonly property bool loggingIn: loginProcess.running

    property var queue: []
    property var currentAction: null

    signal copied(string value)

    function watch(owner) {
        const next = Object.assign({}, root.watchers);
        next[owner] = true;
        root.watchers = next;
        root.refresh();
    }

    function unwatch(owner) {
        const next = Object.assign({}, root.watchers);
        delete next[owner];
        root.watchers = next;
    }

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
        if (!prefsProcess.running)
            prefsProcess.running = true;
    }

    function displayName(node) {
        return TailscaleStatus.displayName(node);
    }

    // Queue a CLI call. Actions run one at a time so a toggle landing during
    // an exit-node change cannot race it.
    function run(kind, args) {
        if (!root.available)
            return false;
        root.queue = root.queue.concat([{
                                            "kind": kind,
                                            "command": args
                                        }]);
        root.pump();
        return true;
    }

    function pump() {
        if (actionProcess.running || root.queue.length === 0)
            return;
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        root.currentAction = next;
        root.busy = true;
        actionProcess.command = next.command;
        actionProcess.running = true;
    }

    function setConnected(value) {
        return root.run(value ? "up" : "down", ["tailscale", value ? "up" : "down"]);
    }

    function toggle() {
        if (root.needsLogin)
            return root.login();
        return root.setConnected(!root.connected);
    }

    // `tailscale up` blocks until the browser login finishes, so it runs
    // beside the action queue rather than in it. The login URL shows up in the
    // status JSON and is opened as soon as it does.
    function login() {
        if (root.status.authUrl !== "") {
            Qt.openUrlExternally(root.status.authUrl);
            return true;
        }
        if (!root.available || loginProcess.running)
            return false;
        root.openAuthUrlWhenReady = true;
        loginProcess.running = true;
        return true;
    }

    // An empty value clears the exit node. Peers are addressed by their
    // Tailscale IP, which `set --exit-node` accepts on every supported version.
    function setExitNode(ip) {
        return root.run("exit-node", ["tailscale", "set", "--exit-node=" + String(ip || "")]);
    }

    function setExitNodeAllowLan(value) {
        return root.run("exit-node-lan", ["tailscale", "set", "--exit-node-allow-lan-access=" + (value ? "true" :
                                                                                                          "false")]);
    }

    function setShieldsUp(value) {
        return root.run("shields-up", ["tailscale", "set", "--shields-up=" + (value ? "true" : "false")]);
    }

    function setAcceptDns(value) {
        return root.run("accept-dns", ["tailscale", "set", "--accept-dns=" + (value ? "true" : "false")]);
    }

    function setAcceptRoutes(value) {
        return root.run("accept-routes", ["tailscale", "set", "--accept-routes=" + (value ? "true" : "false")]);
    }

    // The one privileged call: polkit asks for a password once, and from then
    // on tailscaled accepts this user's changes directly.
    function grantOperator() {
        if (root.userName === "")
            return false;
        return root.run("operator", ["pkexec", "tailscale", "set", "--operator=" + root.userName]);
    }

    function copy(value) {
        const text = String(value || "");
        if (text === "" || copyProcess.running)
            return false;
        copyProcess.command = ["wl-copy", "--", text];
        copyProcess.running = true;
        root.copied(text);
        return true;
    }

    function actionFailed(kind, stderrText) {
        const detail = String(stderrText || "").trim().split("\n").filter(line => line.trim() !== "").slice(-1)[0]
            || "";
        if (kind === "operator") {
            root.lastError = qsTr("Tailscale access was not granted");
            return;
        }
        if (TailscaleStatus.isPermissionError(stderrText)) {
            root.permissionDenied = true;
            root.lastError = qsTr("Tailscale refused the change. Grant this account operator access first.");
            return;
        }
        root.lastError = detail !== "" ? qsTr("Tailscale: %1").arg(detail) : qsTr("The Tailscale command failed");
    }

    Timer {
        interval: root.watched ? 3000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProcess

        property bool started: false

        command: ["tailscale", "status", "--json"]
        onStarted: started = true
        onRunningChanged: {
            if (running)
                return;
            // Never started: the binary is missing.
            if (!started) {
                root.available = false;
                root.probed = true;
                root.status = TailscaleStatus.emptyStatus();
            }
            started = false;
        }
        onExited: exitCode => {
            root.probed = true;
            // `status --json` still prints a document when the daemon is
            // stopped; an unreachable daemon prints nothing parseable.
            const parsed = TailscaleStatus.parseStatus(statusOutput.text);
            root.available = true;
            root.status = parsed;
            if (root.openAuthUrlWhenReady && parsed.authUrl !== "") {
                root.openAuthUrlWhenReady = false;
                Qt.openUrlExternally(parsed.authUrl);
            }
        }

        stdout: StdioCollector {
            id: statusOutput
        }

        stderr: StdioCollector {}
    }

    Process {
        id: prefsProcess

        command: ["tailscale", "debug", "prefs"]
        onExited: exitCode => {
            const parsed = exitCode === 0 ? TailscaleStatus.parsePrefs(prefsOutput.text) :
                                            TailscaleStatus.emptyPrefs();
            if (parsed.ok) {
                root.prefs = parsed;
                if (root.isOperator)
                    root.permissionDenied = false;
            }
        }

        stdout: StdioCollector {
            id: prefsOutput
        }

        stderr: StdioCollector {}
    }

    Process {
        id: actionProcess

        property bool started: false

        onStarted: started = true
        onRunningChanged: {
            if (running)
                return;
            if (!started) {
                const kind = root.currentAction ? root.currentAction.kind : "";
                root.lastError = kind === "operator" ? qsTr("pkexec is not installed; run: sudo tailscale set --operator=%1").arg(root.userName) :
                                                       qsTr("The Tailscale command could not be started");
                root.currentAction = null;
                root.busy = root.queue.length > 0;
                Qt.callLater(root.pump);
            }
            started = false;
        }
        onExited: exitCode => {
            const kind = root.currentAction ? root.currentAction.kind : "";
            root.currentAction = null;
            if (exitCode === 0) {
                root.lastError = "";
                if (kind === "operator")
                    root.permissionDenied = false;
            } else {
                root.actionFailed(kind, actionError.text);
            }
            root.busy = root.queue.length > 0;
            root.refresh();
            Qt.callLater(root.pump);
        }

        stdout: StdioCollector {}

        stderr: StdioCollector {
            id: actionError
        }
    }

    Process {
        id: loginProcess

        command: ["tailscale", "up"]
        onExited: exitCode => {
            root.openAuthUrlWhenReady = false;
            if (exitCode !== 0)
                root.actionFailed("login", loginError.text);
            root.refresh();
        }

        stderr: StdioCollector {
            id: loginError
        }
    }

    Process {
        id: copyProcess
    }
}
