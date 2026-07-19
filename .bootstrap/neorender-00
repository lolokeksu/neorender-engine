#!/system/bin/sh

# NeoRender Engine interactive control center.
# POSIX/BusyBox ash compatible; no Termux packages are required.

SELF="$0"
MODULE_DIR=/data/adb/modules/neorender-engine
STATE_DIR=/data/adb/neorender-engine

if [ "$(id -u 2>/dev/null)" != 0 ]; then
    echo 'NeoRender Engine: запрашиваю root-доступ Magisk...'
    exec su -c "$SELF"
    echo 'ERROR: root-доступ не получен.'
    exit 1
fi

find_ctl() {
    for candidate in \
        "$MODULE_DIR/neorenderctl" \
        "$MODULE_DIR/system/bin/neorenderctl" \
        /system/bin/neorenderctl; do
        [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
    done
    command -v neorenderctl 2>/dev/null
}

CTL="$(find_ctl)"
[ -n "$CTL" ] && [ -x "$CTL" ] || {
    echo 'ERROR: neorenderctl не найден. Переустановите модуль и перезагрузите устройство.'
    exit 1
}

if [ -t 1 ]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_BLUE='\033[36m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
else
    C_RESET=''; C_BOLD=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

line() { printf '%s\n' '────────────────────────────────────────────────────────'; }
clear_screen() { if [ -t 1 ] && [ -n "${TERM:-}" ] && command -v clear >/dev/null 2>&1; then clear 2>/dev/null || printf '\n\n'; else printf '\n\n'; fi; }
pause() { printf '\nНажмите Enter для продолжения... '; IFS= read -r _pause_value; }

read_choice() {
    printf '%s' "$1"
    IFS= read -r MENU_CHOICE
}

confirm() {
    printf '%s [y/N]: ' "$1"
    IFS= read -r answer
    case "$answer" in y|Y|yes|YES|д|Д|да|ДА) return 0 ;; *) return 1 ;; esac
}

config_value() {
    key="$1"; fallback="$2"
    value="$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$STATE_DIR/config.conf" 2>/dev/null | tail -n 1)"
    [ -n "$value" ] && printf '%s\n' "$value" || printf '%s\n' "$fallback"
}

active_pair_package() { cat "$STATE_DIR/bench/pair/active/package" 2>/dev/null; }
active_bench_package() { cat "$STATE_DIR/bench/active/package" 2>/dev/null; }

top_package_menu() {
    pkg="$(dumpsys activity activities 2>/dev/null | sed -nE 's/.*mResumedActivity:.* ([A-Za-z0-9._]+)\/.*/\1/p' | head -n 1)"
    [ -n "$pkg" ] || pkg="$(dumpsys window windows 2>/dev/null | sed -nE 's/.*mCurrentFocus=.* ([A-Za-z0-9._]+)\/.*/\1/p' | head -n 1)"
    printf '%s\n' "$pkg"
}

package_exists_menu() { pm path "$1" >/dev/null 2>&1; }

select_package() {
    current="$(top_package_menu)"
    [ -n "$current" ] && echo "Текущее приложение: $current"
    echo "Введите package name; Enter — текущее приложение; ? — поиск по названию."
    printf '> '
    IFS= read -r selected
    [ -n "$selected" ] || selected="$current"

    if [ "$selected" = '?' ]; then
        printf 'Строка поиска: '
        IFS= read -r query
        [ -n "$query" ] || { echo 'Поиск отменён.'; return 1; }
        echo
        matches="$(pm list packages 2>/dev/null | sed 's/^package://' | grep -i -- "$query" | head -n 30)"
        if [ -z "$matches" ]; then
            echo 'Совпадений не найдено.'
            return 1
        fi
        printf '%s\n' "$matches"
        echo
        printf 'Скопируйте точный package name из списка: '
        IFS= read -r selected
    fi

    [ -n "$selected" ] || { echo 'Package name не выбран.'; return 1; }
    package_exists_menu "$selected" || { echo "Пакет не установлен: $selected"; return 1; }
    SELECTED_PACKAGE="$selected"
    return 0
}

