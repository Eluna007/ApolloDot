# Spotlight Search

`search` is the default input-only mode. Dedicated `apps`, `wallpapers`,
`clipboard` and `files` retain their own layouts and lifecycle. Search renders a
single selectable list with nonselectable group headings, bounded initial group
budgets and incremental **Show more** rows. There is no global score comparison
between categories. Namespaced result IDs and the original query are captured
for activation; an old query cannot activate its old rows.

`Common/functions/SpotlightLocalSearch.js` shares the existing Apps relevance and
Wallpaper filename ordering. Apps in both entry points use `SpotlightAppOrder`
and `SpotlightAppUsage.launch`, counting an accepted launch once. Usage writes do
not trigger a visible re-sort during the closing transition.

## Declarative catalogs

`Common/settings-routes.json` declares the static page tree: stable ID, English
title/context, aliases, icon, relative QML source and a path of navigation IDs.
The Settings rail and static General subpage routing use these declarations.
Dynamic device pages and user content are deliberately excluded.

Meaningful sections declare a `SettingsSearchAnchor` next to their real content.
Its single-line `declaration` string is JSON containing `id`, `route`, `title`,
`context`, `icon`, `aliases` and optionally an allowlisted `availability` value.
The anchor's `target` is the actual section; the section binds its title to the
anchor's `title`. This is an explicit declaration format, not automatic discovery
of arbitrary `title:` properties. Keep the declaration literal on one line; do
not place secrets or settings values in it. Source filenames must agree with the
route, with the explicit General overview host as the only special case.

`search` metadata in `scripts/system/niri-actions.json` classifies every Clavis
shortcut as `include`, `alias`, `settings`, `parameters`, `internal` or `unsafe`.
Included entries supply translated title/description, icon, aliases, fixed `args`,
availability and confirmation policy. The compiler checks the fixed argv against
the existing shortcut expression and a small execution whitelist. New executable
capabilities need an explicit whitelist entry and a matching business-function
branch in AppShell. Search never executes an expression from this JSON.

`search_catalog` is an ALL CMake target. It invokes
`scripts/dev/generate-search-catalog.py` when declarations change, validates
schema/IDs/routes/arguments/policy and produces the deterministic, tracked
`Common/generated/SearchCatalog.js`. The same file serves the source checkout
and the normal Common directory installation. It contains no build-machine
paths. Run the generator directly after editing declarations, then the normal
`update_translations` target (which depends on generation). Literal
`qsTranslate(context, source)` calls in the generated file make the same titles
extractable. Do not edit the generated file or add qmldir files.

`SpotlightCatalog` prepares localized title/English title/aliases once per language
change. Query matching reads that in-memory catalog; it neither creates Settings
pages nor reads source/configuration files.

## Navigation and execution

`ControlCenterService` owns one pending setting target and a monotonically
increasing request serial. Existing page hosts expose readiness and forward a
stable path one level at a time. Loaded signals and geometry changes retry the
request; two stable geometry observations precede scrolling/highlighting. The
bounded deadline only reports unavailable content; it is not a loading delay.
An intervening manual navigation cancels the request instead of forcing a route
back. Anchors register on creation, unregister on destruction, and reset their
soft, theme-colored highlight when a request is replaced or the window closes.
The highlight has no input handlers and uses existing animation durations.

Search Settings/Actions capture IDs, close Spotlight and dispatch after its
keyboard-exclusive window is released. Actions call existing services or the
same AppShell/Keystone/sidebar methods as IPC, rechecking availability. Spotlight
mode actions switch internally and clear the action-search text; Files/Web
extensions retain the literal original query. Only explicit activation can run
an action, and repeated Enter events are ignored.

Inactive Clipboard stops enqueueing inspections and releases pending demand;
one already running read may finish into its normal cache. Watchers and restore
operations are untouched. Files retains its generation/cancellation protocol and
receives an active query only in Files. Wallpaper's dedicated provider retains
its original explicit refresh, while Search reads only the already loaded path
list. Thumbnails are small, first-frame images instantiated by visible list rows.
