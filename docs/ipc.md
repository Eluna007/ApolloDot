# IPC

`key-cli` can be used for the shell lifecycle; new shortcuts call Quickshell IPC directly:

```bash
key shell
qs -c apollo ipc show
qs -c apollo ipc call TARGET METHOD [ARGUMENTS...]
```

The corresponding Quickshell invocations are:

```text
key shell                 → qs -c apollo -n
key shell --daemon        → qs -c apollo -n -d
key shell --kill          → qs -c apollo kill
key shell --log           → qs -c apollo log
key ipc show              → qs -c apollo ipc show
key ipc call A B ...      → qs -c apollo ipc call A B ...
```

Niri shortcuts and scripts must not write a bare `quickshell ipc`, nor a user source path.
Places inside the shell that use the Quickshell API directly need not mechanically go
through the CLI.

Managed shortcuts are written as separate argv entries, without a shell string or a
per-keypress configuration helper:

```kdl
spawn "qs" "-c" "apollo" "ipc" "call" "keystone" "hub"
```

A standard existing binding using `key ipc call` is recognized as the same Apollo action,
but its original text is preserved.
Screen recording, audio recording and the clipboard continue to use their own `key`
interfaces.
The action catalog is maintained against the actual IpcHandler registrations; methods that
take parameters keep an explicit parameter template.
The first time "Set up" is clicked on the shortcuts page and a missing binds.kdl is created,
the default bindings below are written.
All of them use `spawn "qs" "-c" "apollo" "ipc" "call" ...` with `repeat=false`.
`Mod` follows Niri's primary modifier, usually Super.

| Shortcut | Function | IPC target / method / arguments |
| --- | --- | --- |
| Mod+Space | Spotlight search | spotlight toggle |
| Mod+Slash | Shortcut map | shortcut-map toggle |
| Mod+Shift+Space | Web search | spotlight web |
| Mod+Alt+V | Clipboard history | spotlight openMode clipboard |
| Mod+Alt+W | Wallpaper picker | spotlight openMode wallpapers |
| Mod+N | Notifications and dashboard sidebar | sidebar toggle dashboard |
| Mod+A | Quick settings sidebar | sidebar toggle quicksettings |
| Mod+Ctrl+Comma | Settings Center | control-center toggle general |
| Mod+Shift+W | Keystone hub | keystone hub |
| Mod+Shift+T | Tools panel | keystone tools |
| Alt+Shift+L | Lock screen | lock open |

These keys avoid Niri's common window, workspace, screenshot and media controls. Before
first set-up, physical key occupancy is checked across the effective include chain
(including Mod/Super aliases); a conflict refuses the write and lists the key names. The
user can free those keys, or create a custom binds.kdl and then set up. Any third-party
configuration may occupy the default keys, so freedom from conflicts cannot be guaranteed
for every configuration. An existing file is not populated even when empty, and upgrades do
not restore bindings the user has deleted or changed.
Installation deploys only the program; it never rewrites the user's Niri configuration
automatically.

