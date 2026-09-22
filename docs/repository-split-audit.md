# Project responsibility audit

## Apollo Shell

`core/src/` and `core/plugin/` provide:

- `Apollo.Niri`: Niri IPC, windows, workspaces, outputs and window icons;
- `Apollo.Weather` / `Apollo.WeatherMap`: Open-Meteo, map credentials and RainViewer metadata; map rendering and network tile caching are handled by MapLibre Native Qt;
- `Apollo.Cava`: PipeWire live capture, RMS/Peak, spectrum and libcava;
- `Apollo.Lyrics`: asynchronous Local/LRCLIB/NetEase providers, caching, LRC and seek mapping;
- `Apollo.Media`, `Apollo.Keyboard`, `Apollo.I18n`, `Apollo.Runtime`.

`M3Shapes` is provided by a system package (Arch: `qt6-m3shapes-git`) and is an external
QML runtime dependency.

## key-cli

The Python wheel provides only `shell`, `ipc`, `record`, `audio`, `clipboard`, `doctor` and
`version`. It orchestrates `qs`, gpu-screen-recorder, slurp, FFmpeg, the
PulseAudio/PipeWire-compatible `pactl`, cliphist and wl-clipboard. It does not read `/proc`
to implement system monitoring, and it does not own QML state or the weather and lyrics
models.

## keytop

`keytop` alone owns system sampling, the TUI, JSON snapshots and the JSONL stream. Apollo
starts `keytop value stream` directly, without going through `key-cli`.

Apollo uses four independent lifecycles for system information: static identity is read
once through `keytop value system` when the Quickshell process starts; uptime is calibrated
once from `/proc/uptime` while a visible consumer exists and then updated from the local
monotonic clock; battery uses `Quickshell.Services.UPower` directly; and CPU, GPU, Memory,
Disk and Network maintain a single keytop JSONL stream over the module union of the visible
owners, with all active modules sharing the user-configured sampling interval.

## Explicitly removed

Apollo no longer contains the old C++ CLI, the system monitoring plugin, the screen and
audio recording backends, the weather CLI bridge, screen casting, or in-application
version/install/rollback management, and it does not create additional orchestration
scripts for running from source.
