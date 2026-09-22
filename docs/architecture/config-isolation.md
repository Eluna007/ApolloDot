# Configuration and startup ownership

Apollo's settings database lives at `$XDG_CONFIG_HOME/apollo/config.json` and holds the
shell's settings.
The main Niri configuration, outputs, layout and the user's own fragments stay under user
management. The Settings Center reads the effective include chain only, and in normal
operation writes just the Apollo-managed fragments below; it does not migrate the user's
existing bindings.

| Fragment | Responsibility | Explicit entry point |
| --- | --- | --- |
| `apollo/effects.kdl` | X-Ray rules for Apollo surfaces; may contain only comments by default, and does not take over global blur | General → Transparency and blur |
| `apollo/cursor.kdl` | Cursor theme, size and hide options | Cursor section of Theme |
| `apollo/layer-rules.kdl` | Overview backdrop rules and the globally transparent workspace background | Overview section of Wallpaper |
| `apollo/binds.kdl` | Bindings the user adds on the shortcuts page, plus full overrides | General → System → Shortcuts |

There is no built-in outputs or colors fragment registration or template; the historical
documentation's statement about colors.kdl ownership has been withdrawn.
Normal Matugen, colors.json, output queries, multi-monitor positioning and per-screen
wallpaper keep their own responsibilities.
Users may still register arbitrary Matugen templates of their own. Historical user files
and includes are not cleaned up automatically.

Installation deploys only the program and read-only resources. Startup, page loading and
file watching never initialize a fragment.
Clicking the corresponding "Set up" creates the missing file and appends the missing
top-level include at the end of the main configuration; an existing file is not populated,
even when empty. Ordinary, optional, indirect and equivalent-path includes are all
recognized by the KDL parser.
Deleting the file or the include stops generation and prompts again; a permanent
`firstSetupDone` flag must not stand in for that state.

The default main configuration uses the XDG path, preferring `NIRI_CONFIG` and any
confirmable custom niri startup path. Writing is refused when multiple session
configurations cannot be told apart. When no main configuration exists, none is created.
Symlinks, hard links, special files and unwritable targets are read-only, and privileges
are never escalated. Fragment paths are relative to the directory of the actual main
configuration.

The shared on-demand helper `scripts/system/niri_config.py` uses the KDL-py parser deployed
with the program and performs no actions.
The candidate include graph preserves merge boundaries in a temporary directory and is
published only after a real `niri validate` passes. All features share a flock and compare
the read version before committing; a uniquely named backup of the main configuration is
saved before it is modified. Fragments are published first, then the include is appended;
on failure the fragment is rolled back provided its contents are still from this run.
Multi-file operations are not atomic transactions; an external editor that does not honor
the lock still leaves a race window after the final check.
Saved to disk, referenced, and actually reloaded by niri are distinct states — no reload or
restart is performed proactively.

Shortcuts are grouped by complete, typed action expressions; directory placeholders are not
saved to the settings database.
Built-in actions are always retained, and parameter templates must be filled in by the
user. On first explicit set-up, a missing binds.kdl uses the
[default IPC key bindings](../ipc.md); physical key occupancy in the effective include
chain is checked first, and a conflict refuses the write and lists the conflicting keys.
An existing file is not populated, and upgrades or restarts do not restore deleted
bindings.

Editing the title or options of an external binding creates a full override for the same
key in binds.kdl without modifying the source file.
Each chip's title and options are independent; unset, empty string and null are each
preserved distinctly.
The same managed entry is updated in place, and changing its key forms a single candidate
modification. Colliding with another managed key is refused rather than silently yielding.
An external binding's original key cannot be deleted or rebound directly — use "+" to add
another key. Managed entries can be deleted and overrides can be removed, after which the
external fallback is shown again. A later include may override Apollo's entry again; the UI
shows the source and override state, and include order is not adjusted.
Differing spellings of Mod and the actual modifier are judged separately by niri's symbol
merging and by physical trigger order, so a physical conflict is not misreported as a
later-write override. Out-of-scope content such as mouse, scroll wheel and switch-events is
preserved as-is.