The catalog is maintained against [niri key bindings](https://niri-wm.github.io/niri/Configuration:-Key-Bindings.html),
the [default configuration](https://github.com/niri-wm/niri/blob/main/resources/default-config.kdl),
the [bindable action definitions](https://github.com/niri-wm/niri/blob/main/niri-config/src/binds.rs) and
the [Quickshell IpcHandler](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler/).
Managed fragments handle overrides according to [niri include order](https://niri-wm.github.io/niri/Configuration:-Include.html).
The catalog is deployed with the program; at runtime it only verifies action support
locally and never downloads anything.

The shortcut map loads independently of the Settings Center and is opened or closed with
`qs -c apollo ipc call shortcut-map toggle`; parameterless `open` and `close` are also
provided. The account page button and IPC share the same popup layer.

The sidebar IPC parameters distinguish content: `dashboard` means the information, drawer
and weather sidebar, and `quicksettings` means the quick settings sidebar. General settings
→ Sidebar lets each one's screen position be chosen independently, still defaulting to the
information sidebar on the left and quick settings on the right.
Different sides can be open simultaneously. On the same side, clicking the other group's
button automatically retracts the current sidebar and expands the new one once it has
exited, with no need to close it manually. Rapid switching follows the last request;
clicking again on a sidebar that is waiting to expand cancels the expansion, and Esc closes
everything.
Moving two already-open groups to the same side keeps the most recently opened one.
`open`, `close` and `toggle` all accept the parameters above and return
`DASHBOARD_OPEN/CLOSED` or `QUICKSETTINGS_OPEN/CLOSED`. The legacy parameters `left` and
`right` continue to refer to the information and quick settings content respectively, and
keep returning `LEFT_OPEN/CLOSED` and `RIGHT_OPEN/CLOSED`; they are not reinterpreted
according to actual position.
Existing user bindings need no rewriting, and the shortcuts page recognizes the legacy
parameters as the corresponding content actions.

The dynamic island lyrics view is expanded and collapsed with
`qs -c apollo ipc call keystone lyrics`, returning `LYRICS_OPENED` / `LYRICS_CLOSED`. Both
styles act on the current output (falling back to the first screen when none matches), and
expanding collapses the other dynamic island panels. The shortcut settings provide a
placeholder for the lyrics action but bind no default shortcut.

### Spotlight Files

`qs -c apollo ipc call spotlight openMode files` and
`qs -c apollo ipc call spotlight files` open Files and focus its input. Repeated
calls keep it open. Existing Apps/Wallpapers/Clipboard and web methods remain.

Ctrl+1/2/3/4 selects Apps/Wallpapers/Clipboard/Files. Tab expands the four-mode rail; subsequent Tab/Shift+Tab cycle it, and Enter selects a mode. In Files, Enter opens the selected file or enters
the folder; Ctrl+Enter requests selection in a file manager. Holding Ctrl immediately shows
the selected result's containing path; the right-click menu also exposes Open
and Show in file manager. Clipboard retains Shift+Enter.

Search uses the public `key file` capability through `${APOLLO_KEY:-key}`. Install
fd plus key-cli supporting `file.status`/`file.search`; there is no invented
minimum release version. HOME is the default root, with fd's normal ignore/hidden
rules and no directory-symlink traversal. Queries are literal and case-insensitive;
slash-containing queries match paths. A 180 ms debounce feeds at most 50 results
from 400 candidates with a 3-second search budget. Limited searches are identified
in the UI. Empty input does not enumerate HOME.

Open uses the system default association and blocks launching executable content.
Reveal first requests FileManager1 selection, then falls back to opening the
parent directory without promising selection. Failures keep Spotlight open.

Settings → keyboard shortcuts includes **Spotlight: Find files** as an unbound
action. Bind/save it using the existing editor if desired; no default global
shortcut is added and existing user bindings are preserved.

### Spotlight Search (default)

`spotlight open`, the opening branch of `spotlight toggle`, `spotlight search`,
and `spotlight openMode search` enter Search. `open` and `search` are idempotent:
when Search is visible they focus it. A new session starts with an empty input
and no results panel. To open the application Grid/List directly, use
`qs -c apollo ipc call spotlight openMode apps`.

Ctrl+0 or the search icon returns to Search and preserves ordinary search text. Tool parameters and command drafts are cleared.
Ctrl+1/2/3/4 still opens Apps/Wallpapers/Clipboard/Files; Tab expands and cycles
the same four satellite buttons. Ctrl+K enters Web, and Esc from Web restores the previous
mode, including Search. The existing modal/rail/clear-input/close Esc priority and
IME composition handling remain. No new global key is installed.

Nonempty input searches the already loaded Apps directory, static Settings and
Actions catalogs, and `WallpaperService.wallpapers`, in that order. Groups display
with one responsive row of app icons/names and wallpaper thumbnails/names, and
up to two Settings/Actions entries each, with no category expansion. Up/Down moves between rows; Left/Right moves within
a tile row. There is no separate input/result navigation state; Esc follows the
shared modal/rail/clear-input/close behavior.
The last two rows
are explicit **Search files for…** and **Search the web for…** actions. Files is
queried only after entering its dedicated mode; Web opens only after activation.
Clipboard content, live web results and file results are not aggregated.

Search does not refresh or scan wallpaper folders. Files added externally become
visible after the existing startup, directory-change or dedicated wallpaper-page
refresh. There is no file index service or “enable indexing” setting.

Settings results release Spotlight before opening/focusing the existing Settings
window. Stable page/subpage IDs and section anchors support scroll and brief
highlight after loading and layout. Later requests replace earlier ones; leaving
the page or closing the window cancels pending navigation. A missing or hidden
section reports that it is unavailable.

Actions reuse fixed Apollo shortcuts and business functions. Power opens the
existing confirmation menu. Parameter templates, raw compositor commands,
queries, duplicate navigation aliases and the reserved no-op `cancelRecord` are
not exposed as executable Search results. No shell expression is evaluated.
See [search catalog maintenance](architecture/spotlight-search.md).

### Spotlight commands and temporary tools

`spotlight commands` and `spotlight openMode commands` are idempotent public
entries. Explicit IPC mode navigation clears temporary tools/overrides through
the same session controller as local navigation; it does not change user keys.

All 16 command-palette actions are also callable as
`qs -c apollo ipc call spotlight command NAME`, using the slash name without `/`
(e.g. `calc`, `fx`, `time`, `light`, `dark`, `find-settings`, `actions`, `map`).
This returns `OK` or `INVALID_COMMAND`; scoped layout/order overrides are rejected.
Tools open a fresh session; theme, Settings and map actions also work while
Spotlight is closed. Existing dedicated IPC entry points remain compatible.
Every palette action has a permanent row in Settings → Shortcuts, reusing existing
rows where available. The new rows start unassigned and add no default bindings.

Type `>` to enter the command palette immediately (`>calc` filters Calculator).
Slash drafts stay in their base mode. Enter executes an exact command; slash input has no suggestion list. Unknown commands
never fall through to content activation. `\/etc` and `\>hello` are literal
searches. Tool parameters are not reparsed as top-level commands.

| Command | Behavior |
| --- | --- |
| `/default`, `/apps`, `/wallpaper` (`/wallpapers`), `/clipboard`, `/files`, `/commands` | Base mode navigation |
| `/search` (`/web`) | Web tool, not default Search |
| `/calc`, `/fx` (`/currency`), `/time` (`/tz`) | Calculator, currency, time zone |
| `/find-settings`, `/actions` | Settings-only / IPC action-only search |
| `/light`, `/dark`, `/settings`, `/map` | Apply theme, open Settings, open standalone location map |
| `/list`, `/grid`, `/smart`, `/most-used`, `/recent` (`/recently-used`), `/name` | Apps-only temporary presentation |
| `/compact`, `/detail` (`/details`) | Clipboard-only temporary presentation |

Tool commands accept trailing input, e.g. `/calc (120 + 80) * 0.85` or
`/fx 100 USD to CNY`. The first Enter only enters the tool. A later Enter copies
its valid result (Web submits); it does not close calculation tools.

Empty-input Backspace removes the current tool, then the most recent presentation
override. It requires a fresh press in the search input, no selection/preedit or
modal dialog. Holding Backspace cannot unwind the stack. Theme changes
and other completed actions are never undone. Closing clears temporary state.

Tab and Shift+Tab always navigate the mode rail; they never complete input.
Ctrl editing shortcuts and Files Ctrl+Enter retain their previous behavior.

Currency opens with four independent slots: amount, currency, amount, currency,
separated by ≈. Left/Right select adjacent slots without wrapping. Clicking a
slot activates it; typing replaces the selected value. The last edited amount
is the driver; currency changes preserve that side. `/fx 100 USD to CNY` seeds
the slots, while `/fx` defaults to 1 USD → EUR.

Only active currency slots show locally filtered candidates. Up/Down select and
Enter confirms without copying. Tab/Shift+Tab retain mode-rail navigation.
Ctrl+C copies the current slot (an explicit text selection takes priority).
Ctrl+A highlights the whole four-slot expression; Ctrl+C then copies that expression.
With candidates closed, Enter copies the derived amount without its currency.
A fresh Backspace in an empty amount slot leaves Currency.

Only the confirmed pair requests `key tool currency --expression="1 USD to EUR"`.
Amount edits and direction changes reuse that rate locally, using decimal-string
arithmetic. Reverse conversion rounds half-even to 24 decimal places. Pending or
invalid dependent amounts cannot be copied. Existing generation checks reject
old pair results, and current driver state determines which amount is derived.

Time opens a searchable list of templates from local time to every available
time zone. “Change source” chooses a different source zone. Select a template
with Enter, then type a time (`0930`, `9`, `09:30`, or a date and time). Clearing
the input and pressing Backspace again returns to template selection. Another
fresh Backspace on the empty selector leaves the tool. DST ambiguity and invalid
times still use the existing explicit result/error flow.

### Sidebar weather and drawer

`qs -c apollo ipc call sidebar open weather` and `sidebar open drawer` select the
respective dashboard tab and open its sidebar, following the configured edge.
Open/close remain explicit IPC operations. Spotlight Actions and permanent
unassigned shortcut rows instead use `sidebar toggle weather` / `sidebar toggle drawer`.
Toggling the already open target tab closes it; a closed sidebar or a different
active tab opens the requested tab. No default key is installed.

## Games

The Apolloku (sudoku) and Chess windows open centred on the focused output. Opening one
closes the other, and `Esc` closes whichever is open:

```bash
qs -c apollo ipc call games toggle apolloku
qs -c apollo ipc call games toggle chess
qs -c apollo ipc call games open chess
qs -c apollo ipc call games close
```

Both games also have a button in the bar's tray pill, which opens the game on that bar's
output.
`open` and `toggle` return `OPEN`, `CLOSED`, `UNAVAILABLE` or `INVALID_GAME`; `close`
returns `CLOSED` or `NOT_OPEN`. No default shortcut is bound. A niri binding:

```kdl
Mod+Shift+S { spawn "qs" "-c" "apollo" "ipc" "call" "games" "toggle" "apolloku"; }
```

Games, statistics and the chess.com handle are kept in the Apollo configuration directory
(`apolloku.json`, `apolloku-stats.json`, `chess.json`, `chess-stats.json`), the same files
the standalone ApolloWidgets used. Set `games.chessUsername` in `config.json` to show
chess.com ratings; the old top-level `chessUsername` key is still read.

## Tailscale

The Tailscale tile in quick settings connects and disconnects; right-click opens its page
with the device list, exit node, and the shields-up, DNS and route switches. Changing
Tailscale settings requires this user to be the tailscaled operator. When it is not, the
page offers **Grant access**, which runs `pkexec tailscale set --operator=$USER` once;
the equivalent by hand is `sudo tailscale set --operator=$USER`.
