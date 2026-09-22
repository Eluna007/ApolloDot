# CMake installation layout

Apollo Shell uses a standard CMake installation and maintains no in-application version
manager:

```text
/etc/xdg/quickshell/apollo/       QML sources, assets, scripts, matugen
/usr/lib/qt6/qml/Apollo/              Apollo native QML modules
/usr/lib/systemd/user/            Apollo's own apollo-shell.service
```

M3Shapes is an external QML runtime dependency (Arch: `qt6-m3shapes-git`), installed into
the Qt module directory by the system package. It is not part of Apollo's installation or
DESTDIR staging.

Paths are overridden through `CMAKE_INSTALL_PREFIX`, `CMAKE_INSTALL_LIBDIR`,
`APOLLO_QML_BUILD_DIR`, `APOLLO_QML_INSTALL_DIR`, `APOLLO_CONFIG_INSTALL_DIR` and
`APOLLO_SYSTEMD_USER_INSTALL_DIR`. Installation supports `DESTDIR`, and the CMake files
never call sudo. `apollo-clipboard.service` does not belong to this repository; the key-cli
wheel installs it into the same standard systemd user-unit directory.

Quickshell chooses the user XDG configuration directory itself: `~/.config/quickshell/apollo`
takes precedence when it exists, otherwise it falls back to `/etc/xdg/quickshell/apollo`.
The development import tree lives in `build/qml` and is not copied into the system Qt import
root.

The built-in Matugen registry and templates continue to be installed by
`core/CMakeLists.txt` into `${APOLLO_CONFIG_INSTALL_DIR}/matugen/`. QML locates resources
through `Paths.builtinMatugenDir` (`Quickshell.shellDir + "/matugen"`), and scripts locate
them from their own `scripts/lib/` position relative to the shell root, so the source tree
and a system installation share the same relative layout and nothing depends on the old
`defaults/` path. The user registry is the separate `$APOLLO_CONFIG_HOME/matugen/`;
installation never creates or writes into any user HOME, and never copies built-in templates
as user defaults. New scripts and jq parsing files are picked up automatically by the
existing scripts directory installation rules, requiring no new native plugin or Python
runtime.

Arch packaging uses the `/usr` prefix and the `/etc/xdg/quickshell/apollo` configuration
destination explicitly.
The weather SVG and Lottie assets come from the complete release source with fixed
checksums; nothing depends on ignored assets present on a development machine.
Release, CI, development check and installer tooling are not installed into the shell's
runtime scripts directory.
