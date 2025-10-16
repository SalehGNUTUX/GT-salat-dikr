#!/bin/bash
#
# GT-salat-dikr - النسخة المحسّنة النهائية
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
DEFAULT_TERMINAL_SALAT_NOTIFY=1
DEFAULT_TERMINAL_ZIKR_NOTIFY=1
DEFAULT_SYSTEM_SALAT_NOTIFY=1
DEFAULT_SYSTEM_ZIKR_NOTIFY=1

# ------------- دوال مساعدة وعرض -------------
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

check_tools() {
    detect_gui_tools
    if ! command -v jq >/dev/null 2>&1; then
        silent_log "تحذير: jq غير مثبت. بعض الميزات (جلب المواعيد) قد تفشل."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        silent_log "تحذير: notify-send غير موجود. الإشعارات لن تعمل بدون libnotify."
    fi
}

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

create_adhan_player() {
    cat > "$ADHAN_PLAYER_SCRIPT" << 'ADHAN_PLAYER_EOF'
#!/bin/bash
ADHAN_FILE="$1"
PRAYER_NAME="$2"
PLAYER_PID_FILE="/tmp/gt-adhan-player-$$.pid"

if command -v zenity >/dev/null 2>&1; then
    GUI="zenity"
elif command -v yad >/dev/null 2>&1; then
    GUI="yad"
elif command -v kdialog >/dev/null 2>&1; then
    GUI="kdialog"
else
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}" 2>/dev/null || true
    exit 0
fi

PLAYER=""
if command -v mpv >/dev/null 2>&1; then
    PLAYER="mpv"
elif command -v ffplay >/dev/null 2>&1; then
    PLAYER="ffplay"
elif command -v paplay >/dev/null 2>&1; then
    PLAYER="paplay"
elif command -v ogg123 >/dev/null 2>&1; then
    PLAYER="ogg123"
fi

if [ -z "$PLAYER" ] || [ ! -f "$ADHAN_FILE" ]; then
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}" 2>/dev/null || true
    exit 0
fi

play_adhan() {
    case "$PLAYER" in
        mpv) mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        ffplay) ffplay -nodisp -autoexit -loglevel quiet "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        paplay) paplay "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        ogg123) ogg123 -q "$ADHAN_FILE" >/dev/null 2>&1 & ;;
    esac
    echo $! > "$PLAYER_PID_FILE"
}

stop_adhan() {
    [ -f "$PLAYER_PID_FILE" ] && kill $(cat "$PLAYER_PID_FILE") 2>/dev/null
    pkill -f "$ADHAN_FILE" 2>/dev/null || true
    rm -f "$PLAYER_PID_FILE"
}

play_adhan

case "$GUI" in
    zenity)
        zenity --info --title="GT-salat-dikr" \
            --text="<b>حان الآن وقت صلاة ${PRAYER_NAME}</b>\n\n🕌 الله أكبر" \
            --width=400 --ok-label="إيقاف الأذان" 2>/dev/null
        stop_adhan
        ;;
    yad)
        yad --form --title="GT-salat-dikr" \
            --text="<b>حان الآن وقت صلاة ${PRAYER_NAME}</b>\n\n🕌 الله أكبر" \
            --button="إيقاف:0" --width=400 --center 2>/dev/null
        stop_adhan
        ;;
    kdialog)
        kdialog --title "GT-salat-dikr" \
            --msgbox "حان الآن وقت صلاة ${PRAYER_NAME}\n\n🕌 الله أكبر" 2>/dev/null
        stop_adhan
        ;;
esac

rm -f "$PLAYER_PID_FILE" 2>/dev/null
exit 0
ADHAN_PLAYER_EOF

    chmod +x "$ADHAN_PLAYER_SCRIPT"
    silent_log "تم إنشاء مشغل الأذان الرسومي"
}

