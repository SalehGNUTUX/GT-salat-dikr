#!/bin/bash
#
# GT-salat-dikr - النسخة المحسّنة النهائية مع خيارات فصل الإشعارات واختيار النظام
# Author: gnutux
#
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_SOURCE_ABS="$SCRIPT_PATH"

AZKAR_FILE="${SCRIPT_DIR}/azkar.txt"
CONFIG_FILE="${SCRIPT_DIR}/settings.conf"
TIMETABLE_FILE="${SCRIPT_DIR}/timetable.json"
PID_FILE="${SCRIPT_DIR}/.gt-salat-dikr-notify.pid"
NOTIFY_LOG="${SCRIPT_DIR}/notify.log"
ADHAN_FILE="${SCRIPT_DIR}/adhan.ogg"
SHORT_ADHAN_FILE="${SCRIPT_DIR}/short_adhan.ogg"
APPROACHING_SOUND="${SCRIPT_DIR}/prayer_approaching.ogg"
ADHAN_PLAYER_SCRIPT="${SCRIPT_DIR}/adhan-player.sh"

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=15
DEFAULT_ADHAN_TYPE="full"
DEFAULT_SALAT_NOTIFY=1
DEFAULT_ZIKR_NOTIFY=1
DEFAULT_NOTIFY_SYSTEM="systemd"

