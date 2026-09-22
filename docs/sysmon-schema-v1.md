# keytop JSONL schema v1

The one machine interface for system monitoring is:

```bash
keytop value stream --format jsonl --interval 1000 \
  --modules cpu,memory,gpu,disk,network
```

Each line is a complete JSON object containing `schemaVersion: 1`, `timestampMs`,
`sequence`, `intervalMs`, the requested `cpu`, `memory`, `gpus`, `disks` and `network`
fields, and `errors`. Unavailable values are `null`. The shell consumes and validates these
fields directly; there is no CLI relay layer.
Apollo does not request `system` or `battery` from this stream: the former uses a one-shot
`keytop value system --format json`, and the latter uses Quickshell UPower. keytop's v1
protocol still retains the `system` and `battery` modules in full, for its own CLI and TUI
and for other consumers.
