# Development workflow

Install the external QML runtime dependency M3Shapes first (Arch: `qt6-m3shapes-git`).
Apollo neither compiles nor installs it; `build/qml` continues to provide a development
import path for Apollo's native modules only.
When migrating from an older checkout, delete `build/qml/M3Shapes` from the old build
directory so it cannot shadow the system module. Do not copy the system module into that
directory or create a symlink of the same name.

Source development relies on Quickshell's XDG configuration precedence and the import tree
CMake generates:

```bash
mkdir -p ~/.config/quickshell
ln -sfn ~/Projects/ApolloDot ~/.config/quickshell/apollo

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build

MALLOC_CONF="${MALLOC_CONF-thp:never,narenas:4,dirty_decay_ms:3000}" \
QML_IMPORT_PATH="$PWD/build/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" key shell
```

The source directory takes precedence over `/etc/xdg/quickshell/apollo`. QML hot-reloads
on save; C++ plugins require a rebuild and a shell reload. Shell and CLI logging is each
tool's own responsibility — do not use `nohup` or `disown`, or discard output to
`/dev/null`, in documentation or scripts.

`apollo-shell.service` sets jemalloc's memory policy before start: transparent huge pages
disabled, automatic arenas capped at 4, and dirty-page decay set to 3 seconds. Pass
`MALLOC_CONF` the same way when running `key shell` or `qs -c apollo` directly; the form
above preserves an explicitly set value, including an empty one. Quickshell builds that do
not use jemalloc ignore it, and no allocator preload is needed.
The variable cannot go in `shell.qml`'s Env pragma — the allocator is already initialized
by the time QML is parsed. Changing the policy requires restarting the process; hot reload
does not apply. A custom policy for the service can be set with
`Environment="MALLOC_CONF=..."` in a user drop-in.

Formal installation is the distribution packaging process's responsibility. By default this
repository only builds and tests the source, and does not create runtime version snapshots.

Keyboard lock state comes from the separate key-cli: `key keyboard status --format json`
for diagnostics, and `key keyboard watch --format jsonl` managed by a single Process in
`KeyboardLockService`.
Startup, device recovery and resynchronization snapshots do not raise an OSD; only a real
toggle does. There is no periodic polling and no silent timeout.
It stays unavailable when permissions are insufficient, leaving the user to opt into
key-cli's separate optional keyboard authorization; an already-installed authorization
package can be kept.
`Apollo.Keyboard` retains only the shortcut recording that depends on Qt input events.
libudev is still used by the backlight backend.
The clipboard watcher remains managed by its own systemd user service and does not stop
when the keyboard process exits.

The brightness service uses `Niri.currentOutput` directly and no longer starts a
focused-output query process. For internal backlights, `BacklightState` subscribes to
backlight udev events and reads `actual_brightness` / `max_brightness`, selecting the
device by sorted name, and `brightnessctl` writes explicitly to that same device. It reads
back at startup, on device events, and when its own write completes — there is no periodic
polling. If a driver does not emit events for external hardware brightness changes, those
changes will not sync automatically and must be verified manually on the hardware
concerned. DDC detection, reads and write throttling keep their existing behavior.

The keyboard state service distinguishes `connecting` (no trusted snapshot yet), `ready`
(state is trustworthy), `reconnecting` (bounded reconnection after the process exits) and
`unavailable` (explicitly unavailable, or reconnection exhausted).
`available` is true only in `ready`; an unknown `capsLock` / `numLock` is null.
`supported` becomes true after a trusted snapshot and is retained only across process
reconnection; an explicit unavailable response, a protocol error, or exhausted reconnection
clears it. Trusted state is never inferred from whether the authorization package is
installed, and is not persisted.
The Settings Center keyboard indicators section, the keyboard state UI on both lock
screens, and the keyboard OSD all use `available` to control presentation, hiding during
temporary reconnection too. Hiding does not reset OSD preferences, and a recovered snapshot
only updates the baseline.
For source installs, authorization is opted into separately through key-cli's
`scripts/install.sh --keyboard enable --acknowledge-keyboard-access`. An existing
`key-cli-keyboard-access` package can be kept; Apollo does not install authorization rules.

## Integration work against key-cli source

Run once in the key-cli checkout:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
./scripts/install.sh --dev-services enable --apollo-unit ~/Projects/ApolloDot/packaging/systemd/user/apollo-shell.service
```

When Apollo's base unit is not installed, follow the tool's output and link this
repository's existing unit with `systemctl --user link`; key-cli only generates a
development ExecStart drop-in and does not take over installation of the shell service.
Then run `systemctl --user daemon-reload` and restart the selected services as needed.
If the clipboard base unit is missing, key-cli supplies its own; it still runs
independently of the shell.

In fish you may run `fish_add_path --universal --move ~/Projects/key-cli/.venv/bin`, which
also affects python/pip. The services do not rely on the fish PATH — they use the generated
absolute `.venv/bin/key` path.
`key shell` propagates its own entry point to `APOLLO_KEY`, and clipboard callbacks use the
same `key` that started it.
Ordinary Python edits take effect for new processes immediately; restart existing watchers
as needed, and reinstall the editable environment only when installation metadata changes.
Do not re-run makepkg or install system packages to test ordinary source changes.

To undo, run `./scripts/install.sh --dev-services disable` in key-cli, then reload the user
units; custom drop-ins are preserved. Check the development PATH and switch back to
`/usr/local/bin/key` or the distribution entry point as needed. A stable source
installation is provided by key-cli's `scripts/install.sh` and does not depend on the
checkout continuing to exist; Apollo's native build, QML installation and session
management remain this repository's responsibility.