create_approaching_player() {
    local APPROACHING_PLAYER="${SCRIPT_DIR}/approaching-player.sh"
    cat > "$APPROACHING_PLAYER" << 'APPROACHING_PLAYER_EOF'
#!/bin/bash
SOUND_FILE="$1"
PRAYER_NAME="$2"
MINUTES="$3"
PLAYER_PID_FILE="/tmp/gt-approaching-$$.pid"

if command -v zenity >/dev/null 2>&1; then
    GUI="zenity"
elif command -v yad >/dev/null 2>&1; then
    GUI="yad"
elif command -v kdialog >/dev/null 2>&1; then
    GUI="kdialog"
else
    notify-send "GT-salat-dikr" "تبقى ${MINUTES} دقيقة على صلاة ${PRAYER_NAME}" 2>/dev/null || true
    exit 0
fi

PLAYER=""
if command -v mpv >/dev/null 2>&1; then
    PLAYER="mpv"
elif command -v ffplay >/dev/null 2>&1; then
    PLAYER="ffplay"
elif command -v paplay >/dev/null 2>&1; then
    PLAYER="paplay"
elif command -v ogg123 >/dev/null 2>&1; then
    PLAYER="ogg123"
fi

if [ -n "$PLAYER" ] && [ -f "$SOUND_FILE" ]; then
    case "$PLAYER" in
        mpv) mpv --no-video --really-quiet "$SOUND_FILE" >/dev/null 2>&1 & ;;
        ffplay) ffplay -nodisp -autoexit -loglevel quiet "$SOUND_FILE" >/dev/null 2>&1 & ;;
        paplay) paplay "$SOUND_FILE" >/dev/null 2>&1 & ;;
        ogg123) ogg123 -q "$SOUND_FILE" >/dev/null 2>&1 & ;;
    esac
    echo $! > "$PLAYER_PID_FILE"
fi

case "$GUI" in
    zenity)
        zenity --info --title="GT-salat-dikr - تذكير" \
            --text="<b>⏰ تبقى ${MINUTES} دقيقة على صلاة ${PRAYER_NAME}</b>\n\nاستعد للصلاة" \
            --width=400 --timeout=10 2>/dev/null
        ;;
    yad)
        yad --form --title="GT-salat-dikr - تذكير" \
            --text="<b>⏰ تبقى ${MINUTES} دقيقة على صلاة ${PRAYER_NAME}</b>\n\nاستعد للصلاة" \
            --button="حسناً:0" --width=400 --center --timeout=10 2>/dev/null
        ;;
    kdialog)
        kdialog --title "GT-salat-dikr - تذكير" \
            --passivepopup "⏰ تبقى ${MINUTES} دقيقة على صلاة ${PRAYER_NAME}\n\nاستعد للصلاة" 10 2>/dev/null
        ;;
esac

[ -f "$PLAYER_PID_FILE" ] && kill $(cat "$PLAYER_PID_FILE") 2>/dev/null || true
rm -f "$PLAYER_PID_FILE" 2>/dev/null
exit 0
APPROACHING_PLAYER_EOF

    chmod +x "$APPROACHING_PLAYER"
    silent_log "تم إنشاء مشغل تنبيه الاقتراب"
}

