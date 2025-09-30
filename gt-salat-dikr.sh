[file name]: gt-salat-dikr.sh
[file content begin]
#!/bin/bash
#
# GT-salat-dikr - Enhanced version with GUI adhan player
# Author: gnutux (Enhanced)
#
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="$(basename "${0}")"

if [ -n "${BASH_SOURCE:-}" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
else
    SCRIPT_SOURCE="$0"
fi

while [ -h "$SCRIPT_SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
SCRIPT_SOURCE_ABS="$SCRIPT_DIR/$SCRIPT_NAME"

AZKAR_FILE="$SCRIPT_DIR/azkar.txt"
CONFIG_FILE="$SCRIPT_DIR/settings.conf"
TIMETABLE_FILE="$SCRIPT_DIR/timetable.json"
PID_FILE="$SCRIPT_DIR/.gt-salat-dikr-notify.pid"
NOTIFY_LOG="$SCRIPT_DIR/notify.log"
ADHAN_FILE="$SCRIPT_DIR/adhan.ogg"
ADHAN_PLAYER_SCRIPT="$SCRIPT_DIR/adhan-player.sh"

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

# ---------------- أدوات مساعدة ----------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG"
}

fetch_if_missing() {
    local file="$1"; local url="$2"
    if [ ! -f "$file" ]; then
        log "تحميل $file ..."
        if curl -fsSL "$url" -o "$file"; then
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

    log "GUI Tool detected: ${GUI_TOOL:-none}"
}

# ---------------- فحص أدوات النظام ----------------
check_tools() {
    detect_gui_tools

    if ! command -v jq >/dev/null 2>&1; then
        log "تحذير: jq غير مثبت. بعض الميزات (جلب المواعيد) قد تفشل."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        log "تحذير: notify-send غير موجود. الإشعارات لن تعمل بدون libnotify."
    fi
}

# ------------- ضبط DBUS - محسّن للتوافق مع جميع التوزيعات -------------
ensure_dbus() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        return 0
    fi

    local bus="/run/user/$(id -u)/bus"
    if [ -S "$bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        log "DBUS: استخدام المسار القياسي $bus"
        return 0
    fi

    local tmp_bus="/tmp/dbus-$(whoami)"
    if [ -d "$tmp_bus" ]; then
        local sock=$(find "$tmp_bus" -name "session-*" -type s 2>/dev/null | head -1)
        if [ -n "$sock" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$sock"
            log "DBUS: استخدام $sock"
            return 0
        fi
    fi

    local dbus_pid=$(pgrep -u "$(id -u)" dbus-daemon | head -1)
    if [ -n "$dbus_pid" ]; then
        local dbus_addr=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$dbus_pid/environ 2>/dev/null | cut -d= -f2- | tr -d '\0')
        if [ -n "$dbus_addr" ]; then
            export DBUS_SESSION_BUS_ADDRESS="$dbus_addr"
            log "DBUS: استخراج من العملية $dbus_pid"
            return 0
        fi
    fi

    log "تحذير: لم يتم العثور على DBUS - قد تفشل الإشعارات"
    return 1
}

# ---------------- إنشاء مشغل الأذان الرسومي ----------------
create_adhan_player() {
    cat > "$ADHAN_PLAYER_SCRIPT" << 'ADHAN_PLAYER_EOF'
#!/bin/bash
# Adhan GUI Player - يعمل مع zenity, yad, kdialog

ADHAN_FILE="$1"
PRAYER_NAME="$2"
PLAYER_PID_FILE="/tmp/gt-adhan-player-$$.pid"

# اكتشاف الأداة الرسومية المتاحة
if command -v zenity >/dev/null 2>&1; then
    GUI="zenity"
elif command -v yad >/dev/null 2>&1; then
    GUI="yad"
elif command -v kdialog >/dev/null 2>&1; then
    GUI="kdialog"
else
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}"
    exit 0
fi

# اختيار مشغل الصوت المتاح
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
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}"
    exit 0