# ---------------- أدوات مساعدة ----------------
log() { 
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

silent_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

fetch_if_missing() {
    local file="$1"; local url="$2"
    if [ ! -f "$file" ]; then
        log "تحميل $file ..."
        if curl -fsSL "$url" -o "$file" 2>/dev/null; then
            log "تم تحميل $file"
        else
            log "فشل تحميل $file من $url"
            return 1
        fi
    fi
    return 0
}

# ---------------- اكتشاف البيئة الرسومية ----------------
detect_gui_tools() {
    GUI_TOOL=""
    if command -v zenity >/dev/null 2>&1; then
        GUI_TOOL="zenity"
    elif command -v yad >/dev/null 2>&1; then
        GUI_TOOL="yad"
    elif command -v kdialog >/dev/null 2>&1; then
        GUI_TOOL="kdialog"
    fi
    silent_log "GUI Tool detected: ${GUI_TOOL:-none}"
}

# ---------------- فحص أدوات النظام ----------------
check_tools() {
    detect_gui_tools
    if ! command -v jq >/dev/null 2>&1; then
        silent_log "تحذير: jq غير مثبت. بعض الميزات (جلب المواعيد) قد تفشل."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        silent_log "تحذير: notify-send غير موجود. الإشعارات لن تعمل بدون libnotify."
    fi
}

# ------------- ضبط DBUS -------------
ensure_dbus() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        return 0
    fi
    local bus="/run/user/$(id -u)/bus"
    if [ -S "$bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        silent_log "DBUS: استخدام المسار القياسي $bus"
        return 0
    fi
    local tmp_bus="/tmp/dbus-$(whoami)"
    if [ -d "$tmp_bus" ]; then
        local sock=$(find "$tmp_bus" -name "session-*" -type s 2>/dev/null | head -1)
        if [ -n "$sock" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$sock"
            silent_log "DBUS: استخدام $sock"
            return 0
        fi
    fi
    local dbus_pid=$(pgrep -u "$(id -u)" dbus-daemon 2>/dev/null | head -1)
    if [ -n "$dbus_pid" ]; then
        local dbus_addr=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$dbus_pid/environ 2>/dev/null | cut -d= -f2- | tr -d '\0')
        if [ -n "$dbus_addr" ]; then
            export DBUS_SESSION_BUS_ADDRESS="$dbus_addr"
            silent_log "DBUS: استخراج من العملية $dbus_pid"
            return 0
        fi
    fi
    silent_log "تحذير: لم يتم العثور على DBUS"
    return 1
}

# ---------------- إعداد/تحميل الإعدادات ----------------
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
LAT="${LAT:-}"
LON="${LON:-}"
CITY="${CITY:-}"
COUNTRY="${COUNTRY:-}"
METHOD_ID="${METHOD_ID:-1}"
METHOD_NAME="${METHOD_NAME:-Muslim World League}"
PRE_PRAYER_NOTIFY=${PRE_PRAYER_NOTIFY:-$DEFAULT_PRE_NOTIFY}
ZIKR_NOTIFY_INTERVAL=${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}
AUTO_SELF_UPDATE=${AUTO_SELF_UPDATE:-0}
ADHAN_TYPE="${ADHAN_TYPE:-$DEFAULT_ADHAN_TYPE}"
ENABLE_SALAT_NOTIFY=${ENABLE_SALAT_NOTIFY:-$DEFAULT_SALAT_NOTIFY}
ENABLE_ZIKR_NOTIFY=${ENABLE_ZIKR_NOTIFY:-$DEFAULT_ZIKR_NOTIFY}
NOTIFY_SYSTEM="${NOTIFY_SYSTEM:-$DEFAULT_NOTIFY_SYSTEM}"
EOF
    log "تم حفظ الإعدادات في $CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# ---------------- اختيار النظام ----------------
choose_notify_system() {
    echo "اختر نظام الخدمة للإشعارات:"
    echo "  1) systemd (موصى به إذا كان متوفرًا)"
    echo "  2) sysvinit (تشغيل بالخلفية - لكل توزيعة)"
    read -p "الاختيار [1]: " sys_choice
    sys_choice=${sys_choice:-1}
    if [ "$sys_choice" = "2" ]; then
        NOTIFY_SYSTEM="sysvinit"
    else
        NOTIFY_SYSTEM="systemd"
    fi
}

# ---------------- إعدادات الإشعارات ----------------
choose_notify_settings() {
    read -p "تفعيل إشعارات الصلاة؟ [Y/n]: " en_salat
    [[ "${en_salat:-Y}" =~ ^[Nn]$ ]] && ENABLE_SALAT_NOTIFY=0 || ENABLE_SALAT_NOTIFY=1
    read -p "تفعيل إشعارات الذكر؟ [Y/n]: " en_zikr
    [[ "${en_zikr:-Y}" =~ ^[Nn]$ ]] && ENABLE_ZIKR_NOTIFY=0 || ENABLE_ZIKR_NOTIFY=1
}

# ---------------- إعدادات المستخدم الأولى ----------------
setup_wizard() {
    echo "=== إعداد GT-salat-dikr ==="
    if auto_detect_location; then
        echo "تم اكتشاف الموقع تلقائيًا: $CITY, $COUNTRY (LAT=$LAT LON=$LON)"
        read -p "هل تريد استخدامه؟ [Y/n]: " ans; ans=${ans:-Y}
        [[ ! "$ans" =~ ^[Yy]$ ]] && manual_location
    else
        echo "تعذر اكتشاف الموقع تلقائيًا – أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    echo ""
    echo "⏰ إعدادات التنبيه قبل الصلاة:"
    read -p "كم دقيقة قبل الصلاة تريد التنبيه؟ [افتراضي 15]: " pre_min
    PRE_PRAYER_NOTIFY=${pre_min:-$DEFAULT_PRE_NOTIFY}
    echo ""
    echo "🔊 اختر نوع الأذان:"
    echo "  1) أذان كامل (adhan.ogg)"
    echo "  2) أذان قصير (short_adhan.ogg)"
    read -p "الاختيار [1]: " adhan_choice
    adhan_choice=${adhan_choice:-1}
    if [ "$adhan_choice" = "2" ]; then
        ADHAN_TYPE="short"
    else
        ADHAN_TYPE="full"
    fi
    read -p "فاصل الأذكار بالثواني (افتراضي $DEFAULT_ZIKR_INTERVAL): " z
    ZIKR_NOTIFY_INTERVAL=${z:-$DEFAULT_ZIKR_INTERVAL}
    read -p "تفعيل التحديث الذاتي؟ [y/N]: " up; up=${up:-N}
    [[ "$up" =~ ^[Yy]$ ]] && AUTO_SELF_UPDATE=1 || AUTO_SELF_UPDATE=0
    choose_notify_system
    choose_notify_settings
    save_config
}

# ---------------- أوامر التحكم في الإشعارات ----------------
enable_salat_notify() { ENABLE_SALAT_NOTIFY=1; save_config; echo "✅ تم تفعيل إشعارات الصلاة."; }
disable_salat_notify() { ENABLE_SALAT_NOTIFY=0; save_config; echo "✅ تم تعطيل إشعارات الصلاة."; }
enable_zikr_notify() { ENABLE_ZIKR_NOTIFY=1; save_config; echo "✅ تم تفعيل إشعارات الذكر."; }
disable_zikr_notify() { ENABLE_ZIKR_NOTIFY=0; save_config; echo "✅ تم تعطيل إشعارات الذكر."; }
enable_all_notify() { ENABLE_SALAT_NOTIFY=1; ENABLE_ZIKR_NOTIFY=1; save_config; echo "✅ تم تفعيل جميع الإشعارات."; }
disable_all_notify() { ENABLE_SALAT_NOTIFY=0; ENABLE_ZIKR_NOTIFY=0; save_config; echo "✅ تم تعطيل جميع الإشعارات."; }

change_notify_system() {
    choose_notify_system
    save_config
    echo "✅ تم تغيير نظام الخدمة إلى: $NOTIFY_SYSTEM"
    echo "💡 أعد تشغيل الإشعارات ليتم تطبيق النظام الجديد."
}

# ---------------- نظام الخدمة ----------------
start_notify_service() {
    if [ "${NOTIFY_SYSTEM:-systemd}" = "systemd" ]; then
        start_notify_bg
    else
        start_notify_sysvinit
    fi
}

stop_notify_service() {
    if [ "${NOTIFY_SYSTEM:-systemd}" = "systemd" ]; then
        stop_notify_bg
    else
        stop_notify_sysvinit
    fi
}

# ---------------- sysvinit ----------------
start_notify_sysvinit() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi
    ensure_dbus
    check_tools
    create_adhan_player
    create_approaching_player
    nohup bash -c "
        cd '$SCRIPT_DIR'
        export DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}'
        export DISPLAY='${DISPLAY:-:0}'
        while true; do
            '$SCRIPT_SOURCE_ABS' --child-notify >> '$NOTIFY_LOG' 2>&1
            sleep 5
        done
    " >/dev/null 2>&1 &
    local child_pid=$!
    echo "$child_pid" > "$PID_FILE"
    disown
    sleep 2
    if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE" 2>/dev/null)" >/dev/null 2>&1; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $(cat "$PID_FILE"))"
        log "started notify loop (PID: $(cat "$PID_FILE"))"
        return 0
    else
        echo "❌ فشل في بدء الإشعارات - راجع السجل: gtsalat --logs"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_notify_sysvinit() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "✅ تم إيقاف الإشعارات"
            return 0
        fi
    fi
    echo "ℹ️ لا يوجد إشعارات قيد التشغيل"
    return 1
}