show_random_zekr() {
    [ ! -f "$AZKAR_FILE" ] && { echo ""; return 1; }
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_notify() {
    local zekr=$(show_random_zekr)
    [ -z "$zekr" ] && zekr="لم يتم العثور على ذكر!"
    
    # إشعارات الطرفية للذكر
    if [ "${TERMINAL_ZIKR_NOTIFY:-1}" = "1" ]; then
        echo "🕊️ $zekr"
    fi
    
    # إشعارات النظام للذكر
    if [ "${SYSTEM_ZIKR_NOTIFY:-1}" = "1" ]; then
        notify-send "GT-salat-dikr" "$zekr" 2>/dev/null || true
    fi
}

play_adhan_gui() {
    local prayer_name="${1:-الصلاة}"
    local adhan_file="$ADHAN_FILE"
    if [ "${ADHAN_TYPE:-full}" = "short" ] && [ -f "$SHORT_ADHAN_FILE" ]; then
        adhan_file="$SHORT_ADHAN_FILE"
    fi
    [ ! -f "$ADHAN_PLAYER_SCRIPT" ] && create_adhan_player
    "$ADHAN_PLAYER_SCRIPT" "$adhan_file" "$prayer_name" &
}

play_approaching_notification() {
    local prayer_name="${1:-الصلاة}"
    local minutes="${2:-15}"
    local approaching_player="${SCRIPT_DIR}/approaching-player.sh"
    [ ! -f "$approaching_player" ] && create_approaching_player
    "$approaching_player" "$APPROACHING_SOUND" "$prayer_name" "$minutes" &
}

METHODS=( "Muslim World League" "Islamic Society of North America" "Egyptian General Authority of Survey" \
"Umm Al-Qura University, Makkah" "University of Islamic Sciences, Karachi" "Institute of Geophysics, University of Tehran" \
"Shia Ithna-Ashari, Leva Institute, Qum" "Gulf Region" "Kuwait" "Qatar" "Majlis Ugama Islam Singapura, Singapore" \
"Union Organization islamic de France" "Diyanet İşleri Başkanlığı, Turkey" "Spiritual Administration of Muslims of Russia" \
"Moonsighting Committee" "Dubai, UAE" "Jabatan Kemajuan Islam Malaysia (JAKIM)" "Tunisia" "Algeria" \
"Kementerian Agama Republik Indonesia" "Morocco" "Comunidate Islamica de Lisboa (Portugal)" )
METHOD_IDS=(3 2 5 4 1 7 8 9 10 11 12 13 14 15 16 18 24 19 20 21 22 23)

auto_detect_location() {
    if ! command -v curl >/dev/null 2>&1; then return 1; fi
    local info
    info=$(curl -fsSL "http://ip-api.com/json/" 2>/dev/null) || return 1
    LAT=$(echo "$info" | jq -r '.lat // empty' 2>/dev/null)
    LON=$(echo "$info" | jq -r '.lon // empty' 2>/dev/null)
    CITY=$(echo "$info" | jq -r '.city // empty' 2>/dev/null)
    COUNTRY=$(echo "$info" | jq -r '.country // empty' 2>/dev/null)
    [[ -z "$LAT" || -z "$LON" ]] && return 1
    return 0
}

manual_location() {
    read -p "أدخل خط العرض (مثال 24.7136): " LAT
    read -p "أدخل خط الطول (مثال 46.6753): " LON
    read -p "أدخل المدينة: " CITY
    read -p "أدخل الدولة: " COUNTRY
}

choose_method() {
    echo "اختر طريقة حساب مواقيت الصلاة:"
    for i in "${!METHODS[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${METHODS[$i]}"
    done
    while true; do
        read -p "الرقم [1]: " idx
        idx=${idx:-1}
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#METHODS[@]} ]; then
            METHOD_IDX=$((idx-1))
            METHOD_NAME="${METHODS[$METHOD_IDX]}"
            METHOD_ID="${METHOD_IDS[$METHOD_IDX]}"
            break
        fi
        echo "خيار غير صالح، حاول مرة أخرى."
    done
}

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

choose_notify_settings() {
    echo ""
    echo "⚙️ إعدادات الإشعارات المتقدمة:"
    echo ""
    
    # إشعارات الصلاة
    echo "🕌 إشعارات الصلاة:"
    read -p "  تفعيل إشعارات الصلاة في الطرفية؟ [Y/n]: " term_salat
    [[ "${term_salat:-Y}" =~ ^[Nn]$ ]] && TERMINAL_SALAT_NOTIFY=0 || TERMINAL_SALAT_NOTIFY=1
    
    read -p "  تفعيل إشعارات الصلاة في النظام (GUI)؟ [Y/n]: " sys_salat
    [[ "${sys_salat:-Y}" =~ ^[Nn]$ ]] && SYSTEM_SALAT_NOTIFY=0 || SYSTEM_SALAT_NOTIFY=1
    
    # تحديد ENABLE_SALAT_NOTIFY بناءً على الإعدادات
    if [ "$TERMINAL_SALAT_NOTIFY" = "1" ] || [ "$SYSTEM_SALAT_NOTIFY" = "1" ]; then
        ENABLE_SALAT_NOTIFY=1
    else
        ENABLE_SALAT_NOTIFY=0
    fi
    
    echo ""
    # إشعارات الذكر
    echo "🕊️ إشعارات الأذكار:"
    read -p "  تفعيل إشعارات الأذكار في الطرفية؟ [Y/n]: " term_zikr
    [[ "${term_zikr:-Y}" =~ ^[Nn]$ ]] && TERMINAL_ZIKR_NOTIFY=0 || TERMINAL_ZIKR_NOTIFY=1
    
    read -p "  تفعيل إشعارات الأذكار في النظام (GUI)؟ [Y/n]: " sys_zikr
    [[ "${sys_zikr:-Y}" =~ ^[Nn]$ ]] && SYSTEM_ZIKR_NOTIFY=0 || SYSTEM_ZIKR_NOTIFY=1
    
    # تحديد ENABLE_ZIKR_NOTIFY بناءً على الإعدادات
    if [ "$TERMINAL_ZIKR_NOTIFY" = "1" ] || [ "$SYSTEM_ZIKR_NOTIFY" = "1" ]; then
        ENABLE_ZIKR_NOTIFY=1
    else
        ENABLE_ZIKR_NOTIFY=0
    fi
}

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
TERMINAL_SALAT_NOTIFY=${TERMINAL_SALAT_NOTIFY:-$DEFAULT_TERMINAL_SALAT_NOTIFY}
TERMINAL_ZIKR_NOTIFY=${TERMINAL_ZIKR_NOTIFY:-$DEFAULT_TERMINAL_ZIKR_NOTIFY}
SYSTEM_SALAT_NOTIFY=${SYSTEM_SALAT_NOTIFY:-$DEFAULT_SYSTEM_SALAT_NOTIFY}
SYSTEM_ZIKR_NOTIFY=${SYSTEM_ZIKR_NOTIFY:-$DEFAULT_SYSTEM_ZIKR_NOTIFY}
EOF
    log "تم حفظ الإعدادات في $CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

setup_wizard() {
    echo "=== إعداد GT-salat-dikr ==="
    if auto_detect_location; then
        echo "تم اكتشاف الموقع تلقائيًا: $CITY, $COUNTRY (LAT=$LAT LON=$LON)"
        read -p "هل تريد استخدامه؟ [Y/n]: " ans; ans=${ans:-Y}
        [[ ! "$ans" =~ ^[Yy]$ ]] && manual_location
    else
        echo "تعذر اكتشاف الموقع تلقائيًا — أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    echo ""
    echo "⏰ إعدادات التنبيه قبل الصلاة:"
    read -p "كم دقيقة قبل الصلاة تريد التنبيه؟ [افتراضي 15]: " pre_min
    PRE_PRAYER_NOTIFY=${pre_min:-$DEFAULT_PRE_NOTIFY}
    echo ""
    echo "📊 اختر نوع الأذان:"
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

fetch_timetable() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "لا يمكن جلب المواقيت - curl أو jq غير متوفر."
        return 1
    fi
    local today=$(date +%Y-%m-%d)
    local url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}&date=${today}"
    local resp
    resp=$(curl -fsSL "$url" 2>/dev/null) || { log "تعذر جلب مواقيت الصلاة."; return 1; }
    echo "$resp" > "$TIMETABLE_FILE"
    log "تم جلب جدول المواقيت"
    return 0
}

