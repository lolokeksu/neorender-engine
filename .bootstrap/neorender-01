        echo '3) Завершить тест и получить рекомендацию'
        echo '4) Состояние теста'
        echo '5) Отменить тест'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) if select_package; then run_and_pause bench pair start "$SELECTED_PACKAGE"; else pause; fi ;;
            2) pkg="$(active_pair_package)"; if [ -n "$pkg" ]; then run_and_pause bench pair next "$pkg"; else echo 'Активный A/B-тест не найден.'; pause; fi ;;
            3) pkg="$(active_pair_package)"; if [ -n "$pkg" ]; then run_and_pause bench pair finish "$pkg"; else echo 'Активный A/B-тест не найден.'; pause; fi ;;
            4) run_and_pause bench pair status ;;
            5) if confirm 'Сбросить текущий A/B-тест?'; then run_and_pause bench pair abort; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

single_bench_menu() {
    while :; do
        header
        echo 'ОБЫЧНЫЙ BENCHMARK И GFXINFO'
        echo '1) Начать benchmark'
        echo '2) Завершить benchmark'
        echo '3) Состояние benchmark'
        echo '4) Сбросить gfxinfo приложения'
        echo '5) Сохранить gfxinfo framestats'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) if select_package && select_renderer; then run_and_pause bench start "$SELECTED_PACKAGE" "$SELECTED_RENDERER"; else pause; fi ;;
            2) pkg="$(active_bench_package)"; if [ -n "$pkg" ]; then run_and_pause bench stop "$pkg"; else echo 'Активный benchmark не найден.'; pause; fi ;;
            3) run_and_pause bench status ;;
            4) if select_package; then run_and_pause gfx reset "$SELECTED_PACKAGE"; else pause; fi ;;
            5) if select_package; then run_and_pause gfx capture "$SELECTED_PACKAGE"; else pause; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

benchmark_menu() {
    while :; do
        header
        echo 'ТЕСТИРОВАНИЕ'
        echo '1) Парный A/B-тест SkiaGL и SkiaVK'
        echo '2) Обычный benchmark и gfxinfo'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) pair_menu ;;
            2) single_bench_menu ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

recommend_menu() {
    while :; do
        header
        echo 'РЕКОМЕНДАЦИИ A/B-ТЕСТА'
        echo '1) Показать все рекомендации'
        echo '2) Показать рекомендацию приложения'
        echo '3) Применить рекомендацию как профиль приложения'
        echo '4) Удалить рекомендацию'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) run_and_pause recommend list ;;
            2) if select_package; then run_and_pause recommend show "$SELECTED_PACKAGE"; else pause; fi ;;
            3) if select_package; then run_and_pause recommend apply "$SELECTED_PACKAGE"; else pause; fi ;;
            4) if select_package; then if confirm "Удалить рекомендацию $SELECTED_PACKAGE?"; then run_and_pause recommend remove "$SELECTED_PACKAGE"; fi; else pause; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

diagnostics_menu() {
    while :; do
        header
        echo 'ДИАГНОСТИКА'
        echo '1) Краткий статус'
        echo '2) Полная проверка Doctor'
        echo '3) Проверка целостности файлов'
        echo '4) Проверка конфигурации'
        echo '5) Поиск конфликтующих модулей'
        echo '6) Создать и показать системный отчёт'
        echo '7) Создать support bundle'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) run_and_pause status ;;
            2) run_and_pause doctor ;;
            3) run_and_pause self-check ;;
            4) run_and_pause config validate ;;
            5) run_and_pause conflicts ;;
            6) run_and_pause report ;;
            7) run_and_pause support ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

maintenance_menu() {
    while :; do
        header
        echo 'ОБСЛУЖИВАНИЕ И БЕЗОПАСНОСТЬ'
        echo '1) Последние 120 строк журнала'
        echo '2) История загрузок и откатов'
        echo '3) Пути файлов модуля'
        echo '4) Создать резервную копию настроек'
        echo '5) Сбросить конфигурацию к значениям V2'
        echo '6) Аварийно отключить модуль и восстановить OEM'
        echo '7) Очистить safe mode и включить модуль'
        echo '8) Показать/очистить карантин renderer-профиля'
        echo '9) Перезагрузить устройство'
        echo '0) Назад'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) run_and_pause logs 120 ;;
            2) run_and_pause history 30 ;;
            3) run_and_pause paths ;;
            4) run_and_pause backup ;;
            5) if confirm 'Сбросить конфигурацию? Перед сбросом будет создан backup.'; then run_and_pause config reset; fi ;;
            6) if confirm 'Отключить модуль и восстановить OEM renderer?'; then run_and_pause safe disable; fi ;;
            7) if confirm 'Очистить safe mode и маркер disable?'; then run_and_pause safe clear; fi ;;
            8) echo; "$CTL" quarantine show; if confirm 'Очистить карантин профиля?'; then run_and_pause quarantine clear; else pause; fi ;;
            9) if confirm 'Перезагрузить устройство сейчас?'; then reboot; exit 0; fi ;;
            0) return ;;
            *) pause ;;
        esac
    done
}

help_screen() {
    header
    cat <<'HELP'
КАК ПОЛЬЗОВАТЬСЯ

1. Для обычного использования выберите «Глобальный профиль»:
   • Stock — штатное поведение Realme UI.
   • Compatibility — SkiaGL, если Vulkan вызывает ошибки.
   • Vulkan — экспериментальный SkiaVK для новых Android HWUI-процессов.
     NeoRender при признаках нестабильности переводит профиль в Stock,
     но не отключает меню и диагностические функции модуля.

2. После глобального переключения рекомендуется перезагрузка.

3. «Профили приложений» выполняют force-stop выбранного приложения,
   запускают его заново с renderer и затем восстанавливают глобальное
   свойство. Несохранённые данные приложения могут быть потеряны.

4. A/B-тест:
   • начните SkiaGL-фазу;
   • выполните одинаковый сценарий не менее 20–30 секунд;
   • переключите на SkiaVK и повторите тот же сценарий;
   • завершите тест и примените только достоверную рекомендацию.

5. NeoRender управляет Android HWUI. Он не переводит собственный движок
   Unity/Unreal с OpenGL ES на Vulkan и не повышает частоты CPU/GPU.

После установки v1.0.0 первая загрузка выполняется в Stock для проверки стабильности.
Рекомендуется сначала проверить SkiaVK через профиль отдельного приложения.

Главная команда Termux: neorender
Резервная команда: su -c neorenderctl help
HELP
    pause
}

main_menu() {
    while :; do
        header
        echo '1) Глобальный профиль'
        echo '2) Профили и запуск приложений'
        echo '3) Тестирование SkiaGL / SkiaVK'
        echo '4) Рекомендации A/B-теста'
        echo '5) Диагностика'
        echo '6) Обслуживание и безопасность'
        echo '7) Инструкция'
        echo '0) Выход'
        read_choice 'Выбор: '
        case "$MENU_CHOICE" in
            1) profile_menu ;;
            2) app_menu ;;
            3) benchmark_menu ;;
            4) recommend_menu ;;
            5) diagnostics_menu ;;
            6) maintenance_menu ;;
            7) help_screen ;;
            0|q|Q) clear_screen; echo 'NeoRender Engine: выход.'; exit 0 ;;
            *) printf '%bНеверный пункт.%b\n' "$C_YELLOW" "$C_RESET"; pause ;;
        esac
    done
}

main_menu
