# UI copy and waiting feedback

Read the relevant section when changing UI text, settings page layout or interaction.
Review only the current change and the state expressions immediately adjacent to it.

## UI copy and information density

- Settings pages do not carry supporting text by default. Add supporting text only for new
  information the title, icon and control state cannot express — for example a dynamic
  value, the current mode, a reason for unavailability, an error, or a validation
  requirement.
- Never restate a boolean control state in words: the "On" in `Wi-Fi / On / switch ON`
  must be removed. A normal state usually needs no explanation, while abnormal states such
  as a hardware block, a permission failure or an unavailable backend should explain the
  cause briefly.
- A subtitle must not paraphrase or repeat its title; "Add network / Manually add a
  network" is useless copy.
- Ordinary UI must not expose backend implementation terminology with no user value, such
  as `NetworkManager configuration`, `DBus backend` or internal UUIDs. Only an explicitly
  advanced diagnostics page may show them.
- Keep one primary expression per meaning. When a selected/highlighted shape, switch, icon,
  badge or dynamic value already expresses the state completely, do not add a sentence
  repeating it.
- Express information hierarchy and state first through the project's existing Material
  Design / expressive shapes, icons, badges, state layers, tooltips, switches, sliders and
  animation; do not build a parallel component system.
- Use tooltips for icon-only actions, secondary explanations, and supporting information
  not worth occupying the layout permanently. Do not spread every explanation permanently
  across the page just to avoid tooltips.
- Write for a global audience with short, consistent noun or verb phrases, avoiding full
  explanatory sentences, implementation terminology and unnecessary translation burden.
  Errors, destructive-action warnings, validation rules, authentication or permission
  failures, and labels for ambiguous actions must not be hidden in the name of concision.
- Material expressive UI should establish hierarchy visually first, with copy supporting
  only what the visuals cannot convey reliably; page structure must not depend on large
  amounts of prose.
- Before delivery, review the settings entries added or changed in this round: are
  title/subtitle, icon/text, switch/status text or badge/description duplicating each
  other; do adjacent sections express the same state twice; is implementation terminology
  with no user value exposed. Do not expand this into a cleanup of the whole Settings
  Center, and do not produce a separate audit report.

## Waiting feedback in Settings

Short asynchronous waits in the Settings Center reuse `BrailleSpinner` by default,
preferably shown through `Widgets/common/InlineBusyIndicator.qml` as a non-layout overlay
in existing whitespace near the triggering control. Never add layout space for a waiting
indicator, and never insert or remove a whole row, or change the position, spacing or
geometry of buttons and sections, because of a busy state. A single operation marks only
the control that actually triggered it; a global operation may be shown in existing
whitespace near the section header. `InlineStatusBanner` is reserved for errors, warnings
and information that needs attention, and is not used for a plain "working" state. Do not
build a separate loading-animation system.
