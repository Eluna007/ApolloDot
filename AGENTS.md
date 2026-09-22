# Apollo Shell development conventions

## Project responsibilities

Apollo is a CMake/Ninja + QML/Quickshell project. `shell.qml` is the entry point and
`AppShell.qml` handles top-level assembly. `Modules/` holds feature modules, `Services/`
holds long-lived state and system interaction, `Widgets/` holds presentation-only
controls, `Common/` holds theming, sizing, paths and pure utilities, and `core/` holds
native backends and QML plugins.

The three repositories are independent projects; tests and builds must not depend on each
other:

- Apollo owns the QML UI, the Quickshell lifecycle, Niri IPC, windows/workspaces/outputs,
  weather, WeatherMapProvider, MediaPalette, shortcut recording, live Cava, MPRIS lyrics
  and the synchronized timeline.
- `key-cli` owns `key shell`, `key ipc`, screen recording, audio file recording, the
  clipboard and keyboard-lock state backends, and the outward-facing machine JSON
  protocol.
- `keytop` is the sole owner of system metrics collection, parsing, the TUI and the
  JSON/JSONL machine protocol. Apollo consumes `keytop value stream --format jsonl`
  directly and must not reimplement keytop's parser.

Apollo's tests must hold up in a standalone clone; they cannot depend on `../keytop`,
`../key-cli` or their build artifacts. Do not reinstate `cast`, `key top`, `key sysmon`,
Apollo.Sysmon, weather CLI relaying, the Python lyrics script, the embedded C++ key CLI,
the release manager, rollback, the `current` symlink, `releases/`, `setup.sh`, `justfile`
or a Makefile. Reference repositories are read-only and must not be modified.

## Development entry

A single top-level CMake/Ninja build covers native modules, tests and QML installation.
Build commands and the development entry point are described in
[docs/development.md](docs/development.md); read it only when preparing a development
environment or starting the shell. The development entry `~/.config/quickshell/apollo`
points at the source tree; external entry points use `${APOLLO_KEY:-key}`.
Integration work with key-cli uses its editable `.venv` plus an explicit user-service
drop-in; `key shell` propagates the current entry point automatically. Source
installation of key-cli and its optional keyboard authorization are handled by its own
installer and do not require distribution packaging. Apollo keeps its own unit and
session lifecycle; see the development documentation.
New shortcuts call `qs -c apollo ipc call TARGET METHOD [ARGUMENTS...]` directly; the
`key ipc` compatibility entry point remains. Never write repository or build absolute
paths into the Niri configuration.

## QML modules

- `import M3Shapes` uses the externally installed QML runtime module (Arch:
  `qt6-m3shapes-git`). Apollo neither compiles nor installs it, and the vendored
  implementation must not be reinstated.

- `import qs.Common`, `import qs.Services` and `import qs.Modules.Foo` are
  Quickshell root-relative shell modules. Pure QML directories must not gain
  hand-written `qmldir` files.
- Native imports such as `import Apollo.Weather`, `import Apollo.WeatherMap`,
  `import Apollo.Cava` and `import Apollo.Lyrics` are managed by CMake's
  `qt_add_qml_module()`. Do not add meaningless version numbers.
- Build-tree output for native QML modules goes under `build/qml/`. `qmldir`,
  `*.qmltypes` and the plugins are CMake/Qt generated artifacts and must not be written
  or edited by hand.
- Presentation components must not create a `Process` or run system commands. Screen
  recording, audio recording and the clipboard go through `key` invoked with an argument
  array, and must validate the machine response's `schemaVersion` and errors.
- FFmpeg, pactl, ffprobe, the recording PID, temporary audio files and the finalizer
  belong to `key audio`; lyrics fetching, caching, LRC parsing and MPRIS seeking belong
  to `Apollo.Lyrics`.

## Internationalization

User-facing translatable source text is written in English, using the existing
`qsTr()` / `qsTranslate()` context and disambiguation mechanisms. Keep
`i18n/apollo_en_US.ts` in sync when adding or changing text. Use placeholders for
dynamic values and Qt numerus forms for counts; never concatenate translated fragments.

`I18nManager` resolves the language: a saved user choice wins, otherwise the system UI
language preferences are matched, falling back to English when none match. Switching the
interface language must not change the global regional locale, units or weather location.
Language options keep their endonyms. Comments, documentation, protocol values and user
data are not in scope for source-text migration.
Maintenance process and terminology are in `docs/internationalization.md`. Scanning for
Han characters is not a substitute for internationalization review.

## Task-specific guidance

Read these only for the relevant task; there is no expectation of reading every document
each round:

- Changing UI text, settings page layout or interaction: [UI guidelines](docs/ui-guidelines.md).
  Reuse existing components and preserve error and authentication messages. Information
  density review covers only the current change.
- Changing translatable source text, translation catalogs or language resolution:
  [internationalization guidelines](docs/internationalization.md).
- Changing the check toolchain, or when a check fails: the relevant section of
  [development checks](docs/development-checks.md).
