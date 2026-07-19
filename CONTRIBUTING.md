# Contributing

## Scope

Contributions must preserve NeoRender's narrow scope: transparent management and measurement of Android HWUI renderer selection on the explicitly supported device and firmware family.

Do not add undocumented performance properties, remote code download, telemetry, SELinux changes, thermal bypasses, CPU/GPU frequency control or closed binaries.

## Development workflow

1. Create a branch from the current default branch.
2. Modify files under `module/`.
3. Run `./scripts/test.sh`.
4. Run `./scripts/build.sh`.
5. Test the generated ZIP on an explicitly supported device.
6. Submit a pull request with reproducible test output and the exact build fingerprint.

## Shell requirements

Runtime scripts must remain compatible with Android `/system/bin/sh` and BusyBox `ash`. Use LF line endings. Avoid Bash-only syntax.

## Reporting measurements

For A/B changes, provide the same package, scenario, duration, sample size, p95, jank percentage, temperature change and raw report path. A single run is not enough to claim a general performance improvement.
