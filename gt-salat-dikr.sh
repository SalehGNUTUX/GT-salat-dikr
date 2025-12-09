#!/bin/bash
#
# GT-salat-dikr - برنامج الذكر و الصلاة على الطرفية و إشعارات النظام
# Author: gnutux
# Version: 3.2.2
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

# إضافة المتغيرات الجديدة للتخزين المحلي
MONTHLY_TIMETABLE_DIR="${SCRIPT_DIR}/monthly_timetables"
CACHE_DAYS=30  # عدد الأيام التي نخزنها في الذاكرة المؤقتة

# إعدادات التحديث التلقائي
LAST_AUTO_UPDATE_FILE="${SCRIPT_DIR}/.last_auto_update"
AUTO_UPDATE_INTERVAL=7  # أيام بين التحديثات التلقائية

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

# دوال جديدة للتخزين المحلي
create_monthly_timetable_dir() {
    mkdir -p "$MONTHLY_TIMETABLE_DIR"
    silent_log "تم إنشاء/التأكد من مجلد الجداول الشهرية: $MONTHLY_TIMETABLE_DIR"
}

get_monthly_filename() {
    local year="$1"
    local month="$2"
    printf "%s/timetable_%04d_%02d.json" "$MONTHLY_TIMETABLE_DIR" "$year" "$month"
}

# دالة موثوقة للتحقق من اتصال الإنترنت
check_internet_connection() {
    local timeout=10
    local success=false
    
    # قائمة بالمواقع الموثوقة للاختبار
    local test_urls=(
        "https://www.google.com"
        "https://www.cloudflare.com"
        "https://1.1.1.1"  # Cloudflare DNS مباشرة
    )
    
    for url in "${test_urls[@]}"; do
        if command -v curl >/dev/null 2>&1; then
            if curl -fs --connect-timeout $timeout "$url" >/dev/null 2>&1; then
                success=true
                break
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --spider --timeout=$timeout "$url" 2>/dev/null; then
                success=true
                break
            fi
        fi
    done
    
    if [ "$success" = true ]; then
        return 0
    else
        # محاولة أخيرة مع ping
        if command -v ping >/dev/null 2>&1; then
            if ping -c 1 -W $timeout 8.8.8.8 >/dev/null 2>&1; then
                return 0
            fi
        fi
        return 1
    fi
}

# دوال التحديث التلقائي الجديدة
check_auto_update_needed() {
    if [ "${AUTO_UPDATE_TIMETABLES:-0}" != "1" ]; then
        return 1
    fi
    
    if [ ! -f "$LAST_AUTO_UPDATE_FILE" ]; then
        return 0
    fi
    
    local last_update=$(cat "$LAST_AUTO_UPDATE_FILE" 2>/dev/null)
    local current_time=$(date +%s)
    local update_age=$((current_time - last_update))
    local interval_seconds=$((AUTO_UPDATE_INTERVAL * 24 * 3600))
    
    if [ $update_age -ge $interval_seconds ]; then
        return 0
    fi
    
    return 1
}

perform_auto_update() {
    if ! check_internet_connection; then
        silent_log "لا يوجد اتصال للتنفيذ التلقائي"
        return 1
    fi
    
    log "بدء التحديث التلقائي لمواقيت الصلاة"
    
    # استخدام الدالة الموجودة مع إضافة سياق تلقائي
    if fetch_future_timetables "auto"; then
        date +%s > "$LAST_AUTO_UPDATE_FILE"
        log "✅ تم التحديث التلقائي بنجاح"
        
        # إشعار المستخدم بالتحديث (إذا كان في وضع الطرفية)
        if [ -t 1 ]; then
            echo "🔄 تم التحديث التلقائي لمواقيت الصلاة"
        fi
        return 0
    else
        log "❌ فشل التحديث التلقائي"
        return 1
    fi
}