- When applying a skill, use only the sections that fit the current platform and task.
  QML work does not trigger Android or Web build or emulator checks. Design compliance
  reports are produced only when the user asks for a design audit.

## Test Policy

Quality checks and tests are separate. `qmllint`, `qmlformat`, `clang-format`, `bash -n`,
`shellcheck`, Python `compileall`, compiler warnings, the build and `git diff --check` are
quality checks, not tests.

**Do not add tests automatically just because code was changed.**

**Fixing a bug does not automatically require a regression test.**

Before adding a test, settle the following. These are selection criteria, not a per-round
report to write out:

1. what stable behavior or public contract the test verifies;
2. why lint/build cannot cover it;
3. why a unit test, or a genuinely necessary integration test, is the right level;
4. why the test will not freeze current implementation details.

Acceptable Apollo tests are mainly deterministic C++ unit tests (parsers, geometry and
math, workspace topology derivation, coordinate conversion, wallpaper analysis, lyrics
parsing, path and config resolution, state transitions), a small number of pure QML and
JavaScript state/math QtTests, and script integration tests that genuinely verify external
behavior. QML UI, Button, Loader, animation, color, Item hierarchy, compositor timing and
ordinary visual layout do not get new QtTests by default.

Never use `grep`, `sed`, `awk`, regular expressions or source-text matching to assert
properties, Loaders, ids, Item children, function names, file layout, the current object
hierarchy or the shape of a feature's implementation. Do not create
`test_*_architecture.sh`, `test_*_feature.sh` or `test_*_implementation.sh`, and do not
restore the historical smoke QML. CTest registers only real unit tests, or integration
tests that are genuinely needed — never source audits.

Do not chase coverage percentages, do not introduce coverage.py/gcov/lcov/codecov or
thresholds, and do not adopt clang-tidy, `-Werror`, mypy, pyright or a large pre-commit
framework for the sake of one task.

## Workflow and validation

When the user asks only for analysis, comparison or discussion, do the read-only
investigation the answer needs; do not modify files or run unrelated checks.
When the user asks for implementation, complete the authorized work and its necessary
validation, settling details that follow from existing code and conventions. Ask only
about significant product choices that change the outcome, destructive operations, or
work beyond the authorized scope.

`scripts/dev/check.sh` is the everyday validation entry point. After changing QML, format
the changed files with `scripts/dev/format-qml.sh` first, then run the check at the chosen
scope; do not run format-check, lint and check in sequence over the same files. The default
scope is staged, unstaged and untracked-but-not-ignored files since HEAD, and it does not
reformat unrelated files.

| Change | Necessary validation (pick the matching scope; this is not a serial checklist) |
| --- | --- |
| Documentation, static assets | `check.sh`, usually only the diff whitespace check |
| QML UI, including local visual or text tweaks inside shared components | `check.sh`: format and lint the changed QML; visual check as needed |
| Translation catalogs or translatable source text | `check.sh`, plus updating and compiling the affected catalog per the i18n guidelines |
| Shell / Python | `check.sh`: syntax of changed files, ShellCheck, and the matching existing integration tests |
| `core/`, CMake, `tests/qml/` | `check.sh` configures, builds and runs the existing CTest automatically |
| Pure QML/JS state or math logic | `check.sh` plus the corresponding existing QtTest; use `--native` when a native build is required |
| Public interfaces, module resolution or dependency impact | scope it per the conditions below |

A shared component having many references does not by itself trigger a full check. When
changing public properties, signals, required properties, module exports or import
resolution, first bound the affected consumers: if they can be bounded reliably, run the
checks and existing tests for that scope. Use `check.sh --full` when they cannot be
bounded, when a dependency upgrade is broad, or when the user explicitly asks for a full
check. Narrowing scope is never a reason to miss a consumer; the script's path-based
selection does not replace that judgment.

`--native` forces a build and the whole existing CTest set beyond the changed-file checks.
`--full` expands to first-party quality checks, build and CTest across the tree, though
QML formatting still only covers changed files. Ordinary UI work does not trigger the full
CTest set. Tool arguments, VFS preparation and failure handling are covered in the
development checks document; do not hand-write `.qmlls.ini` or qmldir files, and do not
fake lint results.

Stop once the necessary validation passes and the authorized work is done. Re-run an
affected stage only for new changes, a specific failure, or dependency impact that has not
been validated; do not run the whole flow again at the end. Diagnose a given tool or
environment blocker once. Having confirmed it is a tool problem, keep that result, continue
with the necessary checks that can still run independently, do not report a blanket pass,
and do not migrate the toolchain in passing.

By default do not install, restart processes or commit; those require an explicit request
from the user. Checks must not use sudo, modify the system, or start persistent background
services. Do not fix source problems by hand-editing the build, the user's Niri
configuration, the system Qt import root or installed files — normal CMake build output
excepted.

The final reply states what was completed, the results of the necessary validation, and
anything unvalidated or blocked. For QML advisory warnings, report the count and the log
location rather than claiming a zero-warning pass; say so plainly when no relevant tests
exist. Do not recite commands one by one on ordinary success, and give steps only where
the user has to act. Do not add development summaries or audit reports unless asked.