read_timetable() {
    [ ! -f "$TIMETABLE_FILE" ] && { fetch_timetable || return 1; }
    local tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    [ "$tdate" != "$(date +%d-%m-%Y)" ] && { fetch_timetable || return 1; }
    return 0
}

show_timetable() {
    read_timetable || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    for i in "${!names[@]}"; do
        local time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        printf "%10s: %s\n" "${arnames[$i]}" "$time"
    done
}

get_next_prayer() {
    read_timetable || return 1
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    for i in "${!names[@]}"; do
        local time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        local h=${time%%:*}; local m=${time#*:}
        local prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        local diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $PRAYER_TIME" +%s) - now_secs ))
    return 0
}

show_pre_prayer_notify() {
    get_next_prayer || return 1
    local minutes="${PRE_PRAYER_NOTIFY:-15}"
    
    # إشعارات الطرفية للصلاة
    if [ "${TERMINAL_SALAT_NOTIFY:-1}" = "1" ]; then
        echo "⏰ تبقى ${minutes} دقيقة على صلاة ${PRAYER_NAME}"
    fi
    
    # إشعارات النظام للصلاة
    if [ "${SYSTEM_SALAT_NOTIFY:-1}" = "1" ]; then
        play_approaching_notification "$PRAYER_NAME" "$minutes"
    fi
}

show_prayer_notify() {
    get_next_prayer || return 1
    
    # إشعارات الطرفية للصلاة
    if [ "${TERMINAL_SALAT_NOTIFY:-1}" = "1" ]; then
        echo "🕌 حان الآن وقت صلاة ${PRAYER_NAME}"
    fi
    
    # إشعارات النظام للصلاة
    if [ "${SYSTEM_SALAT_NOTIFY:-1}" = "1" ]; then
        play_adhan_gui "$PRAYER_NAME"
    fi
}

notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT INT TERM
    local notify_flag_file="${SCRIPT_DIR}/.last-prayer-notified"
    local pre_notify_flag_file="${SCRIPT_DIR}/.last-preprayer-notified"
    local last_zikr_time=0
    
    while true; do
        # التحقق من إعدادات الذكر أولاً
        if [ "${ENABLE_ZIKR_NOTIFY:-1}" = "1" ]; then
            local current_time=$(date +%s)
            local zikr_interval="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
            
            # التحقق من مرور الوقت الكافي منذ آخر ذكر
            if [ $((current_time - last_zikr_time)) -ge $zikr_interval ]; then
                show_zekr_notify || true
                last_zikr_time=$current_time
            fi
        fi
        
        # التحقق من إعدادات الصلاة
        if [ "${ENABLE_SALAT_NOTIFY:-1}" = "1" ] && get_next_prayer; then
            local pre_notify_seconds=$((${PRE_PRAYER_NOTIFY:-15} * 60))
            
            # تنبيه ما قبل الصلاة (مرة واحدة فقط)
            if [ "$PRAYER_LEFT" -le "$pre_notify_seconds" ] && [ "$PRAYER_LEFT" -gt 0 ]; then
                if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                    show_pre_prayer_notify
                    echo "$PRAYER_NAME" > "$pre_notify_flag_file"
                    # حذف ملف تنبيه الصلاة السابق
                    rm -f "$notify_flag_file" 2>/dev/null
                fi
            fi
            
            # تنبيه وقت الصلاة (مرة واحدة فقط)
            if [ "$PRAYER_LEFT" -le 0 ]; then
                if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                    show_prayer_notify
                    echo "$PRAYER_NAME" > "$notify_flag_file"
                    # حذف ملف تنبيه ما قبل الصلاة
                    rm -f "$pre_notify_flag_file" 2>/dev/null
                    # إعادة تعيين وقت الذكر لتجنب التداخل
                    last_zikr_time=$(date +%s)
                fi
            fi
        fi
        
        # حساب وقت النوم الأمثل
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        if [ "${ENABLE_SALAT_NOTIFY:-1}" = "1" ] && get_next_prayer; then
            if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
                sleep_for=$((PRAYER_LEFT < 2 ? 2 : PRAYER_LEFT))
            fi
        fi
        
        # تجنب النوم لفترات طويلة جداً
        [ "$sleep_for" -gt 3600 ] && sleep_for=3600
        
        sleep "$sleep_for"
    done
}