fetch_monthly_timetable() {
    local year="$1"
    local month="$2"
    local filename
    filename=$(get_monthly_filename "$year" "$month")
    
    # إذا كان الملف موجوداً ومحدثاً، لا نحتاج لتحميله
    if [ -f "$filename" ]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$filename" 2>/dev/null || echo 0)))
        # إذا عمر الملف أقل من 7 أيام، استخدمه
        if [ "$file_age" -lt 604800 ]; then
            silent_log "استخدام الجدول الشهري الموجود: $filename"
            return 0
        fi
    fi
    
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "لا يمكن جلب الجدول الشهري - curl أو jq غير متوفر."
        return 1
    fi
    
    # استخدام API مختلفة لجلب الشهر كاملاً
    local url="https://api.aladhan.com/v1/calendar/${year}/${month}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}"
    local resp
    
    log "جلب جدول الصلاة لشهر $month-$year"
    resp=$(curl -fsSL --connect-timeout 10 "$url" 2>/dev/null) || { 
        log "تعذر جلب جدول الصلاة لشهر $month-$year"
        return 1
    }
    
    # التحقق من أن الاستجابة تحتوي على بيانات
    local valid_response=$(echo "$resp" | jq -r '.data | length' 2>/dev/null || echo "0")
    if [ "$valid_response" -eq 0 ]; then
        log "استجابة فارغة أو غير صالحة لشهر $month-$year"
        return 1
    fi
    
    echo "$resp" > "$filename"
    log "تم حفظ جدول الصلاة لشهر $month-$year في $filename"
    return 0
}

fetch_future_timetables() {
    local context="${1:-manual}"
    local months_ahead=3
    
    create_monthly_timetable_dir
    
    local current_year=$(date +%Y)
    local current_month=$(date +%m)
    
    log "جلب جداول الصلاة ($context)..."
    
    # البدء من الشهر الحالي وإضافة الأشهر القادمة
    for ((i=0; i<=months_ahead; i++)); do
        local year=$((current_year + (current_month + i - 1) / 12))
        local month=$(((current_month + i - 1) % 12 + 1))
        local month_formatted=$(printf "%02d" "$month")
        
        log "جلب جدول الصلاة لشهر $month_formatted-$year ($context)"
        fetch_monthly_timetable "$year" "$month_formatted" || {
            log "فشل في جلب جدول شهر $month_formatted-$year"
            continue
        }
        
        sleep 1
    done
    
    # فقط في الوضع اليدوي، عرض التقرير
    if [ "$context" = "manual" ]; then
        show_update_report
    fi
}

