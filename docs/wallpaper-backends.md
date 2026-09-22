# Wallpaper backends and the niri overview

Apollo treats the ordinary desktop wallpaper and the niri overview background as two
separate surfaces.

With the `quickshell` desktop backend, the runtime structure is:

```text
Quickshell
├── Background: apollo-wallpaper
└── Background: apollo-overview-wallpaper
```

With the `awww` desktop backend, the runtime structure is:

```text
Quickshell
├── Background: apollo-wallpaper (surface stays resident, wallpaper content hidden)
└── Background: apollo-overview-wallpaper

awww-daemon --layer background --namespace apollo-desktop --no-cache
└── ordinary desktop wallpaper

Bottom
└── apollo-desktop-cards
```

The `apollo-wallpaper` PanelWindow is not destroyed along with the desktop backend. When
switching to awww, Apollo waits for `awww img` to succeed on every output before hiding the
Quickshell desktop content; when switching back it first restores the already loaded
Quickshell static wallpaper, then stops `apollo-desktop`. No DMS shader transition runs
while hidden.

The overview surface is always created per output by Quickshell. It takes no part in
desktop backend selection, and does not inherit the desktop's workspace, tiling column or
sidebar parallax.

## niri layer rule

The "Set up" button in the Overview section of the wallpaper page explicitly creates and
wires up `apollo/layer-rules.kdl`:

```kdl
layer-rule {
    match namespace="^apollo-overview-wallpaper$"
    place-within-backdrop true
}

layout {
    background-color "transparent"
}
```

If the configuration still contains the old
`match namespace="awww-daemonoverview"`, the user must replace it manually with the
`apollo-overview-wallpaper` rule above. The Settings Center reads the effective include
chain, and shows a rule already satisfied externally separately from Apollo-managed set-up.
Neither first start nor opening the page writes configuration; only clicking "Set up"
creates the missing fragment and appends the include.

A transparent workspace background is required for the backdrop to coexist properly with
window transparency and blur effects.
If niri's default opaque background color is kept, kitty's `background_opacity` still takes
effect, but only the opaque workspace background shows through behind it, and xray blur
cannot sample the desktop wallpaper either.

Do not use `place-within-backdrop` on the ordinary desktop namespace `apollo-wallpaper`.

After reloading the niri configuration, run:

```bash
niri msg layers
```

to confirm the overview surface's namespace is `apollo-overview-wallpaper` and that the
rule has matched.

## Multi-monitor mapping

The desktop mapping stores the global wallpaper, `monitorWallpapers` and
`monitorWallpaperFillModes`. The overview separately stores a global wallpaper,
`overviewMonitorWallpapers` and `overviewMonitorFillModes`.

When the overview uses its own wallpaper, resolution proceeds in this order:

1. the current output's overview wallpaper;
2. the global overview wallpaper;
3. the current output's desktop wallpaper;
4. the global desktop wallpaper.

Choosing "use the desktop wallpaper" reads Apollo's original desktop wallpaper path
directly — it does not screenshot the awww surface or read the awww cache.

## awww namespace

Apollo owns only `apollo-desktop`:

```text
awww-daemon --layer background --namespace apollo-desktop --no-cache
awww query -n apollo-desktop
awww img -n apollo-desktop -o <output> ...
awww clear -n apollo-desktop -o <output> ...
awww kill -n apollo-desktop
```

Every command is executed as an argument array. Apollo does not use the default namespace,
does not call `killall`, and never stops other awww instances.

awww's FPS and transition step are stored in `wallpaper.awww`. Duration, easing mode and
Bézier curves share the existing configuration in `wallpaper.transition` with the Quickshell
overview; only the transition type is stored separately for the overview.
