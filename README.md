<div align="center">

# NeoRender Engine

**Transparent HWUI renderer control for Realme GT Neo 5 SE on Android 13**

[![Release](https://img.shields.io/github/v/release/lolokeksu/neorender-engine?display_name=tag&sort=semver&style=flat-square)](https://github.com/lolokeksu/neorender-engine/releases/latest)
[![Validate](https://github.com/lolokeksu/neorender-engine/actions/workflows/validate.yml/badge.svg)](https://github.com/lolokeksu/neorender-engine/actions/workflows/validate.yml)
![Android](https://img.shields.io/badge/Android-13-3ddc84?style=flat-square&logo=android&logoColor=white)
![Device](https://img.shields.io/badge/device-RMX3700%20%7C%20RMX3701-555?style=flat-square)
![Root](https://img.shields.io/badge/root-APatch%20tested-orange?style=flat-square)
![Shell](https://img.shields.io/badge/runtime-POSIX%20shell-lightgrey?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Telemetry](https://img.shields.io/badge/telemetry-none-success?style=flat-square)

[Русская документация](README_RU.md) · [Releases](https://github.com/lolokeksu/neorender-engine/releases) · [Issues](https://github.com/lolokeksu/neorender-engine/issues) · [Security](SECURITY.md)

</div>

NeoRender Engine is a systemless root module that manages Android's **HWUI/Skia renderer selection** through `debug.hwui.renderer`. It provides safe Stock, SkiaGL and SkiaVK profiles, controlled per-application launch sessions, paired A/B measurements, diagnostics, rollback protection and a Russian interactive terminal menu.

> [!IMPORTANT]
> NeoRender controls Android HWUI. It does **not** convert Unity, Unreal Engine or another native game renderer from OpenGL ES to Vulkan. It does not replace GPU drivers, change CPU/GPU frequencies, disable thermal limits or modify boot partitions.

## Supported environment

| Component | Supported status |
|---|---|
| Device | Realme GT Neo 5 SE (`RMX3700`, `RMX3701`) |
| Android | Android 13 / API 33 |
| Platform | Qualcomm Snapdragon / Adreno with hardware Vulkan |
| Root manager | APatch tested; Magisk module layout is used |
| Zygisk | Not required |
| BusyBox module | Not required |
| Termux packages | Not required |
| SELinux | Enforcing is supported and expected |

The installer intentionally rejects other devices, Android versions and emulators. Compatibility is not inferred from “Android 13” or “Qualcomm” alone.

## What it actually changes

NeoRender changes one Android system property:

```text
debug.hwui.renderer
```

Profiles map to these values:

| Profile | Effective action |
|---|---|
| `stock` | Restore the captured OEM value; on the tested firmware it is empty |
| `compatibility` | Set `debug.hwui.renderer=skiagl` for newly created processes |
| `vulkan` | Set `debug.hwui.renderer=skiavk` for newly created processes |

The renderer is selected when a process initializes HWUI. Changing the property does not retrofit an already running process. Per-application sessions therefore stop and recreate the selected application, then restore the global property.

## Features

- Strict RMX3700/RMX3701 and Android 13 validation.
- Stock, SkiaGL and experimental global SkiaVK profiles.
- Per-application SkiaGL/SkiaVK launch transactions.
- Crash-safe restoration of temporary renderer changes.
- Paired SkiaGL versus SkiaVK A/B measurements using `dumpsys gfxinfo`.
- Recommendations tied to the current Android build fingerprint.
- Renderer-profile quarantine instead of automatic module disable.
- OEM baseline capture and restoration after uninstall or rollback.
- Conflict scan for other modules that modify graphics properties.
- Runtime SHA-256 integrity verification.
- Local diagnostics, boot history, reports and support bundles.
- Interactive Russian menu available through one command: `neorender`.
- No APK, native ELF binary, network downloader or telemetry.

## Requirements and warnings

Before installation:

1. Keep a known-working module ZIP available locally.
2. Ensure you can disable a module from recovery by creating `/data/adb/modules/neorender-engine/disable`.
3. Disable other modules that force `debug.hwui.renderer`, `debug.renderengine.backend`, SkiaGL or SkiaVK.
4. Do not treat a Skia result as proof of higher 3D game FPS.

The global `vulkan` profile is experimental on Realme UI. Physical testing showed that per-application SkiaVK works, while global SkiaVK can trigger late SystemUI restarts on some firmware states. The default profile is therefore `stock`.

## Download

Stable packages are published on the [GitHub Releases page](https://github.com/lolokeksu/neorender-engine/releases). Install only the ZIP attached to a release and verify its accompanying `.sha256` file.

Do not flash repository source archives such as “Source code (zip)”. They are not Magisk/APatch module packages.

## Installation

1. Download the release ZIP.
2. Open APatch or Magisk module management.
3. Select **Install from storage** and choose the ZIP.
4. Reboot.
5. Open Termux and run:

```sh
neorender
```

The first boot after a fresh install or an update from an active global Vulkan profile is validated in Stock mode.

## Quick start

Check the module after boot:

```sh
su -c neorenderctl status
su -c neorenderctl doctor
su -c neorenderctl self-check
```

Open the interactive menu:

```sh
neorender
```

Select a global profile:

```sh
su -c neorenderctl profile stock
su -c neorenderctl profile compatibility
su -c neorenderctl profile vulkan
```

A reboot is recommended after a global profile change because existing processes keep the renderer selected at their creation time.

## Per-application renderer sessions

Launch Android Settings with SkiaVK without leaving the global property forced:

```sh
su -c neorenderctl app launch com.android.settings skiavk
```

Verify the running process:

```sh
su -c neorenderctl verify com.android.settings
```

A successful Vulkan session reports:

```text
Pipeline=Skia (Vulkan)
```

Save a persistent launch preference:

```sh
su -c neorenderctl app set com.android.settings skiagl
su -c neorenderctl app list
su -c neorenderctl app launch com.android.settings
```

Per-application launch uses `force-stop`. Unsaved application state may be lost.

## Paired A/B measurement

Start the SkiaGL phase:

```sh
su -c neorenderctl bench pair start com.android.settings
```

Perform a repeatable UI scenario for at least 20–30 seconds, then start the SkiaVK phase:

```sh
su -c neorenderctl bench pair next com.android.settings
```

Repeat the same scenario and finish:

```sh
su -c neorenderctl bench pair finish com.android.settings
su -c neorenderctl recommend show com.android.settings
```

The result may be `skiagl`, `skiavk` or `inconclusive`. A recommendation is not applied globally and is invalidated by a different build fingerprint.

## Configuration

The installed configuration is stored at:

```text
/data/adb/neorender-engine/config.conf
```

The packaged defaults are in `module/config.conf.default` in the source repository.

Important keys:

| Key | Default | Purpose |
|---|---:|---|
| `PROFILE` | `stock` | Global profile |
| `BOOT_GUARD` | `1` | Enable boot validation |
| `STABILITY_DELAY_SECONDS` | `60` | Delay after `sys.boot_completed` |
| `WATCHDOG_SECONDS` | `120` | Non-Stock observation period |
| `STOCK_WATCHDOG_SECONDS` | `30` | Stock observation period |
| `SYSTEMUI_RESTART_LIMIT` | `4` | Quarantine threshold for PID changes |
| `PROPERTY_OVERRIDE_LIMIT` | `3` | Quarantine threshold for property conflicts |
| `DEFAULT_APP_RENDERER` | `skiavk` | Default per-app renderer |
| `BENCH_MIN_FRAMES` | `120` | Minimum A/B sample size |
| `BENCH_IMPROVEMENT_PERCENT` | `5` | Required improvement threshold |

Validate configuration after editing:

```sh
su -c neorenderctl config validate
```

## Diagnostics

```sh
su -c neorenderctl status
su -c neorenderctl doctor
su -c neorenderctl conflicts
su -c neorenderctl self-check
su -c neorenderctl history 50
su -c neorenderctl logs 300
su -c neorenderctl report
su -c neorenderctl support
```

Runtime data is stored under:

```text
/data/adb/neorender-engine
```

Support bundles remain local. Review them before publishing because they may contain the build fingerprint and package names.

## Troubleshooting

### Black screen or SystemUI restart after global SkiaVK

NeoRender should restore the OEM renderer, set `PROFILE=stock`, quarantine the failing profile and request a Stock reboot while leaving the module enabled.

Inspect the reason:

```sh
su -c neorenderctl quarantine show
su -c neorenderctl history 50
su -c neorenderctl logs 300
```

Reboot once in Stock. Do not immediately re-enable global SkiaVK.

### `self-check` reports `FAILED`

Reinstall the exact release ZIP. Do not edit installed runtime files before verifying integrity.

### Another module overrides the renderer

```sh
su -c neorenderctl conflicts
```

Disable every module that modifies HWUI, SurfaceFlinger, Vulkan or graphics properties, then reboot and test again.

### Foreground package is unknown

Realme UI can expose foreground activity information differently. Supply the package name explicitly to `verify`, `app launch` or benchmark commands.

## Emergency recovery

From a working Android session:

```sh
su -c neorenderctl safe disable
su -c reboot
```

From recovery with decrypted `/data`:

```sh
touch /data/adb/modules/neorender-engine/disable
reboot
```

The uninstall script restores the captured OEM renderer and removes transient transactions.

## Security and privacy

The release contains only readable shell scripts and documentation. It includes no APK, ELF executable, shared library, remote code loader, telemetry, certificate modification, DNS replacement, SELinux disable command or boot-partition writer.

See [SECURITY.md](SECURITY.md) for reporting guidance.

## Building from source

Requirements on the build host:

- POSIX shell;
- BusyBox with `ash` for compatibility validation;
- `zip`;
- `sha256sum`.

Build and test:

```sh
./scripts/test.sh
./scripts/build.sh
```

Artifacts are written to `dist/`. The build script regenerates `SHA256SUMS` and `RUNTIME_SHA256SUMS`, creates a root-level module ZIP, validates it with `unzip -t` and writes the ZIP SHA-256 file.

GitHub Actions runs the same scripts. Tagged builds can be attached to GitHub Releases without a separate manual repackaging step.

## Source origin and attribution

NeoRender Engine v1.0.0 is an independent clean implementation maintained by **Lolokeksu**. It does not contain the abandoned closed `core-render` executable or the legacy `Toast.apk`. The runtime behavior is implemented in readable POSIX shell.

The documentation layout was informed by mature Android-root projects:

- LSPosed: concise project introduction, support matrix, installation and release navigation;
- Advanced Charging Controller: operational quick start, configuration, diagnostics and troubleshooting;
- Play Integrity Fork: precise scope, dependencies, compatibility warnings and source attribution;
- BusyBox for Android NDK: reproducible build and artifact verification emphasis.

No source code from those projects is included in NeoRender Engine.

## Author and support

Author and maintainer: **Lolokeksu**

Use [GitHub Issues](https://github.com/lolokeksu/neorender-engine/issues) for reproducible bugs and compatibility reports. Include `neorenderctl doctor`, relevant history/log lines and exact firmware information.

## License

NeoRender Engine is released under the [MIT License](LICENSE).