enable_salat_notify() { 
    ENABLE_SALAT_NOTIFY=1
    TERMINAL_SALAT_NOTIFY=1
    SYSTEM_SALAT_NOTIFY=1
    save_config
    echo "✅ تم تفعيل إشعارات الصلاة (طرفية + نظام)."
}

disable_salat_notify() { 
    ENABLE_SALAT_NOTIFY=0
    TERMINAL_SALAT_NOTIFY=0
    SYSTEM_SALAT_NOTIFY=0
    save_config
    echo "✅ تم تعطيل إشعارات الصلاة (طرفية + نظام)."
}

enable_zikr_notify() { 
    ENABLE_ZIKR_NOTIFY=1
    TERMINAL_ZIKR_NOTIFY=1
    SYSTEM_ZIKR_NOTIFY=1
    save_config
    echo "✅ تم تفعيل إشعارات الذكر (طرفية + نظام)."
}

disable_zikr_notify() { 
    ENABLE_ZIKR_NOTIFY=0
    TERMINAL_ZIKR_NOTIFY=0
    SYSTEM_ZIKR_NOTIFY=0
    save_config
    echo "✅ تم تعطيل إشعارات الذكر (طرفية + نظام)."
}

enable_all_notify() { 
    ENABLE_SALAT_NOTIFY=1
    ENABLE_ZIKR_NOTIFY=1
    TERMINAL_SALAT_NOTIFY=1
    TERMINAL_ZIKR_NOTIFY=1
    SYSTEM_SALAT_NOTIFY=1
    SYSTEM_ZIKR_NOTIFY=1
    save_config
    echo "✅ تم تفعيل جميع الإشعارات (طرفية + نظام)."
}