fi

# تشغيل الأذان في الخلفية
play_adhan() {
    case "$PLAYER" in
        mpv)
            mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 &
            ;;
        ffplay)
            ffplay -nodisp -autoexit -loglevel quiet "$ADHAN_FILE" >/dev/null 2>&1 &
            ;;
        paplay)
            paplay "$ADHAN_FILE" >/dev/null 2>&1 &
            ;;
        ogg123)
            ogg123 -q "$ADHAN_FILE" >/dev/null 2>&1 &
            ;;
    esac
    echo $! > "$PLAYER_PID_FILE"
}

stop_adhan() {
    if [ -f "$PLAYER_PID_FILE" ]; then
        local pid=$(cat "$PLAYER_PID_FILE")
        kill "$pid" 2>/dev/null || true
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PLAYER_PID_FILE"
    fi
    pkill -f "$ADHAN_FILE" 2>/dev/null || true
}

# بدء التشغيل
play_adhan

# عرض النافذة الرسومية حسب الأداة المتاحة
case "$GUI" in
    zenity)
        zenity --info \
            --title="GT-salat-dikr - وقت الصلاة" \
            --text="<span size='xx-large' weight='bold'>حان الآن وقت صلاة ${PRAYER_NAME}</span>\n\n🕌 الله أكبر\n\nاستخدم الأزرار للتحكم في الأذان" \
            --width=400 --height=200 \
            --ok-label="إيقاف الأذان" \
            2>/dev/null
        stop_adhan
        ;;

    yad)
        yad --form \
            --title="GT-salat-dikr - وقت الصلاة" \
            --text="<span size='xx-large' weight='bold'>حان الآن وقت صلاة ${PRAYER_NAME}</span>\n\n🕌 الله أكبر" \
            --button="إيقاف الأذان:0" \
            --button="خفض الصوت:1" \
            --width=400 --height=200 \
            --center \
            2>/dev/null

        case $? in
            0) stop_adhan ;;
            1) pactl set-sink-volume @DEFAULT_SINK@ -10% 2>/dev/null || true ;;
        esac
        ;;

    kdialog)
        kdialog --title "GT-salat-dikr - وقت الصلاة" \
            --msgbox "حان الآن وقت صلاة ${PRAYER_NAME}\n\n🕌 الله أكبر" \
            2>/dev/null
        stop_adhan
        ;;
esac

# تنظيف
rm -f "$PLAYER_PID_FILE" 2>/dev/null || true
exit 0
ADHAN_PLAYER_EOF

    chmod +x "$ADHAN_PLAYER_SCRIPT"
    log "تم إنشاء مشغل الأذان الرسومي"
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

# ---------------- اختيار الموقع والطريقة ----------------
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
    info=$(curl -fsSL "http://ip-api.com/json/") || return 1
    LAT=$(echo "$info" | jq -r '.lat // empty')
    LON=$(echo "$info" | jq -r '.lon // empty')
    CITY=$(echo "$info" | jq -r '.city // empty')
    COUNTRY=$(echo "$info" | jq -r '.country // empty')
    if [[ -z "$LAT" || -z "$LON" ]]; then return 1; fi
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

setup_wizard() {
    echo "=== إعداد GT-salat-dikr ==="
    if auto_detect_location; then
        echo "تم اكتشاف الموقع تلقائيًا: $CITY, $COUNTRY (LAT=$LAT LON=$LON)"
        read -p "هل تريد استخدامه؟ [Y/n]: " ans; ans=${ans:-Y}
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then manual_location; fi
    else
        echo "تعذر اكتشاف الموقع تلقائيًا — أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    read -p "تفعيل تنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; p=${p:-Y}; PRE_PRAYER_NOTIFY=$([ "$p" =~ ^[Yy]$ ] && echo 1 || echo 0)
    read -p "فاصل الأذكار بالثواني (افتراضي $DEFAULT_ZIKR_INTERVAL): " z; ZIKR_NOTIFY_INTERVAL=${z:-$DEFAULT_ZIKR_INTERVAL}
    read -p "تفعيل التحديث الذاتي للسكريبت عند توفر تحديث؟ [y/N]: " up; up=${up:-N}; AUTO_SELF_UPDATE=$([ "$up" =~ ^[Yy]$ ] && echo 1 || echo 0)
    save_config
}