# دالة لعرض تقرير التحديث
show_update_report() {
    echo ""
    echo "📊 تقرير التحديث:"
    if [ -d "$MONTHLY_TIMETABLE_DIR" ]; then
        file_count=$(find "$MONTHLY_TIMETABLE_DIR" -name "timetable_*.json" -type f 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo "✅ تم تخزين بيانات $file_count شهر"
            
            echo "📁 الملفات المحفوظة:"
            for file in "$MONTHLY_TIMETABLE_DIR"/timetable_*.json; do
                [ -e "$file" ] || continue
                filename=$(basename "$file")
                year_month=$(echo "$filename" | sed 's/timetable_\([0-9]*\)_\([0-9]*\).json/\1-\2/')
                size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?KB")
                echo "   📄 $year_month ($size)"
            done
            
            echo ""
            echo "💾 يمكنك الآن استخدام البرنامج بدون اتصال بالإنترنت"
        else
            echo "❌ لم يتم تخزين أي بيانات"
        fi
    else
        echo "❌ فشل في إنشاء مجلد التخزين"
    fi
}

find_prayer_time_in_cache() {
    local target_date="$1"  # بصيغة YYYY-MM-DD
    local target_year=$(echo "$target_date" | cut -d'-' -f1)
    local target_month=$(echo "$target_date" | cut -d'-' -f2)
    local target_day=$(echo "$target_date" | cut -d'-' -f3)
    
    local filename
    filename=$(get_monthly_filename "$target_year" "$target_month")
    
    if [ ! -f "$filename" ]; then
        silent_log "الملف غير موجود للبحث: $filename"
        return 1
    fi
    
    # تحويل التاريخ إلى الصيغة التي يستخدمها API (DD-MM-YYYY)
    local target_date_formatted=$(printf "%02d-%02d-%04d" "$target_day" "$target_month" "$target_year")
    
    # استخراج مواقيت اليوم المطلوب
    local timings
    timings=$(jq -r ".data[] | select(.date.gregorian.date == \"$target_date_formatted\") | .timings" "$filename" 2>/dev/null)
    
    if [ -n "$timings" ] && [ "$timings" != "null" ]; then
        silent_log "تم العثور على بيانات محفوظة لليوم: $target_date"
        echo "$timings"
        return 0
    else
        silent_log "لم يتم العثور على بيانات محفوظة لليوم: $target_date"
        return 1
    fi
}

fetch_timetable_enhanced() {
    local today=$(date +%Y-%m-%d)
    
    # أولاً حاول استخدام الذاكرة المؤقتة
    local cached_timings
    if cached_timings=$(find_prayer_time_in_cache "$today"); then
        # إنشاء ملف مؤقت ببيانات اليوم من الذاكرة المؤقتة
        cat > "$TIMETABLE_FILE" <<EOF
{
    "data": {
        "date": {
            "gregorian": {
                "date": "$(date +%d-%m-%Y)"
            }
        },
        "timings": $cached_timings
    }
}
EOF
        silent_log "تم استخدام البيانات من الذاكرة المؤقتة لليوم: $today"
        return 0
    fi
    
    # إذا لم توجد في الذاكرة المؤقتة، جلب من الإنترنت
    silent_log "لم توجد بيانات محفوظة، جلب من الإنترنت..."
    fetch_timetable
}

# تحسين دالة fetch_timetable الأصلية
fetch_timetable() {
    if ! check_internet_connection; then
        log "⚠️  لا يوجد اتصال بالإنترنت - استخدام البيانات المحفوظة"
        # محاولة استخدام البيانات المحفوظة لليوم
        local today=$(date +%Y-%m-%d)
        if cached_timings=$(find_prayer_time_in_cache "$today"); then
            cat > "$TIMETABLE_FILE" <<EOF
{
    "data": {
        "date": {
            "gregorian": {
                "date": "$(date +%d-%m-%Y)"
            }
        },
        "timings": $cached_timings
    }
}
EOF
            log "تم استخدام البيانات المحفوظة بسبب انقطاع الإنترنت"
            return 0
        else
            log "❌ لا توجد بيانات محفوظة ولا اتصال بالإنترنت"
            return 1
        fi
    fi
    
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "لا يمكن جلب المواقيت - curl أو jq غير متوفر."
        return 1
    fi
    
    local today=$(date +%Y-%m-%d)
    local url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}&date=${today}"
    local resp
    
    log "جرب جدول المواقيت من الإنترنت..."
    resp=$(curl -fsSL --connect-timeout 10 "$url" 2>/dev/null) || { 
        log "تعذر جلب مواقيت الصلاة من الإنترنت."
        return 1
    }
    
    # التحقق من صحة الاستجابة
    if ! echo "$resp" | jq -e '.data.timings' >/dev/null 2>&1; then
        log "استجابة غير صالحة من API"
        return 1
    fi
    
    echo "$resp" > "$TIMETABLE_FILE"
    log "تم جلب جدول المواقيت من الإنترنت بنجاح"
    return 0
}

read_timetable_enhanced() {
    [ ! -f "$TIMETABLE_FILE" ] && { fetch_timetable_enhanced || return 1; }
    local tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    [ "$tdate" != "$(date +%d-%m-%Y)" ] && { fetch_timetable_enhanced || return 1; }
    return 0
}

# دوال التحكم في التحديث التلقائي
enable_auto_update() {
    AUTO_UPDATE_TIMETABLES=1
    save_config
    echo "✅ تم تفعيل التحديث التلقائي لمواقيت الصلاة"
    echo "📅 سيتم التحديث كل $AUTO_UPDATE_INTERVAL أيام عند توفر الإنترنت"
}

disable_auto_update() {
    AUTO_UPDATE_TIMETABLES=0
    save_config
    echo "✅ تم تعطيل التحديث التلقائي لمواقيت الصلاة"
}

