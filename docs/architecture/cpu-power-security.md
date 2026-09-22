# CPU power reading boundaries

RAPL and other CPU power metrics belong to the separate `keytop` capability. Apollo Shell
only consumes the results of `keytop value stream`; it never requests sudo, installs a
capability, or manages a privilege helper.

```bash
keytop value cpu --format json
keytop value snapshot --format json --modules cpu,system,memory
```

An unreadable powercap interface should report unsupported or permission denied while
continuing to provide the other system metrics. Any packaging integration that requires
system privileges should be designed and reviewed separately, as part of keytop's own
distribution package.