# ---------------- timetable ----------------
fetch_timetable() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "لا يمكن جلب المواقيت - curl أو jq غير متوفر."
        return 1
    fi
    local today=$(date +%Y-%m-%d)
    local url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}&date=${today}"
    local resp
    resp=$(curl -fsSL "$url") || { log "تعذر جلب مواقيت الصلاة من الإنترنت."; return 1; }
    echo "$resp" > "$TIMETABLE_FILE"
    log "تم جلب جدول المواقيت وحفظه في $TIMETABLE_FILE"
    return 0
}

read_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ]; then 
        fetch_timetable || return 1
    fi
    local tdate
    tdate=$(jq -r '.data.date.readable' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    local current_date=$(date +"%d %b %Y")
    if [ "$tdate" != "$current_date" ]; then
        fetch_timetable || return 1
    fi
    return 0
}

show_timetable() {
    if read_timetable; then
        echo "╔══════════════════════════════════════╗"
        echo "║         مواقيت الصلاة اليوم         ║"
        echo "║             ($CITY)              ║"
        echo "╠══════════════════════════════════════╣"
        local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
        local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
        for i in "${!names[@]}"; do
            time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
            printf "║ %-8s : %-8s ║\n" "${arnames[$i]}" "$time"
        done
        echo "╚══════════════════════════════════════╝"
    else
        echo "❌ تعذر قراءة جدول المواقيت."
        return 1
    fi
}

