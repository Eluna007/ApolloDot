# Internationalization

Apollo uses English source text with Qt's context-based translation system.
English (`en_US`) is the only shipped language; the catalog lives in
`i18n/apollo_en_US.ts`.

## Language selection

A saved language selection takes precedence. Without one, Apollo selects the
first supported language in Qt's system UI language preferences, falling back
to English if none match. English variants use `en_US`.

Language normalization lives in `Apollo.I18n.I18nManager`; UI preferences use
that same resolver. Existing saved choices remain valid. Switching UI language
does not change the global regional locale, temperature units, weather location,
or clock preferences.

## Editing messages

- Write concise English inside `qsTr()` / `qsTranslate()`. Preserve context and
  disambiguation when moving or changing a message.
- Retain the English catalog with each source change: the runtime loads it,
  including English plural forms.
- Use `%1`, `%2`, etc. with `.arg()` for dynamic values. Translate complete
  phrases, not word fragments joined around a variable. Use Qt numerus messages
  for counts (`qsTr("%n minute(s) ago", "", count)`).
- Keep labels brief. Do not repeat a title in supporting text or describe a
  switch's visible state. Keep error reasons and destructive-action warnings.
- Leave configuration keys, protocol values, user data, names, and
  language-specific date formatting alone. They are not translation sources.
- Missing translations fall back to English source text. Review unfinished
  entries before shipping; extraction cannot translate new messages for you.

Use consistent terms: **Settings**, **Quick settings**, **Sidebar**, **Desktop
cards**, **Keystone**, **Clipboard**, **Cloud storage**, **Connect**,
**Disconnect**, **Cancel**, **Delete**, and **Reset**. Use *Delete* for removal of
saved data, and *Remove* when only taking an item out of a layout or selection.

## Updating catalogs

After the normal CMake configure, extract source messages with:

```bash
cmake --build build --target update_translations
```

The extraction scope includes the shell sources and its i18n module, excluding
test messages and third-party headers. See [Qt’s translation target documentation](https://doc.qt.io/qt-6/qtlinguist-cmake-qt-add-translations.html)
for the extraction behavior introduced in Qt 6.7.

Review all three TS files and finish new or changed translations. A normal
build compiles and embeds the QM catalogs. Run the appropriate single
`scripts/dev/check.sh` validation scope from `AGENTS.md`; shared language interface changes follow its consumer-scope rules. Use `--full`
when that impact cannot be reliably bounded, not for ordinary message edits.

Review placeholder preservation, singular/plural forms, language switching,
and long English labels. The native i18n tests exercise
language preference resolution, compiled catalog lookup, English fallback,
plural selection, and preservation of regional settings. They do not inspect
QML source structure.

The former Han-detection wrapping script has been retired. Review new visible
text and Qt's extracted catalogs instead.
