# Spotlight Search

`search` is the default input-only mode. Dedicated `apps`, `wallpapers`,
`clipboard` and `files` retain their own layouts and lifecycle. Search renders a
single scrolling surface with nonselectable group headings. Apps use compact
icon/name tiles and Wallpapers use rounded thumbnail/name tiles, each limited
to one responsive row. Settings and Actions show up to two entries each.
Categories do not expand; all horizontal cells are available for results.
There is no global score comparison
between categories. Namespaced result IDs and the original query are captured
for activation; an old query cannot activate its old rows. Up/Down moves between
visual rows; Left/Right moves within a tile row, without a separate input/result
navigation state. Esc follows the shared modal/rail/clear-input/close behavior.
Pending preedit text
defers launcher keys to the IME; cursor/format-only IME state after a commit does
not keep launcher navigation suspended.
The flat identity model is retained independently of visual packing,
including when a resize or background update changes the rows. An existing
selection can occupy the last available slot without increasing the category
budget. Only visible rows instantiate thumbnails; all categories share the
vertical scrollbar.

`Common/functions/SpotlightLocalSearch.js` shares the existing Apps relevance and
Wallpaper filename ordering. Apps in both entry points use `SpotlightAppOrder`
and `SpotlightAppUsage.launch`, counting an accepted launch once. Usage writes do
not trigger a visible re-sort during the closing transition.

## Mode rail motion

`SpotlightModeMorphSurface` derives the pill and four deforming buttons from a
single reversible progress value. Shape-preserving cubic curves retain motion
through extraction, a tapered four-lobe chain, left-to-right separation and a
small settle, without holding an intermediate pose. The
controller advances time linearly so it does not compress these phases with a
second easing curve; interrupted transitions continue from the current value.
Icons follow the same timeline and appear during separation.

The launcher shader blends five rounded distance fields, without separately
drawn connectors or a vertical clipping band. Derivative-based antialiasing
follows render scale. Compositor blur uses inset shape regions and conservative
interior neck regions; these approximate the silhouette without extending blur
across detached gaps. The intermediate texture is opaque; the final effect
applies `surfaceColor.a` once, preserving the configured background opacity
through shadow compositing. `spotlight_mode_field.frag.qsb` uses a new resource
URL for the changed uniform layout, because Qt can retain the old shader in its
process-wide cache across QML reloads. Rebuild its tracked `.qsb` with
`scripts/build/compile-launcher-shaders.sh` after editing the fragment shader.

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