# ---------------- zikr - محسّن العرض ----------------
show_random_zekr() {
    if [ ! -f "$AZKAR_FILE" ]; then echo ""; return 1; fi
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_terminal() {
    local zekr; zekr=$(show_random_zekr) || { echo "لا يوجد أذكار."; return 1; }
    
    echo "╔══════════════════════════════════════════════╗"
    echo "║                   ذكر اليوم                 ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║                                              ║"
    
    # تقسيم الذكر إلى أسطر
    local words=($zekr)
    local line=""
    local max_length=40
    local current_line=""
    
    for word in "${words[@]}"; do
        if [ $((${#current_line} + ${#word} + 1)) -lt $max_length ]; then
            if [ -n "$current_line" ]; then
                current_line="$current_line $word"
            else
                current_line="$word"
            fi
        else
            printf "║   %-*s   ║\n" $((max_length - 2)) "$current_line"
            current_line="$word"
        fi
    done
    
    if [ -n "$current_line" ]; then
        printf "║   %-*s   ║\n" $((max_length - 2)) "$current_line"
    fi
    
    echo "║                                              ║"
    echo "╚══════════════════════════════════════════════╝"
}

show_zekr_notify() {
    local zekr; zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then
        notify-send "GT-salat-dikr" "لم يتم العثور على ذكر!"
    else
        notify-send "GT-salat-dikr" "$zekr"
    fi
}

# ---------------- adhan play - محسّن مع واجهة رسومية ----------------
play_adhan_gui() {
    local prayer_name="${1:-الصلاة}"

    if [ ! -f "$ADHAN_PLAYER_SCRIPT" ]; then
        create_adhan_player
    fi

    # تشغيل المشغل الرسومي في الخلفية
    "$ADHAN_PLAYER_SCRIPT" "$ADHAN_FILE" "$prayer_name" &
}

# ---------------- next prayer ----------------
get_next_prayer() {
    if ! read_timetable; then
        return 1
    fi
    
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        if [ "$time" = "null" ] || [ -z "$time" ]; then
            continue
        fi
        
        h=${time%%:*}; m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s 2>/dev/null || date -d "$h:$m" +%s 2>/dev/null)
        if [ -z "$prayer_secs" ]; then
            continue
        fi
        
        diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    
    # إذا انتهت جميع الصلوات، نعود للفجر في اليوم التالي
    PRAYER_NAME="الفجر"
    local fajr_time=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_TIME="$fajr_time"
    PRAYER_LEFT=$(( $(date -d "tomorrow $fajr_time" +%s 2>/dev/null || echo $((now_secs + 86400))) - now_secs ))
    return 0
}

# ---------------- prayer notifications ----------------
show_pre_prayer_notify() {
    get_next_prayer || return 1
    notify-send "GT-salat-dikr" "تبقى 10 دقائق على صلاة ${PRAYER_NAME} (${PRAYER_TIME})"
}

show_prayer_notify() {
    get_next_prayer || return 1
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME} (${PRAYER_TIME})"
    play_adhan_gui "$PRAYER_NAME"
}

# ---------------- notify loop - محسّن ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT

    local notify_flag_file="$SCRIPT_DIR/.last-prayer-notified"
    local pre_notify_flag_file="$SCRIPT_DIR/.last-preprayer-notified"
    
    # تهيئة الملفات
    touch "$notify_flag_file" "$pre_notify_flag_file" 2>/dev/null || true

    log "بدء حلقة الإشعارات - PID: $$"
    
    # اختبار أولي للإشعارات
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "GT-salat-dikr" "بدأت الإشعارات التلقائية ✅" -t 3000
    fi

    local last_zekr_time=0
    local zekr_interval="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"

    while true; do
        local current_time=$(date +%s)
        
        # إرسال ذكر عشوائي كل فترة
        if [ $((current_time - last_zekr_time)) -ge $zekr_interval ]; then
            show_zekr_notify || true
            last_zekr_time=$current_time
        fi

        if ! get_next_prayer; then
            sleep 30
            continue
        fi

        # تنبيه قبل الصلاة
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ] && [ "$PRAYER_LEFT" -gt 0 ]; then
            if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                show_pre_prayer_notify
                echo "$PRAYER_NAME" > "$pre_notify_flag_file"
            fi
        fi

        # تنبيه عند وقت الصلاة
        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                show_prayer_notify
                echo "$PRAYER_NAME" > "$notify_flag_file"
                rm -f "$pre_notify_flag_file" 2>/dev/null || true
            fi
        fi

        # تحديد مدة النوم الذكية
        local sleep_for=60  # فحص كل دقيقة بدلاً من الانتظار الطويل
        if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
            sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        fi
        
        sleep "$sleep_for"
    done
}

# ---------------- start/stop notify - محسّن ----------------
start_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    ensure_dbus
    check_tools
    
    # إنشاء مشغل الأذان إذا لم يكن موجوداً
    if [ ! -f "$ADHAN_PLAYER_SCRIPT" ]; then
        create_adhan_player
    fi

    echo "🔄 بدء الإشعارات في الخلفية..."
    
    # تشغيل حلقة الإشعارات في الخلفية مباشرة
    (
        cd "$SCRIPT_DIR"
        if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" 2>/dev/null || true
        fi
        notify_loop &
        local loop_pid=$!
        echo $loop_pid > "$PID_FILE"
        log "بدأت حلقة الإشعارات مع PID: $loop_pid"
        wait $loop_pid
    ) >/dev/null 2>&1 &
    
    local bg_pid=$!
    sleep 2
    
    if [ -f "$PID_FILE" ]; then
        local main_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$main_pid" ] && kill -0 "$main_pid" 2>/dev/null; then
            echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $main_pid)"
            return 0
        fi
    fi
    
    echo "❌ فشل في بدء الإشعارات"
    rm -f "$PID_FILE" 2>/dev/null || true
    return 1
}

