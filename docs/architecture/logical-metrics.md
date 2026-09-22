# Unified logical sizing

`Common/Metrics.qml` holds the static logical-pixel tokens reused across components,
covering spacing, icons, control height, touch targets, corners, card and page padding,
sidebar, bar and avatar sizes.

Components use logical sizes such as `Metrics.controlHeightM`. These tokens take no
user-level global multiplier, and are not multiplied by the Niri scale or by
`devicePixelRatio` — Qt/Wayland already handles the conversion from logical pixels to
buffer pixels. DPR may be used only for the one-pixel edge alignment that genuinely needs
it.

Migration proceeds gradually: common Widgets first, then Settings Center controls, then the
bar, sidebars and popups, then the high-traffic modules. Shader constants, one-off special
visual values, animation curves and content-derived sizes stay local; do not invent
semantically meaningless tokens just to eliminate numbers.