Watching covers only the main configuration, the effective include chain and those files'
parent directories, supporting atomic replacement and recovery of missing files, without
scanning backups or polling whole directories.
Drafts are preserved during editing, and a version change requires cancelling and
reloading.
Key recording captures only once the actual settings window has been granted a
ShortcutInhibitor, and releases immediately on focus loss or close. When a key cannot be
matched against the live keyboard layout, the user is prompted to type the XKB key name
manually.

The session is started by niri-session, and the units for the shell and the clipboard
watcher follow `niri.service`.
Fcitx5, nm-applet and blueman-applet are managed by XDG Autostart, and the Polkit agent is
still started by the user's own configuration.

## Matugen template registration and enablement state

`<shell root>/matugen/config.toml` and `templates/` are read-only built-in resources
installed by the package manager. `$APOLLO_CONFIG_HOME/matugen/config.toml` (by default
`$XDG_CONFIG_HOME/apollo/matugen/config.toml`) registers user templates only. Built-in
resources are not copied on first start, and the user directory need not exist. An orphan
file in the templates directory does not constitute registration.

`scripts/lib/matugen-registry.sh` and `scripts/theme/matugen_registry.jq` together read
both registry layers, and the parsed result is shared by
`manage_matugen_templates.sh list` and the generation script.
`MatugenTemplateService` exposes the dynamic model, the source, resolved absolute
input/output paths, hooks and errors.
A user ID must not override a built-in ID, and a duplicate ID within the same layer is
invalid; `quickshell` is a hidden, required internal template.

An explicit canonical subset of TOML is supported:

```toml
[templates.ghostty]
input_path = "templates/ghostty.conf"
output_path = "~/.config/ghostty/themes/Matugen"
post_hook = "optional command"
```

Fields use single-line double-quoted strings, supporting `\"`, `\\`, `\b`, `\f`, `\n`,
`\r`, `\t` and `\uXXXX` escapes, plus blank lines and `#` comments. `post_hook` may be
omitted. Inline tables, multi-line or single-quoted strings, other fields and other
TOML-equivalent spellings are not supported; unsupported content is reported as an error.
IDs are case-sensitive and consist of letters, digits, underscores and hyphens, and such
segments may be joined by a single dot.
An ID containing a dot must be written as `[templates."editor.custom"]` so TOML does not
treat it as a nested table; the manager always emits quoted IDs and never renames them on
its own.

A relative input path is resolved against its own registry's directory; an output must be
an absolute file path, `~/...` or `$HOME/...`. Paths undergo no variable or command
substitution and no `eval`; remaining `$`, backticks and control characters are rejected.
Built-in outputs support the `@APOLLO_GENERATED_HOME@` placeholder.

`theme.matugenTemplates` in `config.json` is an ID → bool map that preserves existing state
for unknown but valid IDs. A newly discovered built-in template is recorded as `true` and a
user template as `false`; an explicit state always wins.
An invalid template cannot be enabled and is never passed to generation by the Settings
Center. Configuration file watching plus a 5-second polling refresh is what discovers a
registry created for the first time, manual edits, and deletion or restoration of input
files.

The add window reuses FilePicker and accepts any ordinary UTF-8 template file. After the
user clicks add, the manager validates statically and invokes Matugen `--dry-run` (with a
fixed validation color and hooks removed), writing the registration only on success. The
standalone `validate` CLI remains, and the UI does not require the user to click validate
first. A BrailleSpinner with a fixed placeholder is shown while adding; on failure the
window stays open and displays the error. Matugen's `--dry-run` does not render template
expressions, so syntax and rendering problems may still be reported during real generation.
The manager copies the source file to the user's `templates/<ID>.<original extension>`,
writes the config to a temporary file in the same directory and replaces it by rename.
Apollo writers are serialized through flock and check whether the configuration was edited
externally before committing.
A failure never publishes a half-written registry; unsupported configuration syntax must be
fixed by the user first, and a symlinked config should be managed manually.
External editors should still use atomic writes; comparing before committing cannot
eliminate every race window for editors that do not honor the lock.