disable_all_notify() { 
    ENABLE_SALAT_NOTIFY=0
    ENABLE_ZIKR_NOTIFY=0
    TERMINAL_SALAT_NOTIFY=0
    TERMINAL_ZIKR_NOTIFY=0
    SYSTEM_SALAT_NOTIFY=0
    SYSTEM_ZIKR_NOTIFY=0
    save_config
    echo "✅ تم تعطيل جميع الإشعارات (طرفية + نظام)."
}

enable_salat_terminal() {
    TERMINAL_SALAT_NOTIFY=1
    # تحديث ENABLE_SALAT_NOTIFY إذا كان أي منهما مفعل
    if [ "$TERMINAL_SALAT_NOTIFY" = "1" ] || [ "${SYSTEM_SALAT_NOTIFY:-1}" = "1" ]; then
        ENABLE_SALAT_NOTIFY=1
    fi
    save_config
    echo "💻 تم تفعيل إشعارات الصلاة في الطرفية"
}

disable_salat_terminal() {
    TERMINAL_SALAT_NOTIFY=0
    # تحديث ENABLE_SALAT_NOTIFY إذا كان كلاهما معطل
    if [ "$TERMINAL_SALAT_NOTIFY" = "0" ] && [ "${SYSTEM_SALAT_NOTIFY:-0}" = "0" ]; then
        ENABLE_SALAT_NOTIFY=0
    fi
    save_config
    echo "💻 تم تعطيل إشعارات الصلاة في الطرفية"
}

enable_zikr_terminal() {
    TERMINAL_ZIKR_NOTIFY=1
    # تحديث ENABLE_ZIKR_NOTIFY إذا كان أي منهما مفعل
    if [ "$TERMINAL_ZIKR_NOTIFY" = "1" ] || [ "${SYSTEM_ZIKR_NOTIFY:-1}" = "1" ]; then
        ENABLE_ZIKR_NOTIFY=1
    fi
    save_config
    echo "💻 تم تفعيل إشعارات الأذكار في الطرفية"
}