show_auto_update_status() {
    if [ "${AUTO_UPDATE_TIMETABLES:-0}" = "1" ]; then
        echo "🟢 التحديث التلقائي: مفعل"
        if [ -f "$LAST_AUTO_UPDATE_FILE" ]; then
            local last_update=$(cat "$LAST_AUTO_UPDATE_FILE")
            local last_date=$(date -d "@$last_update" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "غير معروف")
            echo "   📅 آخر تحديث: $last_date"
            
            local next_update=$((last_update + (AUTO_UPDATE_INTERVAL * 24 * 3600)))
            local next_date=$(date -d "@$next_update" "+%Y-%m-%d" 2>/dev/null || echo "غير معروف")
            echo "   ⏰ التحديث القادم: $next_date"
        else
            echo "   ⏰ لم يتم أي تحديث تلقائي بعد"
        fi
    else
        echo "🔴 التحديث التلقائي: معطل"
    fi
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
    
    # إعادة تحميل الإعدادات دائماً
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
    local adhan_file="$ADHAN_FILE"
    local adhan_type="${ADHAN_TYPE:-full}"
    
    if [ "$adhan_type" = "short" ] && [ -f "$SHORT_ADHAN_FILE" ]; then
        adhan_file="$SHORT_ADHAN_FILE"
        silent_log "استخدام الأذان القصير لصلاة: $prayer_name"
    elif [ "$adhan_type" = "short" ] && [ ! -f "$SHORT_ADHAN_FILE" ]; then
        silent_log "تحذير: ملف الأذان القصير غير موجود، استخدام الكامل"
        adhan_file="$ADHAN_FILE"
    else
        silent_log "استخدام الأذان الكامل لصلاة: $prayer_name"
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
AUTO_UPDATE_TIMETABLES=${AUTO_UPDATE_TIMETABLES:-0}
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
    
    # ⬅️ التعديل هنا - تحويل الدقائق إلى ثواني
    default_minutes=$((DEFAULT_ZIKR_INTERVAL/60))
    read -p "فاصل الأذكار بالدقائق (افتراضي $default_minutes): " z_minutes
    ZIKR_NOTIFY_INTERVAL=$((${z_minutes:-$default_minutes} * 60))
    
    read -p "تفعيل التحديث الذاتي؟ [y/N]: " up; up=${up:-N}
    [[ "$up" =~ ^[Yy]$ ]] && AUTO_SELF_UPDATE=1 || AUTO_SELF_UPDATE=0
    
    # إضافة السؤال عن التخزين المحلي
    echo ""
    echo "💾 التخزين المحلي لمواقيت الصلاة:"
    read -p "هل تريد تخزين مواقيت الصلاة لعدة أشهر للعمل بدون إنترنت؟ [Y/n]: " storage_ans
    storage_ans=${storage_ans:-Y}
    if [[ "$storage_ans" =~ ^[Yy]$ ]]; then
        echo "📥 جاري تحميل مواقيت الصلاة للأشهر القادمة..."
        fetch_future_timetables "wizard"
    fi
    
    # السؤال الجديد عن التحديث التلقائي
    echo ""
    echo "🔄 التحديث التلقائي لمواقيت الصلاة:"
    read -p "هل تريد تفعيل التحديث التلقائي كل أسبوع؟ [y/N]: " auto_update_ans
    auto_update_ans=${auto_update_ans:-N}
    if [[ "$auto_update_ans" =~ ^[Yy]$ ]]; then
        AUTO_UPDATE_TIMETABLES=1
        echo "✅ تم تفعيل التحديث التلقائي"
    else
        AUTO_UPDATE_TIMETABLES=0
        echo "✅ التحديث التلقائي معطل"
    fi
    
    choose_notify_system
    choose_notify_settings
    save_config
}

show_timetable() {
    read_timetable_enhanced || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    for i in "${!names[@]}"; do
        local time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        printf "%10s: %s\n" "${arnames[$i]}" "$time"
    done
}

