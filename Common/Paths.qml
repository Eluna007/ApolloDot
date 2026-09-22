pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string shellDir: Quickshell.shellDir
    // Quickshell chooses the user XDG shell directory before the system XDG
    // directory. Both installed and source shells therefore use the same
    // relative resource paths.
    readonly property string shareRoot: shellDir
    readonly property string builtinMatugenDir: shareRoot + "/matugen"
    readonly property string userMatugenDir: configHome + "/matugen"
    readonly property string assetsDir: shareRoot + "/assets"
    readonly property string fontsDir: assetsDir + "/fonts"
    readonly property string iconsDir: assetsDir + "/icons"
    readonly property string appIconsDir: iconsDir + "/apps"
    readonly property string weatherIconsDir: iconsDir + "/weather"
    readonly property string rcloneIconsDir: iconsDir + "/rclone"
    readonly property string meteoconsDir: weatherIconsDir + "/meteocons"
    readonly property string imagesDir: assetsDir + "/images"
    readonly property string scriptsDir: shareRoot + "/scripts"
    readonly property string audioScriptsDir: scriptsDir + "/audio"
    readonly property string captureScriptsDir: scriptsDir + "/capture"
    readonly property string mediaScriptsDir: scriptsDir + "/media"
    readonly property string systemScriptsDir: scriptsDir + "/system"
    readonly property string themeScriptsDir: scriptsDir + "/theme"
    readonly property string weatherScriptsDir: scriptsDir + "/weather"
    readonly property string homeDir: root.absoluteEnvironment("HOME")
    readonly property string xdgConfigHome: root.absoluteEnvironment("XDG_CONFIG_HOME") || homeDir + "/.config"
    readonly property string xdgDataHome: root.absoluteEnvironment("XDG_DATA_HOME") || homeDir + "/.local/share"
    readonly property string binHome: root.absoluteEnvironment("APOLLO_BIN_HOME") || homeDir + "/.local/bin"
    readonly property string stableKey: root.absoluteEnvironment("APOLLO_KEY") || "key"
    readonly property string configHome: root.absoluteEnvironment("APOLLO_CONFIG_HOME") || xdgConfigHome + "/apollo"
    readonly property string dataHome: root.absoluteEnvironment("APOLLO_DATA_HOME") || xdgDataHome + "/apollo"
    readonly property string stateHome: root.absoluteEnvironment("APOLLO_STATE_HOME") || (root.absoluteEnvironment("XDG_STATE_HOME") || homeDir + "/.local/state") + "/apollo"
    readonly property string cacheHome: root.absoluteEnvironment("APOLLO_CACHE_HOME") || (root.absoluteEnvironment("XDG_CACHE_HOME") || homeDir + "/.cache") + "/apollo"
    readonly property string runtimeHome: root.absoluteEnvironment("APOLLO_RUNTIME_HOME") || (root.absoluteEnvironment("XDG_RUNTIME_DIR") || cacheHome + "/runtime") + "/apollo"
    readonly property string requestedProfileName: Quickshell.env("APOLLO_PROFILE") || "default"
    readonly property string profileName: root.validProfileName(requestedProfileName) ? requestedProfileName.trim() : "default"
    readonly property string profileConfigHome: root.absoluteEnvironment("APOLLO_PROFILE_CONFIG_HOME") || configHome + "/profiles/" + profileName
    readonly property string profileHome: root.absoluteEnvironment("APOLLO_PROFILE_HOME") || dataHome + "/profiles/" + profileName
    readonly property string generatedHome: root.absoluteEnvironment("APOLLO_GENERATED_HOME") || profileHome + "/generated"
    readonly property string currentWallpaper: stateHome + "/wallpaper/current"
    readonly property string profileAvatar: homeDir + "/.face"
    readonly property string defaultAvatar: imagesDir + "/dino.png"

    function absoluteEnvironment(name) {
        const value = String(Quickshell.env(name) || "").trim();
        return value.startsWith("/") ? value : "";
    }

    function validProfileName(value) {
        const name = String(value || "").trim();
        return name !== "" && name !== "." && name !== ".." && name.indexOf("/") < 0 && name.indexOf("\\") < 0;
    }

    function fileUrl(path) {
        const value = String(path);
        return value.startsWith("file://") ? value : "file://" + value;
    }

    function icon(name) {
        return fileUrl(iconsDir + "/" + name);
    }

    function appIcon(name) {
        return fileUrl(appIconsDir + "/" + name);
    }

    function scriptPath(group, name) {
        return scriptsDir + "/" + group + "/" + name;
    }

    function meteoconSvg(style, slug) {
        return fileUrl(meteoconsDir + "/svg/" + style + "/" + slug + ".svg");
    }

    function meteoconLottie(slug) {
        return fileUrl(meteoconsDir + "/lottie/fill/" + slug + ".json");
    }

}
