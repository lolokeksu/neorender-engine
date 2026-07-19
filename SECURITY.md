# Security policy

## Supported version

Security fixes are provided for the latest `v1.x` release of NeoRender Engine. The supported target is Realme GT Neo 5 SE (`RMX3700` / `RMX3701`) on Android 13.

## Reporting a vulnerability

Use a private GitHub security advisory when the repository supports it. Do not publish an exploit, private build fingerprint, account information or sensitive package list in a public issue.

Include:

- NeoRender version;
- exact device identifier and Android build;
- root manager and version;
- reproducible steps;
- relevant source file and line, when known;
- output of `neorenderctl doctor` with private information reviewed first.

For ordinary compatibility failures, use the GitHub issue templates instead of a security report.

## Emergency recovery

From Android:

```sh
su -c neorenderctl safe disable
su -c reboot
```

From recovery with decrypted `/data`:

```sh
touch /data/adb/modules/neorender-engine/disable
reboot
```

## Security properties

The release contains no APK, native ELF executable, shared library, remote updater, telemetry, certificate modification, DNS replacement, SELinux disable command or boot-partition write. Support bundles are generated locally and must be reviewed before sharing.
