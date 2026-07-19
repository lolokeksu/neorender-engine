<div align="center">

# NeoRender Engine

**Прозрачное управление HWUI-рендерером для Realme GT Neo 5 SE на Android 13**

[![Релиз](https://img.shields.io/github/v/release/lolokeksu/neorender-engine?display_name=tag&sort=semver&style=flat-square)](https://github.com/lolokeksu/neorender-engine/releases/latest)
[![Проверка](https://github.com/lolokeksu/neorender-engine/actions/workflows/validate.yml/badge.svg)](https://github.com/lolokeksu/neorender-engine/actions/workflows/validate.yml)
![Android](https://img.shields.io/badge/Android-13-3ddc84?style=flat-square&logo=android&logoColor=white)
![Устройство](https://img.shields.io/badge/device-RMX3700%20%7C%20RMX3701-555?style=flat-square)
![Root](https://img.shields.io/badge/root-APatch%20tested-orange?style=flat-square)
![Shell](https://img.shields.io/badge/runtime-POSIX%20shell-lightgrey?style=flat-square)
![Лицензия](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Телеметрия](https://img.shields.io/badge/telemetry-none-success?style=flat-square)

[English](README.md) · [Релизы](https://github.com/lolokeksu/neorender-engine/releases) · [Проблемы](https://github.com/lolokeksu/neorender-engine/issues) · [Безопасность](SECURITY.md)

</div>

NeoRender Engine — systemless root-модуль для управления выбором **Android HWUI/Skia renderer** через свойство `debug.hwui.renderer`. Модуль предоставляет безопасный Stock-профиль, SkiaGL, SkiaVK, контролируемые сессии отдельных приложений, парные A/B-измерения, диагностику, автоматический откат и русскоязычное меню Termux.

> [!IMPORTANT]
> NeoRender управляет Android HWUI. Он **не переводит** Unity, Unreal Engine или другой собственный игровой renderer с OpenGL ES на Vulkan. Модуль не заменяет GPU-драйвер, не повышает частоты CPU/GPU, не отключает термоконтроль и не изменяет загрузочные разделы.

## Поддерживаемая среда

| Компонент | Поддержка |
|---|---|
| Устройство | Realme GT Neo 5 SE (`RMX3700`, `RMX3701`) |
| Android | Android 13 / API 33 |
| Платформа | Qualcomm Snapdragon / Adreno с аппаратным Vulkan |
| Root-менеджер | APatch протестирован; используется структура Magisk-модуля |
| Zygisk | Не требуется |
| Отдельный BusyBox-модуль | Не требуется |
| Пакеты Termux | Не требуются |
| SELinux | Поддерживается и ожидается режим Enforcing |

Установщик намеренно отклоняет другие устройства, версии Android и эмуляторы. Совместимость не определяется только по словам «Android 13» или «Qualcomm».

## Что модуль реально изменяет

NeoRender изменяет одно системное свойство Android:

```text
debug.hwui.renderer
```

Профили соответствуют следующим действиям:

| Профиль | Фактическое действие |
|---|---|
| `stock` | Восстановление сохранённого OEM-значения; на протестированной прошивке оно пустое |
| `compatibility` | `debug.hwui.renderer=skiagl` для новых процессов |
| `vulkan` | `debug.hwui.renderer=skiavk` для новых процессов |

Renderer выбирается при инициализации HWUI внутри процесса. Изменение свойства не переключает уже работающий процесс. Поэтому персональная сессия останавливает и заново запускает выбранное приложение, после чего восстанавливает глобальное свойство.

## Возможности

- Строгая проверка RMX3700/RMX3701 и Android 13.
- Профили Stock, SkiaGL и экспериментальный глобальный SkiaVK.
- Персональный запуск приложений с SkiaGL/SkiaVK.
- Транзакционное восстановление временного renderer после сбоя команды.
- Парное сравнение SkiaGL и SkiaVK через `dumpsys gfxinfo`.
- Рекомендации, привязанные к build fingerprint прошивки.
- Карантин нестабильного renderer-профиля вместо автоматического отключения модуля.
- Сохранение и восстановление исходного OEM renderer.
- Поиск конфликтующих графических модулей.
- Runtime-проверка SHA-256.
- Локальные отчёты, история загрузок и support bundle.
- Русскоязычное меню одной командой: `neorender`.
- Отсутствие APK, закрытого ELF-бинарника, сетевой загрузки и телеметрии.

## Требования и предупреждения

Перед установкой:

1. Сохраните рабочий ZIP модуля локально.
2. Убедитесь, что из recovery можно создать `/data/adb/modules/neorender-engine/disable`.
3. Отключите модули, принудительно меняющие `debug.hwui.renderer`, `debug.renderengine.backend`, SkiaGL или SkiaVK.
4. Не считайте результат Skia доказательством роста 3D-FPS в игре.

Глобальный профиль `vulkan` экспериментален на Realme UI. Физический тест подтвердил работу персонального SkiaVK, но глобальный SkiaVK на некоторых состояниях прошивки вызывал поздние перезапуски SystemUI. Поэтому профиль по умолчанию — `stock`.

## Загрузка

Готовые пакеты публикуются на странице [GitHub Releases](https://github.com/lolokeksu/neorender-engine/releases). Устанавливайте только ZIP, прикреплённый к релизу, и проверяйте соответствующий файл `.sha256`.

Не прошивайте автоматически создаваемые GitHub-архивы «Source code (zip)»: это исходный код, а не устанавливаемый модуль.

## Установка

1. Скачайте релизный ZIP.
2. Откройте управление модулями APatch или Magisk.
3. Выберите установку из хранилища и укажите ZIP.
4. Перезагрузите устройство.
5. Откройте Termux и выполните:

```sh
neorender
```

Первая загрузка после чистой установки или обновления с активного глобального Vulkan выполняется в Stock для проверки стабильности.

## Быстрый старт

Проверка после загрузки:

```sh
su -c neorenderctl status
su -c neorenderctl doctor
su -c neorenderctl self-check
```

Запуск меню:

```sh
neorender
```

Выбор глобального профиля:

```sh
su -c neorenderctl profile stock
su -c neorenderctl profile compatibility
su -c neorenderctl profile vulkan
```

После глобального переключения рекомендуется перезагрузка: уже работающие процессы сохраняют renderer, выбранный при их создании.

## Персональные renderer-сессии

Запуск Android Settings с SkiaVK без постоянного глобального свойства:

```sh
su -c neorenderctl app launch com.android.settings skiavk
```

Проверка процесса:

```sh
su -c neorenderctl verify com.android.settings
```

Успешная Vulkan-сессия показывает:

```text
Pipeline=Skia (Vulkan)
```

Сохранение персонального профиля:

```sh
su -c neorenderctl app set com.android.settings skiagl
su -c neorenderctl app list
su -c neorenderctl app launch com.android.settings
```

Персональный запуск использует `force-stop`. Несохранённое состояние приложения может быть потеряно.

## Парный A/B-тест

Начало SkiaGL-фазы:

```sh
su -c neorenderctl bench pair start com.android.settings
```

Выполните повторяемый сценарий интерфейса не менее 20–30 секунд, затем включите фазу SkiaVK:

```sh
su -c neorenderctl bench pair next com.android.settings
```

Повторите тот же сценарий и завершите тест:

```sh
su -c neorenderctl bench pair finish com.android.settings
su -c neorenderctl recommend show com.android.settings
```

Результат: `skiagl`, `skiavk` или `inconclusive`. Рекомендация не применяется глобально и становится недействительной после смены build fingerprint.

## Конфигурация

Рабочая конфигурация:

```text
/data/adb/neorender-engine/config.conf
```

Исходные значения в репозитории: `module/config.conf.default`.

Основные параметры:

| Параметр | По умолчанию | Назначение |
|---|---:|---|
| `PROFILE` | `stock` | Глобальный профиль |
| `BOOT_GUARD` | `1` | Проверка успешной загрузки |
| `STABILITY_DELAY_SECONDS` | `60` | Задержка после `sys.boot_completed` |
| `WATCHDOG_SECONDS` | `120` | Контроль non-Stock профиля |
| `STOCK_WATCHDOG_SECONDS` | `30` | Контроль Stock |
| `SYSTEMUI_RESTART_LIMIT` | `4` | Порог карантина при сменах PID SystemUI |
| `PROPERTY_OVERRIDE_LIMIT` | `3` | Порог конфликта свойства |
| `DEFAULT_APP_RENDERER` | `skiavk` | Renderer персонального запуска |
| `BENCH_MIN_FRAMES` | `120` | Минимальный размер выборки A/B |
| `BENCH_IMPROVEMENT_PERCENT` | `5` | Минимальное улучшение для рекомендации |

После ручного редактирования:

```sh
su -c neorenderctl config validate
```

## Диагностика

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

Рабочие данные находятся в:

```text
/data/adb/neorender-engine
```

Support bundle никуда не отправляется. Перед публикацией проверьте его: он может содержать build fingerprint и имена пакетов.

## Решение проблем

### Чёрный экран или перезапуск SystemUI после глобального SkiaVK

NeoRender должен восстановить OEM renderer, установить `PROFILE=stock`, поместить проблемный профиль в карантин и запросить Stock-перезагрузку, не отключая сам модуль.

Проверка причины:

```sh
su -c neorenderctl quarantine show
su -c neorenderctl history 50
su -c neorenderctl logs 300
```

Один раз перезагрузитесь в Stock. Не включайте глобальный SkiaVK повторно без анализа отчёта.

### `self-check` показывает `FAILED`

Переустановите точный ZIP релиза. Не изменяйте runtime-файлы до проверки целостности.

### Другой модуль перезаписывает renderer

```sh
su -c neorenderctl conflicts
```

Отключите модули, меняющие HWUI, SurfaceFlinger, Vulkan или графические свойства, затем перезагрузитесь.

### Не определяется активное приложение

Realme UI может иначе публиковать информацию об activity. Укажите package name явно в командах `verify`, `app launch` или benchmark.

## Аварийное восстановление

Из работающего Android:

```sh
su -c neorenderctl safe disable
su -c reboot
```

Из recovery с расшифрованным `/data`:

```sh
touch /data/adb/modules/neorender-engine/disable
reboot
```

При удалении модуль восстанавливает OEM renderer и очищает временные транзакции.

## Безопасность и приватность

Релиз содержит читаемые shell-скрипты и документацию. В нём нет APK, ELF, `.so`, удалённой загрузки кода, телеметрии, подмены сертификатов, DNS, отключения SELinux или записи в загрузочные разделы.

Правила сообщения об уязвимостях: [SECURITY.md](SECURITY.md).

## Самостоятельная сборка

Требования к компьютеру:

- POSIX shell;
- BusyBox с `ash` для проверки совместимости;
- `zip`;
- `sha256sum`.

Сборка:

```sh
./scripts/test.sh
./scripts/build.sh
```

Артефакты создаются в `dist/`. Скрипт заново формирует `SHA256SUMS` и `RUNTIME_SHA256SUMS`, собирает ZIP с файлами модуля в корне, выполняет `unzip -t` и записывает SHA-256 архива.

GitHub Actions запускает те же скрипты. Тегированный релиз можно публиковать без отдельной ручной перепаковки.

## Происхождение и авторство кода

NeoRender Engine v1.0.0 — самостоятельная чистая реализация автора **Lolokeksu**. Модуль не содержит закрытый исполняемый файл заброшенного `core-render` и не включает старый `Toast.apk`. Вся рабочая логика реализована читаемыми POSIX shell-скриптами.

Структура документации спроектирована с учётом практик зрелых Android-root-проектов:

- LSPosed: краткое введение, таблица поддержки, установка и навигация по релизам;
- Advanced Charging Controller: быстрый старт, конфигурация, диагностика и troubleshooting;
- Play Integrity Fork: точная граница воздействия, зависимости, предупреждения и прозрачное происхождение;
- BusyBox for Android NDK: воспроизводимая сборка и проверка артефактов.

Исходный код перечисленных проектов в NeoRender Engine не включён.

## Автор и поддержка

Автор и сопровождающий: **Lolokeksu**

Для воспроизводимых ошибок и отчётов совместимости используйте [GitHub Issues](https://github.com/lolokeksu/neorender-engine/issues). Прикладывайте `neorenderctl doctor`, необходимые строки истории/лога и точную версию прошивки.

## Лицензия

NeoRender Engine распространяется по [лицензии MIT](LICENSE).