get_next_prayer() {
    read_timetable_enhanced || return 1
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
    
    # تحميل الإعدادات قبل التشغيل
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    
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
        # إعادة تحميل الإعدادات في كل دورة
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
        fi
        
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

check_script_update() {
    if ! command -v curl >/dev/null 2>&1; then
        log "curl غير متوفر - لا يمكن التحقق من التحديثات"
        return 1
    fi
    
    local remote_content
    remote_content=$(curl -fsSL "$REPO_SCRIPT_URL" 2>/dev/null) || {
        log "فشل جلب النسخة الحديثة من المستودع"
        return 1
    }
    
    local current_hash
    local remote_hash
    current_hash=$(sha256sum "$SCRIPT_SOURCE_ABS" 2>/dev/null | cut -d' ' -f1)
    remote_hash=$(echo "$remote_content" | sha256sum | cut -d' ' -f1)
    
    if [ "$current_hash" != "$remote_hash" ]; then
        log "⚠️ يوجد تحديث جديد متاح!"
        echo "🔄 يوجد تحديث جديد لـ GT-salat-dikr!"
        read -p "هل تريد التحديث الآن؟ [Y/n]: " answer
        answer=${answer:-Y}
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "📥 جاري التحديث..."
            # إنشاء نسخة احتياطية
            cp "$SCRIPT_SOURCE_ABS" "$SCRIPT_SOURCE_ABS.backup"
            if echo "$remote_content" > "$SCRIPT_SOURCE_ABS"; then
                chmod +x "$SCRIPT_SOURCE_ABS"
                log "تم التحديث إلى النسخة الجديدة"
                echo "✅ تم التحديث بنجاح!"
                echo "💡 أعد تشغيل البرنامج للتأكد من العمل بشكل صحيح."
                exit 0
            else
                # استعادة النسخة الاحتياطية إذا فشل التحديث
                mv "$SCRIPT_SOURCE_ABS.backup" "$SCRIPT_SOURCE_ABS"
                log "فشل في حفظ التحديث"
                echo "❌ فشل في التحديث"
                return 1
            fi
        fi
    else
        log "البرنامج محدث بالفعل"
        echo "✅ البرنامج محدث إلى آخر نسخة"
    fi
}

# ---------- System Tray Commands ----------
start_system_tray() {
    echo "🖥️  تشغيل أيقونة شريط المهام..."
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import pystray, PIL" 2>/dev/null; then
            if [ -f "${SCRIPT_DIR}/gt-tray.py" ]; then
                # التحقق إذا كانت تعمل بالفعل
                if pgrep -f "gt-tray.py" >/dev/null 2>&1; then
                    echo "✅ System Tray يعمل بالفعل"
                else
                    python3 "${SCRIPT_DIR}/gt-tray.py" &
                    echo "✅ تم تشغيل System Tray"
                    echo "💡 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
                fi
            else
                echo "❌ ملف gt-tray.py غير موجود"
                echo "💡 أعد تشغيل install.sh لتحميله"
            fi
        else
            echo "❌ مكتبات Python غير مثبتة"
            echo "📦 جاري التثبيت التلقائي..."
            
            # كشف مدير الحزم
            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y python3-pystray python3-pil && {
                    python3 "${SCRIPT_DIR}/gt-tray.py" &
                    echo "✅ تم تشغيل System Tray بعد التثبيت"
                }
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm python-pystray python-pillow && {
                    python3 "${SCRIPT_DIR}/gt-tray.py" &
                    echo "✅ تم تشغيل System Tray بعد التثبيت"
                }
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y python3-pystray python3-pillow && {
                    python3 "${SCRIPT_DIR}/gt-tray.py" &
                    echo "✅ تم تشغيل System Tray بعد التثبيت"
                }
            else
                echo "💡 قم بالتثبيت يدوياً:"
                echo "   pip install --user pystray pillow"
            fi
        fi
    else
        echo "❌ Python3 غير مثبت"
        echo "💡 قم بتثبيته أولاً:"
        echo "   sudo apt install python3  أو  sudo pacman -S python"
    fi
}

restart_system_tray() {
    echo "🔄 إعادة تشغيل System Tray..."
    pkill -f "gt-tray.py" 2>/dev/null
    sleep 2
    if [ -f "${SCRIPT_DIR}/gt-tray.py" ]; then
        python3 "${SCRIPT_DIR}/gt-tray.py" &
        echo "✅ تم إعادة التشغيل"
    else
        echo "❌ ملف gt-tray.py غير موجود"
    fi
}

stop_system_tray() {
    echo "⏸️  إيقاف System Tray..."
    if pkill -f "gt-tray.py" 2>/dev/null; then
        echo "✅ تم إيقاف System Tray"
    else
        echo "ℹ️  System Tray غير قيد التشغيل"
    fi
}

# ---------- Main Execution ----------
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

# التحقق التلقائي من التحديثات
if [ "${AUTO_UPDATE_TIMETABLES:-0}" = "1" ] && check_auto_update_needed; then
    silent_log "بدء التحقق التلقائي للتحديث"
    perform_auto_update >/dev/null 2>&1 &
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
        
        # تحميل الإعدادات
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
        fi
        
        local adhan_file="$ADHAN_FILE"
        if [ ! -f "$adhan_file" ]; then
            echo "❌ ملف الأذان الكامل غير موجود: $adhan_file"
            echo "💡 تأكد من وجود ملف adhan.ogg في مجلد البرنامج"
            exit 1
        fi
        
        echo "🔊 اختبار الأذان الكامل..."
        "$ADHAN_PLAYER_SCRIPT" "$adhan_file" "اختبار الأذان الكامل" &
        echo "✅ تم تشغيل اختبار الأذان الكامل"
        ;;
    --test-adhan-short)
        ensure_dbus
        create_adhan_player
        
        # تحميل الإعدادات للتأكد من استخدام الأذان القصير
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
        fi
        
        local adhan_file="$SHORT_ADHAN_FILE"
        if [ ! -f "$adhan_file" ]; then
            echo "❌ ملف الأذان القصير غير موجود: $adhan_file"
            echo "💡 تأكد من وجود ملف short_adhan.ogg في مجلد البرنامج"
            exit 1
        fi
        
        echo "🔊 اختبار الأذان القصير..."
        "$ADHAN_PLAYER_SCRIPT" "$adhan_file" "اختبار الأذان القصير" &
        echo "✅ تم تشغيل اختبار الأذان القصير"
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
    --update-timetables)
        echo "📥 جلب مواقيت الصلاة للأشهر القادمة..."
        if ! check_internet_connection; then
            echo "❌ لا يوجد اتصال بالإنترنت - لا يمكن تحديث الجداول"
            exit 1
        fi
        
        # التحقق من وجود إعدادات الموقع
        if [ -z "${LAT:-}" ] || [ -z "${LON:-}" ]; then
            echo "❌ لم يتم تحديد الموقع بعد"
            echo "   الرجاء تشغيل الإعدادات أولاً: gtsalat --settings"
            exit 1
        fi
        
        echo "📍 الموقع: ${CITY:-غير محدد} (${LAT}, ${LON})"
        echo "📖 طريقة الحساب: ${METHOD_NAME:-غير محدد}"
        echo ""
        
        fetch_future_timetables "manual"
        ;;
    --enable-auto-update)
        enable_auto_update
        ;;
    --disable-auto-update)
        disable_auto_update
        ;;
    --auto-update-status)
        show_auto_update_status
        ;;
    --force-auto-update)
        echo "🔄 بدء التحديث التلقائي القسري..."
        perform_auto_update
        ;;
    --self-update)
        echo "🔍 التحقق من التحديثات..."
        check_script_update
        ;;
    --tray)
        start_system_tray
        ;;
    --tray-restart)
        restart_system_tray
        ;;
    --tray-stop)
        stop_system_tray
        ;;
    --status)
        echo "📊 حالة GT-salat-dikr:"
        echo "═══════════════════════════════════════════"
        
        # تحميل الإعدادات أولاً
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
        fi
        
        notify_running=false
        
        # التحقق بناءً على نظام الخدمة المختار
        case "${NOTIFY_SYSTEM:-systemd}" in
            systemd)
                if command -v systemctl >/dev/null 2>&1 && \
                   systemctl --user is-active gt-salat-dikr >/dev/null 2>&1; then
                    echo "✅ الإشعارات: تعمل (نظام systemd)"
                    notify_running=true
                else
                    echo "❌ الإشعارات: متوقفة (نظام systemd)"
                fi
                ;;
            sysvinit|*)
                if [ -f "$PID_FILE" ]; then
                    pid=$(cat "$PID_FILE" 2>/dev/null)
                    if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
                        echo "✅ الإشعارات: تعمل (PID: $pid - sysvinit)"
                        notify_running=true
                    else
                        echo "❌ الإشعارات: متوقفة (sysvinit - ملف PID موجود لكن العملية متوقفة)"
                        rm -f "$PID_FILE" 2>/dev/null || true
                    fi
                else
                    echo "❌ الإشعارات: متوقفة (sysvinit)"
                fi
                ;;
        esac
        
        # إذا لم تكن تعمل بأي نظام، تحقق كحالة طارئة إذا كانت هناك عملية نشطة
        if [ "$notify_running" = false ] && [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE" 2>/dev/null)
            if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
                echo "⚠️  الإشعارات: تعمل (اكتشاف طارئ - PID: $pid)"
                notify_running=true
            else
                rm -f "$PID_FILE" 2>/dev/null || true
            fi
        fi
        
        echo ""
        if [ -f "$CONFIG_FILE" ]; then
            echo "📍 الموقع: ${CITY:-غير محدد}, ${COUNTRY:-غير محدد}"
            echo "🧭 الإحداثيات: ${LAT:-غير محدد}, ${LON:-غير محدد}"
            echo "📖 طريقة الحساب: ${METHOD_NAME:-غير محدد}"
            echo "⏰ التنبيه قبل الصلاة: ${PRE_PRAYER_NOTIFY} دقيقة"
            echo "🕊️ فاصل الأذكار: $((ZIKR_NOTIFY_INTERVAL/60)) دقيقة"
            echo "📊 نوع الأذان: ${ADHAN_TYPE:-full}"
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
        
        # عرض حالة التخزين المحلي بشكل محسن
        echo ""
        echo "💾 حالة التخزين المحلي:"
        if [ -d "$MONTHLY_TIMETABLE_DIR" ]; then
            file_count=$(find "$MONTHLY_TIMETABLE_DIR" -name "timetable_*.json" -type f 2>/dev/null | wc -l)
            if [ "$file_count" -gt 0 ]; then
                echo "  ✅ مخزن محلياً: $file_count شهر"
                
                # عرض تواريخ الملفات
                files=($(find "$MONTHLY_TIMETABLE_DIR" -name "timetable_*.json" -type f | sort))
                if [ ${#files[@]} -gt 0 ]; then
                    first_file="${files[0]}"
                    last_file="${files[${#files[@]}-1]}"
                    
                    first_date=$(basename "$first_file" | sed 's/timetable_\([0-9]*\)_\([0-9]*\).json/\1-\2/')
                    last_date=$(basename "$last_file" | sed 's/timetable_\([0-9]*\)_\([0-9]*\).json/\1-\2/')
                    echo "  📅 الفترة: $first_date إلى $last_date"
                    
                    # التحقق من وجود بيانات للشهر الحالي
                    current_year=$(date +%Y)
                    current_month=$(date +%m)
                    current_file="$MONTHLY_TIMETABLE_DIR/timetable_${current_year}_${current_month}.json"
                    if [ -f "$current_file" ]; then
                        echo "  🟢 البيانات الحالية: متوفرة"
                    else
                        echo "  🔴 البيانات الحالية: غير متوفرة"
                    fi
                fi
            else
                echo "  ❌ لا توجد بيانات محلية"
                echo "  💡 استخدم: gtsalat --update-timetables"
            fi
        else
            echo "  ❌ مجلد التخزين غير موجود"
            echo "  💡 استخدم: gtsalat --update-timetables"
        fi
        
        echo ""
        echo "🔄 حالة التحديث التلقائي:"
        show_auto_update_status
        
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
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار - الإصدار 3.2
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
  --test-adhan        اختبار الأذان الكامل
  --test-adhan-short  اختبار الأذان القصير
  --test-approaching  اختبار تنبيه الاقتراب

🔄 التحديث:
  --update-azkar          تحديث الأذكار
  --self-update           تحديث البرنامج
  --update-timetables     تحديث مواقيت الصلاة للأشهر القادمة
  --enable-auto-update    تفعيل التحديث التلقائي
  --disable-auto-update   تعطيل التحديث التلقائي
  --auto-update-status    عرض حالة التحديث التلقائي
  --force-auto-update     إجبار التحديث التلقائي الآن

🖥️  System Tray (شريط المهام):
  --tray              تشغيل أيقونة شريط المهام
  --tray-restart      إعادة تشغيل الأيقونة
  --tray-stop         إيقاف الأيقونة

ℹ️  --help, -h        هذه المساعدة

═══════════════════════════════════════════════════════════
💾 الميزة الجديدة: التخزين المحلي لمواقيت الصلاة
   - يمكن للبرنامج العمل بدون اتصال بالإنترنت
   - يتم تخزين بيانات 3 أشهر مسبقاً

🖥️  الميزة الجديدة: System Tray Icon
   - أيقونة في شريط المهام للتحكم السريع
   - عرض مواقيت الصلاة والصلاة القادمة
   - قائمة تحكم كاملة

🔄 الميزة الجديدة في الإصدار 3.2: التحديث التلقائي!
   - تحديث أسبوعي تلقائي لمواقيت الصلاة
   - تحكم كامل في تفعيل/تعطيل الميزة
   - إشعارات ذكية بعمليات التحديث
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