# ---------------- notify loop ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT INT TERM
    local notify_flag_file="${SCRIPT_DIR}/.last-prayer-notified"
    local pre_notify_flag_file="${SCRIPT_DIR}/.last-preprayer-notified"
    while true; do
        if [ "${ENABLE_ZIKR_NOTIFY:-1}" = "1" ]; then
            show_zekr_notify || true
        fi
        if ! get_next_prayer; then
            sleep 30
            continue
        fi
        local pre_notify_seconds=$((${PRE_PRAYER_NOTIFY:-15} * 60))
        if [ "${ENABLE_SALAT_NOTIFY:-1}" = "1" ]; then
            if [ "$PRAYER_LEFT" -le "$pre_notify_seconds" ] && [ "$PRAYER_LEFT" -gt 0 ]; then
                if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                    show_pre_prayer_notify
                    echo "$PRAYER_NAME" > "$pre_notify_flag_file"
                fi
            fi
            if [ "$PRAYER_LEFT" -le 0 ]; then
                if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                    show_prayer_notify
                    echo "$PRAYER_NAME" > "$notify_flag_file"
                    rm -f "$pre_notify_flag_file" 2>/dev/null
                fi
            fi
        fi
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ] && sleep_for=$((PRAYER_LEFT < 2 ? 2 : PRAYER_LEFT))
        sleep "$sleep_for"
    done
}

# ---------------- child mode ----------------
if [[ "${1:-}" == "--child-notify" ]]; then
    ensure_dbus
    check_tools
    notify_loop
    exit 0
fi

# ---------------- تحميل الإعدادات ----------------
check_tools
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true

if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
else
    load_config || setup_wizard
fi

if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update >/dev/null 2>&1 || true
fi