stop_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            log "stopped notify loop (PID: $pid)"
            echo "✅ تم إيقاف إشعارات GT-salat-dikr (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE" 2>/dev/null || true
            echo "⚠️ لم تكن هناك إشعارات قيد التشغيل."
            return 1
        fi
    else
        echo "ℹ️ لا يوجد إشعارات قيد التشغيل."
        return 1
    fi
}

# ---------------- self-update ----------------
check_script_update() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v sha1sum >/dev/null 2>&1; then
        log "لا يمكن التحقق من التحديث - curl أو sha1sum غير متوفر."
        return 1
    fi
    local local_hash remote_hash tmpf
    if [ -f "$SCRIPT_SOURCE_ABS" ]; then
        local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}') || true
    else
        local_hash=""
    fi
    remote_hash=$(curl -fsSL "$REPO_SCRIPT_URL" | sha1sum | awk '{print $1}') || return 1
    if [ "$local_hash" != "" ] && [ "$local_hash" != "$remote_hash" ]; then
        echo "يوجد تحديث جديد للسكريبت."
        read -p "هل ترغب بتحديث السكربت تلقائيًا الآن؟ [Y/n]: " ans; ans=${ans:-Y}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            tmpf=$(mktemp) || return 1
            curl -fsSL "$REPO_SCRIPT_URL" -o "$tmpf" || { echo "فشل تحميل النسخة الجديدة."; rm -f "$tmpf"; return 1; }
            chmod +x "$tmpf"
            mv "$tmpf" "$SCRIPT_SOURCE_ABS" && echo "✅ تم تحديث السكربت. أعد التشغيل لاستخدام النسخة الجديدة."
            return 0
        else
            echo "تم تأجيل التحديث."
        fi
    else
        echo "لا يوجد تحديث."
    fi
    return 0
}

# ---------------- install - محسّن ----------------
install_self() {
    echo "ℹ️  البرنامج مثبت بالفعل في $INSTALL_DIR"
    echo "💡 استخدم 'gtsalat --settings' لتعديل الإعدادات"
    return 0
}

uninstall_self() {
    stop_notify_bg || true
    rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true
    echo "✅ تم إزالة GT-salat-dikr."
}

# ---------------- child mode ----------------
if [[ "${1:-}" == "--child-notify" ]]; then
    ensure_dbus
    check_tools
    notify_loop
    exit 0
fi

# ---------------- تحميل الإعدادات وتهيئة أولية ----------------
check_tools
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true

if [ ! -f "$CONFIG_FILE" ]; then
    # إذا لم تكن هناك إعدادات، نعرض المساعدة بدلاً من الإعدادات التلقائية
    echo "⚠️  لم يتم العثور على إعدادات."
    echo "💡 استخدم 'gtsalat --settings' لتهيئة الإعدادات أولاً"
else
    load_config || {
        echo "⚠️  خطأ في تحميل الإعدادات."
        echo "💡 استخدم 'gtsalat --settings' لإعادة التهيئة"
    }
fi

if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update || true
fi