select_renderer() {
    echo '1) SkiaGL — максимальная совместимость'
    echo '2) SkiaVK — Vulkan HWUI'
    read_choice 'Renderer: '
    case "$MENU_CHOICE" in
        1) SELECTED_RENDERER=skiagl ;;
        2) SELECTED_RENDERER=skiavk ;;
        *) echo 'Неверный выбор.'; return 1 ;;
    esac
}

header() {
    profile="$(config_value PROFILE unknown)"
    active="$(getprop debug.hwui.renderer 2>/dev/null)"
    [ -n "$active" ] || active='<OEM/пусто>'
    if [ -f "$MODULE_DIR/disable" ]; then module_state='ОТКЛЮЧЁН'; state_color="$C_RED"; else module_state='активен'; state_color="$C_GREEN"; fi
    clear_screen
    printf '%b%s%b\n' "$C_BOLD$C_BLUE" 'NeoRender Engine — центр управления' "$C_RESET"
    line
    printf 'Профиль: %b%s%b | Renderer: %s | Модуль: %b%s%b\n' \
        "$C_BOLD" "$profile" "$C_RESET" "$active" "$state_color" "$module_state" "$C_RESET"
    if [ -f "$STATE_DIR/state/profile-quarantine.txt" ]; then
        printf '%b%s%b\n' "$C_YELLOW" 'Карантин профиля: активен; глобальный режим возвращён в Stock' "$C_RESET"
    fi
    if [ -f "$STATE_DIR/state/reboot-stock-required" ]; then
        printf '%b%s%b\n' "$C_RED" 'Требуется перезагрузка в Stock' "$C_RESET"
    fi
    line
}

run_and_pause() {
    echo
    "$CTL" "$@"
    rc=$?
    [ "$rc" -eq 0 ] || printf '%bКоманда завершилась с кодом %s.%b\n' "$C_RED" "$rc" "$C_RESET"
    pause
    return "$rc"
}

profile_menu() {
    while :; do
        header
        echo 'ГЛОБАЛЬНЫЙ ПРОФИЛЬ'
        echo '1) Stock — настройки прошивки Realme'
        echo '2) Compatibility — SkiaGL'
        echo '3) Vulkan — SkiaVK (экспериментально для всей системы)'
        echo '4) Повторно применить текущий профиль'
        echo '5) Проверить активное приложение'
        echo '6) Перезагрузить устройство'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) run_and_pause profile stock ;;
            2) run_and_pause profile compatibility ;;
            3) if confirm 'Включить глобальный SkiaVK? На Realme UI возможен временный чёрный экран.'; then run_and_pause profile vulkan; fi ;;
            4) run_and_pause apply ;;
            5) run_and_pause verify ;;
            6) if confirm 'Перезагрузить устройство сейчас?'; then reboot; exit 0; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

app_menu() {
    while :; do
        header
        echo 'ПРОФИЛИ И ЗАПУСК ПРИЛОЖЕНИЙ'
        echo '1) Показать сохранённые профили'
        echo '2) Назначить приложению SkiaGL/SkiaVK'
        echo '3) Запустить приложение с сохранённым профилем'
        echo '4) Разовый запуск с выбранным renderer'
        echo '5) Проверить HWUI pipeline приложения'
        echo '6) Удалить профиль приложения'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) run_and_pause app list ;;
            2) if select_package && select_renderer; then run_and_pause app set "$SELECTED_PACKAGE" "$SELECTED_RENDERER"; else pause; fi ;;
            3) if select_package; then run_and_pause app launch "$SELECTED_PACKAGE"; else pause; fi ;;
            4) if select_package && select_renderer; then run_and_pause app launch "$SELECTED_PACKAGE" "$SELECTED_RENDERER"; else pause; fi ;;
            5) if select_package; then run_and_pause verify "$SELECTED_PACKAGE"; else pause; fi ;;
            6) if select_package; then if confirm "Удалить профиль $SELECTED_PACKAGE?"; then run_and_pause app remove "$SELECTED_PACKAGE"; fi; else pause; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

pair_menu() {
    while :; do
        header
        echo 'ПАРНЫЙ A/B-ТЕСТ SKIAGL ↔ SKIAVK'
        echo '1) Начать фазу 1 — SkiaGL'
        echo '2) Завершить SkiaGL и начать фазу 2 — SkiaVK'