Deletion removes only the user section and then cleans up the `config.json` state. Only
ordinary source files that no other registration references and that sit directly in the
managed directory are cleaned up. Manually registered external source files, symlinked
sources and shared sources are kept.
**No output_path is ever deleted as a result of turning off a switch or removing a
registration.**

"Open template location" calls `xdg-open` via argv on the source file's parent directory,
not on the generated target.
When the default directory handler declares `Terminal=true`, `xdg-terminal-exec` supplies
the terminal, avoiding the case where `xdg-open`'s generic backend launches a terminal file
manager with no TTY. MIME default configuration is not modified.

A template's `post_hook` is an arbitrary command executed with the user's privileges — it
is not a sandbox. Newly discovered user templates default to off. The Settings Center shows
a terminal information marker with no click or keyboard action, exposing the command
through a tooltip.
The switch controls the whole template directly; there is no separate hook permission or
enablement confirmation.
Validation and adding do not execute hooks. Enabling a template means the user trusts its
contents, and subsequent edits to the template and its hook warrant care.

Each generation writes a runtime configuration to
`$APOLLO_RUNTIME_HOME/temporary/matugen.XXXXXX/config.toml` without touching either
registry layer. The internal color scheme is generated first and, after the `core-ready`
JSONL line is emitted, `Appearance.reloadColors()` is notified immediately; valid, enabled
external templates are then generated one by one, creating parent directories for each
output_path.
Adding a template requires no changes to the service, the UI or the application list in the
generation script. A script invocation without `--templates` enables only the built-in
templates by default; `--templates ''` generates just the internal color scheme.

The generation script's stdout is schemaVersion 1 status JSONL (`core-ready`, `core-error`,
`external-error`, `finished`); Matugen diagnostics are reported through stderr and the error
field. Exit 0 means success, 3 means the core succeeded but an external template failed, and
any other non-zero means a core or invocation failure. An external failure still continues
with the remaining templates, and the Settings Center shows the error with details in a
tooltip. A hanging hook delays subsequent external templates but does not delay the already
completed core color reload; no command sandbox or hook timeout policy is provided here.

## Spotlight application ordering and usage records

Settings Center → Spotlight → Applications → Application order offers Smart, Most used,
Recently used and Name. `spotlightAppOrder` in `ui-preferences.json` stores `smart`,
`most-used`, `recently-used` and `name` respectively, defaulting to Name when missing or
invalid.
The list and grid share the ordering. During a search, keyword relevance always comes
first, usage ordering compares only within equal relevance, and name then desktop ID give a
stable final order.

Usage records are stored separately in `Paths.stateHome/spotlight-app-usage.json` (by
default `$XDG_STATE_HOME/apollo`, or `~/.local/state/apollo` when unset), recording
`launchCount` and a Unix-millisecond `lastLaunchedAt` per desktop ID.
Only valid requests issued by Spotlight through the existing launch path are recorded;
terminal and other entry points are not counted, and no claim is made that an application
window actually appeared.
When the history file is missing, counting starts from empty and is saved atomically after
the first launch; launches during a read are accumulated and then merged. A file that
cannot be read, is corrupt, or has an unknown schema is left untouched, and the session
continues with in-memory counts.

Most used compares cumulative counts; Recently used compares last launch time; Smart uses
`log2(launchCount + 1)` plus a recency score, adding 8, 6, 4 and 2 points for a last launch
under 1 hour, 1 day, 7 days and 30 days ago respectively, with no points for older or
unknown times. It is computed against the current time each time Apps is opened or a search
is rerun, without adding periodic polling, and a closing grid is not reordered after a
launch.