disable_zikr_terminal() {
    TERMINAL_ZIKR_NOTIFY=0
    # تحديث ENABLE_ZIKR_NOTIFY إذا كان كلاهما معطل
    if [ "$TERMINAL_ZIKR_NOTIFY" = "0" ] && [ "${SYSTEM_ZIKR_NOTIFY:-0}" = "0" ]; then
        ENABLE_ZIKR_NOTIFY=0
    fi
    save_config
    echo "💻 تم تعطيل إشعارات الأذكار في الطرفية"
}

enable_salat_gui() {
    SYSTEM_SALAT_NOTIFY=1
    # تحديث ENABLE_SALAT_NOTIFY إذا كان أي منهما مفعل
    if [ "${TERMINAL_SALAT_NOTIFY:-1}" = "1" ] || [ "$SYSTEM_SALAT_NOTIFY" = "1" ]; then
        ENABLE_SALAT_NOTIFY=1
    fi
    save_config
    echo "🪟 تم تفعيل إشعارات الصلاة في النظام"
}

disable_salat_gui() {
    SYSTEM_SALAT_NOTIFY=0
    # تحديث ENABLE_SALAT_NOTIFY إذا كان كلاهما معطل
    if [ "${TERMINAL_SALAT_NOTIFY:-0}" = "0" ] && [ "$SYSTEM_SALAT_NOTIFY" = "0" ]; then
        ENABLE_SALAT_NOTIFY=0
    fi
    save_config
    echo "🪟 تم تعطيل إشعارات الصلاة في النظام"
}

enable_zikr_gui() {
    SYSTEM_ZIKR_NOTIFY=1
    # تحديث ENABLE_ZIKR_NOTIFY إذا كان أي منهما مفعل
    if [ "${TERMINAL_ZIKR_NOTIFY:-1}" = "1" ] || [ "$SYSTEM_ZIKR_NOTIFY" = "1" ]; then
        ENABLE_ZIKR_NOTIFY=1
    fi
    save_config
    echo "🪟 تم تفعيل إشعارات الأذكار في النظام"
}

disable_zikr_gui() {
    SYSTEM_ZIKR_NOTIFY=0
    # تحديث ENABLE_ZIKR_NOTIFY إذا كان كلاهما معطل
    if [ "${TERMINAL_ZIKR_NOTIFY:-0}" = "0" ] && [ "$SYSTEM_ZIKR_NOTIFY" = "0" ]; then
        ENABLE_ZIKR_NOTIFY=0
    fi
    save_config
    echo "🪟 تم تعطيل إشعارات الأذكار في النظام"
}

change_notify_system() {
    choose_notify_system
    save_config
    echo "✅ تم تغيير نظام الخدمة إلى: $NOTIFY_SYSTEM"
    echo "💡 أعد تشغيل الإشعارات ليتم تطبيق النظام الجديد."
}