# ---------------- CLI ----------------
case "${1:-}" in
    --install) install_self ;;
    --uninstall) uninstall_self ;;
    --settings) setup_wizard ;;
    --show-timetable|-t) show_timetable ;;
    --notify-start) start_notify_service ;;
    --notify-stop) stop_notify_service ;;
    --enable-all-notify) enable_all_notify ;;
    --disable-all-notify) disable_all_notify ;;
    --enable-salat-notify) enable_salat_notify ;;
    --disable-salat-notify) disable_salat_notify ;;
    --enable-zikr-notify) enable_zikr_notify ;;
    --disable-zikr-notify) disable_zikr_notify ;;
    --change-notify-system) change_notify_system ;;
    --test-notify)
        ensure_dbus
        notify-send "GT-salat-dikr" "اختبار إشعار ✓" 2>/dev/null && echo "تم إرسال إشعار" || echo "فشل"
        ;;
    --test-adhan)
        ensure_dbus
        create_adhan_player
        play_adhan_gui "اختبار"
        ;;
    --test-approaching)
        ensure_dbus
        create_approaching_player
        play_approaching_notification "اختبار" "15"
        ;;
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE" 2>/dev/null && echo "✅ تم التحديث" || echo "فشل التحديث"
        ;;
    --self-update)
        # نفس كود التحديث السابق
        ;;
    --status)
        # نفس كود الحالة السابق + إظهار حالة الإشعارات المنفصلة والنظام
        echo "📊 حالة GT-salat-dikr:"
        echo "════════════════════════════════════════"
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE" 2>/dev/null)
            if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
                echo "✅ الإشعارات: تعمل (PID: $pid)"
            else
                echo "❌ الإشعارات: متوقفة"
            fi
        else
            echo "❌ الإشعارات: متوقفة"
        fi
        echo ""
        if [ -f "$CONFIG_FILE" ]; then
            load_config
            echo "📍 الموقع: $CITY, $COUNTRY"
            echo "🧭 الإحداثيات: $LAT, $LON"
            echo "📖 طريقة الحساب: $METHOD_NAME"
            echo "⏰ التنبيه قبل الصلاة: ${PRE_PRAYER_NOTIFY} دقيقة"
            echo "🔊 نوع الأذان: ${ADHAN_TYPE}"
            echo "🔔 إشعارات الصلاة: $([ "${ENABLE_SALAT_NOTIFY:-1}" = "1" ] && echo 'مفعلة' || echo 'معطلة')"
            echo "🟢 إشعارات الذكر: $([ "${ENABLE_ZIKR_NOTIFY:-1}" = "1" ] && echo 'مفعلة' || echo 'معطلة')"
            echo "🛠 نظام الخدمة: ${NOTIFY_SYSTEM:-systemd}"
        fi
        echo ""
        if get_next_prayer 2>/dev/null; then
            leftmin=$((PRAYER_LEFT/60))
            lefth=$((leftmin/60))
            leftm=$((leftmin%60))
            echo "🕌 الصلاة القادمة: $PRAYER_NAME"
            echo "⏰ الوقت: $PRAYER_TIME"
            printf "⏳ المتبقي: %02d:%02d\n" "$lefth" "$leftm"
        fi
        ;;
    --help|-h)
        cat <<EOF
════════════════════════════════════════════════════════════
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار
════════════════════════════════════════════════════════════

📦 التثبيت:
  --install           تثبيت البرنامج مع autostart
  --uninstall         إزالة البرنامج

⚙️ الإعدادات:
  --settings          تعديل الموقع والإعدادات
  --change-notify-system  تغيير نظام الخدمة (systemd/sysvinit)

📊 العرض:
  --show-timetable    عرض مواقيت الصلاة
  --status            عرض حالة البرنامج
  --logs              عرض السجل
  --debug             معلومات التشخيص

🔔 الإشعارات:
  --notify-start      بدء الإشعارات حسب النظام المختار
  --notify-stop       إيقاف الإشعارات حسب النظام المختار

🟢 التحكم في الإشعارات:
  --enable-all-notify     تفعيل جميع الإشعارات
  --disable-all-notify    تعطيل جميع الإشعارات
  --enable-salat-notify   تفعيل إشعارات الصلاة فقط
  --disable-salat-notify  تعطيل إشعارات الصلاة فقط
  --enable-zikr-notify    تفعيل إشعارات الذكر فقط
  --disable-zikr-notify   تعطيل إشعارات الذكر فقط

🧪 الاختبار:
  --test-notify       اختبار إشعار
  --test-adhan        اختبار الأذان
  --test-approaching  اختبار تنبيه الاقتراب

🔄 التحديث:
  --update-azkar      تحديث الأذكار
  --self-update       تحديث البرنامج

ℹ️  --help, -h        هذه المساعدة

════════════════════════════════════════════════════════════
💡 الاستخدام الافتراضي: تشغيل بدون خيارات يعرض ذكر ووقت الصلاة
════════════════════════════════════════════════════════════
EOF
        ;;
    '')
        {
            if [ "${ENABLE_ZIKR_NOTIFY:-1}" = "1" ]; then
                zekr=$(show_random_zekr 2>/dev/null)
                if [ -n "$zekr" ]; then
                    echo "$zekr"
                    echo ""
                fi
            fi
            if get_next_prayer 2>/dev/null; then
                leftmin=$((PRAYER_LEFT/60))
                lefth=$((leftmin/60))
                leftm=$((leftmin%60))
                printf "\e[1;34m🕌 الصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "$PRAYER_NAME" "$PRAYER_TIME" "$lefth" "$leftm"
            fi
        } 2>/dev/null
        ;;
    *)
        echo "❌ خيار غير معروف: $1"
        echo "استخدم --help لعرض الخيارات"
        exit 2
        ;;
esac

exit 0
