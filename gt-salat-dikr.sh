#!/bin/bash
#
# GT-salat-dikr - نسخة محسنة للعرض الخفيف
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

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

# ---------------- دوال العرض الخفيف ----------------
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

show_simple_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ]; then
        return 1
    fi
    
    local next_prayer next_time time_left
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    
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
}

# ---------------- الوضع الافتراضي (عرض خفيف) ----------------
main_light_mode() {
    # تحديث مواقيت الصلاة في الخلفية (صامت)
    fetch_timetable_silent &
    
    # عرض الذكر
    show_simple_zekr
    
    # عرض الصلاة القادمة
    show_simple_timetable
}

# ---------------- دوال الخدمة ----------------
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

    # بدء خدمة الإشعارات في الخلفية
    (
        cd "$SCRIPT_DIR"
        while true; do
            if [ -f "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE"
                local zekr_interval="${ZIKR_NOTIFY_INTERVAL:-300}"
                
                # إرسال ذكر
                local zekr
                zekr=$(awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" 2>/dev/null | shuf -n 1)
                if [ -n "$zekr" ]; then
                    notify-send "📿 ذكر" "$zekr" 2>/dev/null || true
                fi
            fi
            sleep "$zekr_interval"
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

setup_wizard() {
    echo "⚙️  إعداد GT-salat-dikr"
    
    # اكتشاف الموقع التلقائي
    local info
    info=$(curl -fsSL "http://ip-api.com/json/" 2>/dev/null) || true
    
    if [ -n "$info" ]; then
        LAT=$(echo "$info" | jq -r '.lat // empty' 2>/dev/null || echo "")
        LON=$(echo "$info" | jq -r '.lon // empty' 2>/dev/null || echo "")
        CITY=$(echo "$info" | jq -r '.city // empty' 2>/dev/null || echo "")
        COUNTRY=$(echo "$info" | jq -r '.country // empty' 2>/dev/null || echo "")
        
        if [ -n "$LAT" ] && [ -n "$LON" ]; then
            echo "📍 تم اكتشاف الموقع: $CITY, $COUNTRY"
            read -p "هل تريد استخدام هذا الموقع؟ [Y/n]: " ans
            ans=${ans:-Y}
            if [[ ! "$ans" =~ ^[Yy]$ ]]; then
                LAT=""
                LON=""
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
    
    echo "✅ تم حفظ الإعدادات"
}

# ---------------- معالجة الأوامر ----------------
case "${1:-}" in
    --notify-start)
        start_notify_bg
        ;;
    --notify-stop)
        stop_notify_bg
        ;;
    --settings)
        setup_wizard
        ;;
    --status)
        echo "📊 حالة GT-salat-dikr:"
        if [ -f "$PID_FILE" ]; then
            local pid
            pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "✅ الإشعارات: نشطة"
            else
                echo "❌ الإشعارات: متوقفة"
                rm -f "$PID_FILE" 2>/dev/null || true
            fi
        else
            echo "❌ الإشعارات: متوقفة"
        fi
        ;;
    --help|-h)
        echo "🕌 GT-salat-dikr - أوامر سريعة:"
        echo "  gtsalat           عرض ذكر ومواقيت الصلاة"
        echo "  gtsalat --notify-start  بدء الإشعارات"
        echo "  gtsalat --notify-stop   إيقاف الإشعارات"
        echo "  gtsalat --settings      تعديل الإعدادات"
        echo "  gtsalat --status        عرض الحالة"
        ;;
    *)
        main_light_mode
        ;;
esac