# ---------------- CLI - محسّن العرض ----------------
case "${1:-}" in
    --install)
        install_self
        ;;
    --uninstall)
        uninstall_self
        ;;
    --settings)
        setup_wizard
        ;;
    --show-timetable|-t)
        show_timetable
        ;;
    --notify-start)
        start_notify_bg
        ;;
    --notify-stop)
        stop_notify_bg
        ;;
    --test-notify)
        ensure_dbus
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "GT-salat-dikr" "اختبار إشعار ✔"
            echo "✅ تم إرسال إشعار تجريبي (تحقق من ظهور النافذة)."
        else
            echo "❌ notify-send غير متوفرة."
            exit 1
        fi
        ;;
    --test-adhan)
        ensure_dbus
        echo "🔊 اختبار مشغل الأذان الرسومي..."
        create_adhan_player
        play_adhan_gui "اختبار"
        ;;
    --update-azkar)
        echo "⏳ جلب أحدث نسخة من الأذكار..."
        if curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE"; then
            echo "✅ تم تحديث الأذكار."
        else
            echo "❌ فشل في تحديث الأذكار."
        fi
        ;;
    --self-update)
        check_script_update
        ;;
    --status)
        echo "📊 حالة GT-salat-dikr:"
        echo "══════════════════════════════════════════════"
        if [ -f "$PID_FILE" ]; then
            local pid; pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "✅ الإشعارات: نشطة (PID: $pid)"
            else
                echo "❌ الإشعارات: متوقفة"
                rm -f "$PID_FILE" 2>/dev/null || true
            fi
        else
            echo "❌ الإشعارات: متوقفة"
        fi
        
        if [ -f "$CONFIG_FILE" ]; then
            echo "📍 الموقع: ${CITY:-غير معين}, ${COUNTRY:-غير معين}"
            echo "📅 طريقة الحساب: ${METHOD_NAME:-غير معين}"
            echo "⏰ تنبيه قبل الصلاة: $([ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && echo "مفعل" || echo "معطل")"
            echo "🔄 فاصل الأذكار: ${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL} ثانية"
        else
            echo "⚠️  الإعدادات: غير مهيئة"
        fi
        echo "📁 مجلد التثبيت: $INSTALL_DIR"
        echo "══════════════════════════════════════════════"
        ;;
    --help|-h)
        echo "🕌 GT-salat-dikr - مساعد مواقيت الصلاة والأذكار"
        echo "══════════════════════════════════════════════════════════════════════════════════"
        echo "الاستخدام: $0 [خيار]"
        echo ""
        echo "الخيارات المتاحة:"
        echo "  --install           تثبيت البرنامج وإعداد التشغيل التلقائي"
        echo "  --uninstall         إزالة التثبيت"
        echo "  --settings          إعدادات الموقع وطريقة الحساب"
        echo "  --show-timetable | -t  عرض مواقيت الصلاة اليوم بطريقة جميلة"
        echo "  --notify-start      بدء الإشعارات في الخلفية"
        echo "  --notify-stop       إيقاف الإشعارات"
        echo "  --status            عرض حالة البرنامج والإعدادات"
        echo "  --test-notify       اختبار الإشعارات"
        echo "  --test-adhan        اختبار مشغل الأذان الرسومي"
        echo "  --update-azkar      تحديث ملف الأذكار"
        echo "  --self-update       التحقق من تحديثات السكربت"
        echo "  --help | -h         عرض هذه المساعدة"
        echo ""
        echo "بدون خيارات: عرض الذكر اليومي ومواقيت الصلاة"
        echo "══════════════════════════════════════════════════════════════════════════════════"
        ;;
    *)
        # الوضع الافتراضي: عرض الذكر ومواقيت الصلاة
        echo ""
        show_zekr_terminal
        echo ""
        
        if [ -f "$CONFIG_FILE" ]; then
            show_timetable 2>/dev/null || echo "⚠️  تعذر تحميل مواقيت الصلاة"
            echo ""
            get_next_prayer 2>/dev/null && {
                leftmin=$((PRAYER_LEFT/60))
                lefth=$((leftmin/60))
                leftm=$((leftmin%60))
                printf "🕌 الصلاة القادمة: %s عند %s (باقي %02d:%02d)\n" "${PRAYER_NAME:-?}" "${PRAYER_TIME:-??:??}" "$lefth" "$leftm"
            } || echo "⚠️  تعذر تحديد موعد الصلاة القادمة"
        else
            echo "💡 استخدم 'gtsalat --settings' لتهيئة الإعدادات أولاً"
        fi
        
        echo ""
        echo "💡 استخدم '$0 --help' لعرض جميع الخيارات المتاحة"
        ;;
esac
[file content end]
