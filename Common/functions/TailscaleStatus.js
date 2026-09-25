.pragma library

// Pure parsing for `tailscale status --json` and `tailscale debug prefs`.
// Every field is checked for type, so a changed or truncated document yields
// empty values rather than exceptions in the UI.

function _str(value, max) {
    if (typeof value !== "string")
        return "";
    const limit = max || 256;
    const text = value.replace(/[\u0000-\u001f\u007f]/g, "").trim();
    return text.length > limit ? text.slice(0, limit) : text;
}

function _ips(value) {
    return Array.isArray(value) ? value.map(ip => _str(ip, 64)).filter(ip => ip.length > 0) : [];
}

// MagicDNS names come back fully qualified with a trailing dot.
function _dnsName(value) {
    return _str(value).replace(/\.$/, "");
}

function _node(raw) {
    const node = raw || {};
    const ips = _ips(node.TailscaleIPs);
    return {
        "id": _str(node.ID, 64),
        "publicKey": _str(node.PublicKey, 128),
        "hostName": _str(node.HostName, 128),
        "dnsName": _dnsName(node.DNSName),
        "os": _str(node.OS, 32),
        "ips": ips,
        "ipv4": ips.find(ip => ip.indexOf(":") === -1) || "",
        "online": node.Online === true,
        "active": node.Active === true,
        "exitNode": node.ExitNode === true,
        "exitNodeOption": node.ExitNodeOption === true,
        "lastSeen": _str(node.LastSeen, 64)
    };
}

// The short name: the first MagicDNS label, falling back to the host name.
function displayName(node) {
    if (!node)
        return "";
    const label = node.dnsName ? node.dnsName.split(".")[0] : "";
    return label || node.hostName || node.ipv4;
}

function emptyStatus() {
    return {
        "ok": false,
        "backendState": "",
        "authUrl": "",
        "tailnetName": "",
        "magicDnsSuffix": "",
        "self": _node(null),
        "peers": [],
        "health": []
    };
}

function parseStatus(text) {
    let raw;
    try {
        raw = JSON.parse(text);
    } catch (error) {
        return emptyStatus();
    }
    if (!raw || typeof raw !== "object")
        return emptyStatus();

    const tailnet = raw.CurrentTailnet || {};
    const peers = [];
    const peerMap = raw.Peer && typeof raw.Peer === "object" ? raw.Peer : {};
    for (const key in peerMap)
        peers.push(_node(peerMap[key]));
    // Online first, then by name, so the list does not reshuffle between polls.
    peers.sort((a, b) => {
        if (a.online !== b.online)
            return a.online ? -1 : 1;
        return displayName(a).localeCompare(displayName(b));
    });

    return {
        "ok": true,
        "backendState": _str(raw.BackendState, 32),
        "authUrl": /^https:\/\//.test(_str(raw.AuthURL)) ? _str(raw.AuthURL) : "",
        "tailnetName": _str(tailnet.Name, 128),
        "magicDnsSuffix": _str(tailnet.MagicDNSSuffix || raw.MagicDNSSuffix, 128),
        "self": _node(raw.Self),
        "peers": peers,
        "health": Array.isArray(raw.Health) ? raw.Health.map(item => _str(item, 512)).filter(item => item) : []
    };
}

function emptyPrefs() {
    return {
        "ok": false,
        "wantRunning": false,
        "shieldsUp": false,
        "acceptDns": false,
        "acceptRoutes": false,
        "exitNodeId": "",
        "exitNodeIp": "",
        "exitNodeAllowLan": false,
        "operatorUser": ""
    };
}

function parsePrefs(text) {
    let raw;
    try {
        raw = JSON.parse(text);
    } catch (error) {
        return emptyPrefs();
    }
    if (!raw || typeof raw !== "object")
        return emptyPrefs();

    return {
        "ok": true,
        "wantRunning": raw.WantRunning === true,
        "shieldsUp": raw.ShieldsUp === true,
        "acceptDns": raw.CorpDNS === true,
        "acceptRoutes": raw.RouteAll === true,
        "exitNodeId": _str(raw.ExitNodeID, 64),
        "exitNodeIp": _str(raw.ExitNodeIP, 64),
        "exitNodeAllowLan": raw.ExitNodeAllowLANAccess === true,
        "operatorUser": _str(raw.OperatorUser, 64)
    };
}

// True when a failed command's stderr means the daemon refused the caller,
// i.e. this user is not the operator.
function isPermissionError(text) {
    return /access denied|permission denied|operator|must be root|checkprefs/i.test(String(text || ""));
}
