# Runtime boundaries

The shell's native modules and its QML sources are produced by the same CMake build, and
every first-party QML import uses an unversioned URI. The product version and the JSON
`schemaVersion` are independent of QML import versions.

The system monitoring protocol is provided by `keytop value stream --format jsonl`. The
shell validates `schemaVersion`, the timestamp, the sequence number and the module fields,
and shows an explicit stale or error state when the connection is lost.
The screen recording, audio recording and clipboard protocols are provided by `key-cli`;
the shell only consumes argument arrays and machine JSON.

Weather, Cava, lyrics and Niri state are exposed as reactive models inside the shell
process, so high-frequency data does not have to pass through a CLI or a Python relay.