start_notify_bg() {
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
    nohup setsid bash -c "
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

stop_notify_bg() {
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

start_notify_sysvinit() { start_notify_bg; }
stop_notify_sysvinit() { stop_notify_bg; }

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

if [[ "${1:-}" == "--child-notify" ]]; then
    ensure_dbus
    check_tools
    notify_loop
    exit 0
fi

check_tools
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true

# منع تشغيل الإشعارات أثناء الإعداد
if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
else
    load_config || setup_wizard
fi

if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update >/dev/null 2>&1 || true
fi

case "${1:-}" in
    --install)
        if [ -f "$INSTALL_DIR/install.sh" ]; then
            bash "$INSTALL_DIR/install.sh"
        else
            echo "ملف install.sh غير موجود في $INSTALL_DIR"
        fi
        ;;
    --uninstall)
        if [ -f "$INSTALL_DIR/uninstall.sh" ]; then
            bash "$INSTALL_DIR/uninstall.sh"
        else
            echo "ملف uninstall.sh غير موجود في $INSTALL_DIR"
        fi
        ;;
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
    --enable-salat-terminal) enable_salat_terminal ;;
    --disable-salat-terminal) disable_salat_terminal ;;
    --enable-zikr-terminal) enable_zikr_terminal ;;
    --disable-zikr-terminal) disable_zikr_terminal ;;
    --enable-salat-gui) enable_salat_gui ;;
    --disable-salat-gui) disable_salat_gui ;;
    --enable-zikr-gui) enable_zikr_gui ;;
    --disable-zikr-gui) disable_zikr_gui ;;
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
        # التحديث الذاتي (نفس الكود القديم)
        ;;
    --status)
        echo "📊 حالة GT-salat-dikr:"
        echo "═══════════════════════════════════════════"
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
            echo "📊 نوع الأذان: ${ADHAN_TYPE}"
            echo ""
            echo "🔔 إشعارات الصلاة:"
            echo "  💻 الطرفية: $([ "${TERMINAL_SALAT_NOTIFY:-1}" = "1" ] && echo 'مفعلة ✓' || echo 'معطلة ✗')"
            echo "  🪟 النظام: $([ "${SYSTEM_SALAT_NOTIFY:-1}" = "1" ] && echo 'مفعلة ✓' || echo 'معطلة ✗')"
            echo ""
            echo "🟢 إشعارات الذكر:"
            echo "  💻 الطرفية: $([ "${TERMINAL_ZIKR_NOTIFY:-1}" = "1" ] && echo 'مفعلة ✓' || echo 'معطلة ✗')"
            echo "  🪟 النظام: $([ "${SYSTEM_ZIKR_NOTIFY:-1}" = "1" ] && echo 'مفعلة ✓' || echo 'معطلة ✗')"
            echo ""
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
═══════════════════════════════════════════════════════════
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار
═══════════════════════════════════════════════════════════

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

🔔 الإشعارات:
  --notify-start      بدء الإشعارات حسب النظام المختار
  --notify-stop       إيقاف الإشعارات حسب النظام المختار

🟢 التحكم في الإشعارات:
  
  🧩 أوامر عامة:
    --enable-all-notify       تفعيل جميع الإشعارات (طرفية + نظام)
    --disable-all-notify      تعطيل جميع الإشعارات
    --enable-salat-notify     تفعيل إشعارات الصلاة فقط (طرفية + نظام)
    --disable-salat-notify    تعطيل إشعارات الصلاة فقط
    --enable-zikr-notify      تفعيل إشعارات الأذكار فقط (طرفية + نظام)
    --disable-zikr-notify     تعطيل إشعارات الأذكار فقط

  💻 إشعارات الطرفية:
    --enable-salat-terminal   تفعيل إشعارات الصلاة في الطرفية
    --disable-salat-terminal  تعطيل إشعارات الصلاة في الطرفية
    --enable-zikr-terminal    تفعيل إشعارات الأذكار في الطرفية
    --disable-zikr-terminal   تعطيل إشعارات الأذكار في الطرفية

  🪟 إشعارات النظام:
    --enable-salat-gui        تفعيل إشعارات الصلاة في النظام
    --disable-salat-gui       تعطيل إشعارات الصلاة في النظام
    --enable-zikr-gui         تفعيل إشعارات الأذكار في النظام
    --disable-zikr-gui        تعطيل إشعارات الأذكار في النظام

🧪 الاختبار:
  --test-notify       اختبار إشعار
  --test-adhan        اختبار الأذان
  --test-approaching  اختبار تنبيه الاقتراب

🔄 التحديث:
  --update-azkar      تحديث الأذكار
  --self-update       تحديث البرنامج

ℹ️  --help, -h        هذه المساعدة

═══════════════════════════════════════════════════════════
💡 الاستخدام الافتراضي: تشغيل بدون خيارات يعرض ذكر ووقت الصلاة
═══════════════════════════════════════════════════════════
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
