# Shell background transparency and blur

"General → Transparency and blur" in the Control Center adjusts only the outer background
of Apollo's windows.
Text, icons, images, buttons and inner cards do not inherit extra transparency. Background
blur is implemented by niri's `ext-background-effect` and requires niri 26.04 or newer.

Apollo manages `~/.config/niri/apollo/effects.kdl`. niri applies X-Ray to
client-requested effects by default, so when "blur wallpaper only" is enabled the fragment
generates no `background-effect` override at all. When that option is disabled, the fragment
sets `xray false` only for the `^apollo-shell-` layer namespace and for Apollo's settings
and file picker windows. The fragment never writes `blur true`, and never matches the
wallpaper, overview, lock screen, screenshot selection or input capture surfaces.

The main configuration must contain:

```kdl
include optional=true "apollo/effects.kdl"
```

Without that include, the settings page shows "Niri integration". Only after "Configure" is
clicked does Apollo create `config.kdl.apollo-backup`, validate the candidate
configuration, and then update the main configuration by atomic replacement. An include
that already exists is not appended again.

niri's global `blur` block remains under user management. If it contains:

```kdl
blur {
    off
}
```

the Region Apollo submits will produce no visible blur; Apollo does not modify or remove
that setting.
