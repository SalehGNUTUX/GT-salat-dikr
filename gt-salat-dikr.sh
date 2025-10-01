#!/bin/bash
#
# GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن
# Author: gnutux
#
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"

# تحديد مسار السكربت
if [ -n "${BASH_SOURCE:-}" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
else
    SCRIPT_SOURCE="$0"
fi

while [ -h "$SCRIPT_SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    case "$SCRIPT_SOURCE" in
        /*) ;;
        *) SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE" ;;
    esac
done
SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"

# ملفات التهيئة
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

# ---------------- دوال مساعدة ----------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

fetch_if_missing() {
    local file="$1" url="$2"
    if [ ! -f "$file" ]; then
        curl -fsSL "$url" -o "$file" 2>/dev/null || return 1
    fi
    return 0
}

ensure_dbus() {
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        local bus="/run/user/$(id -u)/bus"
        if [ -S "$bus" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        fi
    fi
}

# ---------------- دوال العرض ----------------
show_simple_zekr() {
    if [ ! -f "$AZKAR_FILE" ]; then
        echo "📿 لا يوجد أذكار"
        return 1
    fi
    
    local zekr
    zekr=$(awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1)
    
    if [ -n "$zekr" ]; then
        echo "📿 $zekr"
    else
        echo "📿 سبحان الله وبحمده"
    fi
}

show_next_prayer() {
    if [ ! -f "$TIMETABLE_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
        echo "🕌 جاري تحميل مواقيت الصلاة..."
        return 1
    fi
    
    source "$CONFIG_FILE"
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    local next_prayer next_time time_left
    
    for i in "${!names[@]}"; do
        local time
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" 2>/dev/null | cut -d' ' -f1)
        if [ "$time" = "null" ] || [ -z "$time" ]; then
            continue
        fi
        
        local h m prayer_secs diff
        h=${time%%:*}
        m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s 2>/dev/null || date -d "$h:$m" +%s 2>/dev/null)
        
        if [ -n "$prayer_secs" ]; then
            diff=$((prayer_secs - now_secs))
            if [ $diff -ge 0 ]; then
                next_prayer="${arnames[$i]}"
                next_time="$time"
                time_left=$diff
                break
            fi
        fi
    done
    
    if [ -n "$next_prayer" ]; then
        local left_min=$((time_left/60))
        local left_hr=$((left_min/60))
        local left_min=$((left_min%60))
        printf "🕌 %s: %s (باقي %02d:%02d)\n" "$next_prayer" "$next_time" "$left_hr" "$left_min"
    else
        echo "🕌 جاري تحديث مواقيت الصلاة..."
    fi
}

show_full_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ تعذر تحميل جدول المواقيت"
        return 1
    fi
    
    source "$CONFIG_FILE"
    echo "╔══════════════════════════════════════╗"
    echo "║         مواقيت الصلاة اليوم         ║"
    echo "║             ($CITY)              ║"
    echo "╠══════════════════════════════════════╣"
    
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    
    for i in "${!names[@]}"; do
        local time
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" 2>/dev/null | cut -d' ' -f1)
        if [ "$time" != "null" ] && [ -n "$time" ]; then
            printf "║ %-8s : %-8s ║\n" "${arnames[$i]}" "$time"
        fi
    done
    
    echo "╚══════════════════════════════════════╝"
}

fetch_timetable_silent() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    source "$CONFIG_FILE"
    
    if [ -z "$LAT" ] || [ -z "$LON" ]; then
        return 1
    fi
    
    local today url resp
    today=$(date +%Y-%m-%d)
    url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID:-1}&date=${today}"
    
    resp=$(curl -fsSL "$url" 2>/dev/null) || return 1
    echo "$resp" > "$TIMETABLE_FILE"
    log "تم تحديث جدول المواقيت"
}

# ---------------- دوال الإشعارات ----------------
start_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الإشعارات تعمل بالفعل"
            return 0
        else
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    ensure_dbus
    
    # بدء خدمة الإشعارات في الخلفية
    (
        cd "$SCRIPT_DIR"
        local last_zekr=0
        local zekr_interval=300
        
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
            zekr_interval="${ZIKR_NOTIFY_INTERVAL:-300}"
        fi
        
        while true; do
            local current_time=$(date +%s)
            
            # إرسال ذكر كل فترة
            if [ $((current_time - last_zekr)) -ge "$zekr_interval" ]; then
                if [ -f "$AZKAR_FILE" ]; then
                    local zekr
                    zekr=$(awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1)
                    if [ -n "$zekr" ]; then
                        notify-send "📿 ذكر" "$zekr" 2>/dev/null || true
                    fi
                fi
                last_zekr=$current_time
            fi
            
            sleep 60
        done
    ) >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
    echo "✅ بدأت الإشعارات التلقائية"
}

stop_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "✅ أوقفت الإشعارات"
        else
            echo "ℹ️ لا توجد إشعارات نشطة"
        fi
    else
        echo "ℹ️ لا توجد إشعارات نشطة"
    fi
}

# ---------------- دوال الاختبار ----------------
test_notify() {
    ensure_dbus
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "GT-salat-dikr" "اختبار إشعار ✔" -t 3000
        echo "✅ تم إرسال إشعار تجريبي"
    else
        echo "❌ notify-send غير متوفرة"
        return 1
    fi
}

test_adhan() {
    ensure_dbus
    if [ ! -f "$ADHAN_FILE" ]; then
        echo "❌ ملف الأذان غير موجود"
        return 1
    fi
    
    if command -v mpv >/dev/null 2>&1; then
        mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 &
        echo "✅ تشغيل الأذان التجريبي"
    elif command -v paplay >/dev/null 2>&1; then
        paplay "$ADHAN_FILE" >/dev/null 2>&1 &
        echo "✅ تشغيل الأذان التجريبي"
    else
        echo "❌ لم يتم العثور على مشغل صوت"
        return 1
    fi
}

# ---------------- دوال التحديث ----------------
update_azkar() {
    echo "⏳ جلب أحدث نسخة من الأذكار..."
    if curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE"; then
        echo "✅ تم تحديث الأذكار"
    else
        echo "❌ فشل في تحديث الأذكار"
        return 1
    fi
}

self_update() {
    echo "⏳ التحقق من التحديثات..."
    local current_hash new_hash temp_file
    current_hash=$(sha1sum "$SCRIPT_DIR/$SCRIPT_NAME" 2>/dev/null | awk '{print $1}' || echo "")
    new_hash=$(curl -fsSL "$REPO_SCRIPT_URL" | sha1sum | awk '{print $1}') || {
        echo "❌ فشل التحقق من التحديثات"
        return 1
    }
    
    if [ "$current_hash" != "$new_hash" ] && [ -n "$current_hash" ]; then
        echo "📦 يوجد تحديث جديد"
        read -p "هل تريد التحديث الآن؟ [Y/n]: " answer
        answer=${answer:-Y}
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            temp_file=$(mktemp)
            curl -fsSL "$REPO_SCRIPT_URL" -o "$temp_file" || {
                echo "❌ فشل تحميل التحديث"
                rm -f "$temp_file"
                return 1
            }
            chmod +x "$temp_file"
            mv "$temp_file" "$SCRIPT_DIR/$SCRIPT_NAME"
            echo "✅ تم التحديث بنجاح"
        fi
    else
        echo "✅ أنت باستخدام أحدث نسخة"
    fi
}

# ---------------- إعدادات ----------------
setup_wizard() {
    echo "⚙️  إعداد GT-salat-dikr"
    
    # اكتشاف الموقع التلقائي
    local info lat lon city country
    info=$(curl -fsSL "http://ip-api.com/json/" 2>/dev/null) || true
    
    if [ -n "$info" ]; then
        lat=$(echo "$info" | jq -r '.lat // empty' 2>/dev/null || echo "")
        lon=$(echo "$info" | jq -r '.lon // empty' 2>/dev/null || echo "")
        city=$(echo "$info" | jq -r '.city // empty' 2>/dev/null || echo "")
        country=$(echo "$info" | jq -r '.country // empty' 2>/dev/null || echo "")
        
        if [ -n "$lat" ] && [ -n "$lon" ]; then
            echo "📍 تم اكتشاف الموقع: $city, $country"
            read -p "هل تريد استخدام هذا الموقع؟ [Y/n]: " ans
            ans=${ans:-Y}
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                LAT="$lat"
                LON="$lon"
                CITY="$city"
                COUNTRY="$country"
            fi
        fi
    fi
    
    if [ -z "$LAT" ] || [ -z "$LON" ]; then
        echo "🌍 أدخل موقعك يدوياً:"
        read -p "خط العرض (مثال 33.9716): " LAT
        read -p "خط الطول (مثال -6.8498): " LON
        read -p "المدينة: " CITY
        read -p "الدولة: " COUNTRY
    fi
    
    METHOD_ID=1
    METHOD_NAME="Muslim World League"
    PRE_PRAYER_NOTIFY=1
    ZIKR_NOTIFY_INTERVAL=300
    
    # حفظ الإعدادات
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
LAT="$LAT"
LON="$LON"
CITY="$CITY"
COUNTRY="$COUNTRY"
METHOD_ID="$METHOD_ID"
METHOD_NAME="$METHOD_NAME"
PRE_PRAYER_NOTIFY=$PRE_PRAYER_NOTIFY
ZIKR_NOTIFY_INTERVAL=$ZIKR_NOTIFY_INTERVAL
AUTO_SELF_UPDATE=0
EOF
    
    # جلب المواقيت فوراً
    fetch_timetable_silent
    echo "✅ تم حفظ الإعدادات"
}

show_status() {
    echo "📊 حالة GT-salat-dikr:"
    echo "══════════════════════════════════════════════"
    
    # حالة الإشعارات
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الإشعارات: نشطة (PID: $pid)"
        else
            echo "❌ الإشعارات: متوقفة"
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    else
        echo "❌ الإشعارات: متوقفة"
    fi
    
    # الإعدادات
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "📍 الموقع: $CITY, $COUNTRY"
        echo "📅 طريقة الحساب: $METHOD_NAME"
        echo "⏰ تنبيه قبل الصلاة: $([ "$PRE_PRAYER_NOTIFY" = "1" ] && echo "مفعل" || echo "معطل")"
        echo "🔄 فاصل الأذكار: ${ZIKR_NOTIFY_INTERVAL:-300} ثانية"
    else
        echo "⚠️  الإعدادات: غير مهيئة"
    fi
    
    echo "📁 مجلد التثبيت: $INSTALL_DIR"
    echo "══════════════════════════════════════════════"
}

show_help() {
    echo "═══════════════════════════════════════════════════════════"
    echo "  GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📦 التثبيت والإزالة:"
    echo "  --install           تثبيت البرنامج مع autostart التلقائي"
    echo "  --uninstall         إزالة البرنامج بالكامل"
    echo ""
    echo "⚙️  الإعدادات:"
    echo "  --settings          تعديل الموقع والإعدادات"
    echo ""
    echo "📊 العرض:"
    echo "  --show-timetable    عرض جدول مواقيت الصلاة لليوم"
    echo "  --status            عرض حالة البرنامج التفصيلية"
    echo ""
    echo "🔔 الإشعارات:"
    echo "  --notify-start      بدء إشعارات الخلفية"
    echo "  --notify-stop       إيقاف إشعارات الخلفية"
    echo ""
    echo "🧪 الاختبار:"
    echo "  --test-notify       اختبار الإشعارات العادية"
    echo "  --test-adhan        اختبار مشغل الأذان الرسومي"
    echo ""
    echo "🔄 التحديث:"
    echo "  --update-azkar      تحديث ملف الأذكار"
    echo "  --self-update       تحديث البرنامج"
    echo ""
    echo "ℹ️  المساعدة:"
    echo "  --help, -h          عرض هذه المساعدة"
    echo "═══════════════════════════════════════════════════════════"
}

# ---------------- الوضع الافتراضي (خفيف) ----------------
main_light_mode() {
    # تحديث مواقيت الصلاة في الخلفية
    fetch_timetable_silent &
    
    # عرض الذكر
    show_simple_zekr
    
    # عرض الصلاة القادمة
    show_next_prayer
}

# ---------------- معالجة الأوامر ----------------
case "${1:-}" in
    --install)
        echo "ℹ️  البرنامج مثبت بالفعل في $INSTALL_DIR"
        ;;
    --uninstall)
        stop_notify_bg
        rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
        rm -rf "$INSTALL_DIR" 2>/dev/null || true
        echo "✅ تم إزالة GT-salat-dikr"
        ;;
    --settings)
        setup_wizard
        ;;
    --show-timetable|-t)
        show_full_timetable
        ;;
    --notify-start)
        start_notify_bg
        ;;
    --notify-stop)
        stop_notify_bg
        ;;
    --test-notify)
        test_notify
        ;;
    --test-adhan)
        test_adhan
        ;;
    --update-azkar)
        update_azkar
        ;;
    --self-update)
        self_update
        ;;
    --status)
        show_status
        ;;
    --help|-h)
        show_help
        ;;
    *)
        main_light_mode
        ;;
esac
