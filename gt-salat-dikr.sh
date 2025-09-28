#!/bin/bash
# GT-salat-dikr - النسخة النهائية المُصلحة

set -euo pipefail

# --- مسارات ثابتة ---
SCRIPT_DIR="$HOME/.GT-salat-dikr"
AZKAR_FILE="$SCRIPT_DIR/azkar.txt"
CONFIG_FILE="$SCRIPT_DIR/settings.conf"
TIMETABLE_FILE="$SCRIPT_DIR/timetable.json"
PID_FILE="$SCRIPT_DIR/.gt-salat-dikr-notify.pid"
ADHAN_FILE="$SCRIPT_DIR/adhan.ogg"
LOG_FILE="$SCRIPT_DIR/notify.log"

ALADHAN_API_URL="https://api.aladhan.com/v1/timings"
REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"

# ---------------- تحميل الإعدادات ----------------
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        return 1
    fi
}

# ---------------- عرض مواقيت الصلاة ----------------
show_timetable() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ لم يتم إعداد الإعدادات بعد. جرب: gtsalat --settings"
        return 1
    fi
    
    source "$CONFIG_FILE"
    TODAY=$(date +%Y-%m-%d)
    URL="$ALADHAN_API_URL/$TODAY?latitude=$LAT&longitude=$LON&method=$METHOD_ID"
    
    if curl -fsSL "$URL" -o "$TIMETABLE_FILE"; then
        echo "مواقيت الصلاة اليوم ($CITY):"
        echo "================================"
        
        PRAYERS=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
        AR_NAMES=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
        NOW_SECS=$(date +%s)
        
        for i in "${!PRAYERS[@]}"; do
            TIME=$(jq -r ".data.timings.${PRAYERS[$i]}" "$TIMETABLE_FILE" | cut -d" " -f1)
            if [ "$TIME" != "null" ]; then
                PRAYER_SECS=$(date -d "$(date +%Y-%m-%d) $TIME" +%s 2>/dev/null || date -d "$TIME" +%s)
                DIFF=$((PRAYER_SECS - NOW_SECS))
                
                if [ $DIFF -ge 0 ]; then
                    HOURS=$((DIFF / 3600))
                    MINUTES=$(((DIFF % 3600) / 60))
                    printf "%-8s: %s (باقي %02d:%02d)\n" "${AR_NAMES[$i]}" "$TIME" "$HOURS" "$MINUTES"
                else
                    printf "%-8s: %s (مرت)\n" "${AR_NAMES[$i]}" "$TIME"
                fi
            fi
        done
    else
        echo "❌ تعذر جلب مواقيت الصلاة"
    fi
}

# ---------------- إعدادات الأولية ----------------
setup_wizard() {
    echo "🎯 إعداد GT-salat-dikr"
    echo "======================"
    
    # كشف الموقع التلقائي
    echo "🔍 جاري كشف موقعك التلقائي..."
    if curl -fsSL "http://ip-api.com/json/" | jq -r '"\(.lat),\(.lon),\(.city),\(.country)"' > /tmp/location.txt 2>/dev/null; then
        LAT=$(cut -d, -f1 /tmp/location.txt)
        LON=$(cut -d, -f2 /tmp/location.txt)
        CITY=$(cut -d, -f3 /tmp/location.txt)
        COUNTRY=$(cut -d, -f4 /tmp/location.txt)
        echo "✅ تم تحديد موقعك: $CITY, $COUNTRY"
    else
        echo "❌ تعذر كشف الموقع تلقائياً"
        read -p "📌 أدخل خط العرض (مثال 24.7136): " LAT
        read -p "📌 أدخل خط الطول (مثال 46.6753): " LON
        read -p "🏙️  أدخل المدينة: " CITY
        read -p "🌍 أدخل الدولة: " COUNTRY
    fi
    
    # طريقة الحساب
    echo "📊 اختر طريقة حساب مواقيت الصلاة:"
    echo "1) Muslim World League"
    echo "2) Egyptian General Authority of Survey"
    echo "3) Umm Al-Qura University, Makkah"
    read -p "اختر رقم الطريقة [1]: " METHOD_CHOICE
    METHOD_CHOICE=${METHOD_CHOICE:-1}
    
    case $METHOD_CHOICE in
        1) METHOD_ID=3 ;;
        2) METHOD_ID=5 ;;
        3) METHOD_ID=4 ;;
        *) METHOD_ID=3 ;;
    esac
    
    # الإعدادات
    read -p "🔔 هل تريد التنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " PRE_ANS
    PRE_ANS=${PRE_ANS:-Y}
    PRE_PRAYER_NOTIFY=$([ "$PRE_ANS" =~ ^[Yy]$ ] && echo 1 || echo 0)
    
    # حفظ الإعدادات
    cat > "$CONFIG_FILE" <<EOF
LAT="$LAT"
LON="$LON"
CITY="$CITY"
COUNTRY="$COUNTRY"
METHOD_ID="$METHOD_ID"
PRE_PRAYER_NOTIFY="$PRE_PRAYER_NOTIFY"
EOF
    
    echo "✅ تم حفظ الإعدادات بنجاح"
}

# ---------------- حلقة الإشعارات الرئيسية ----------------
notify_loop() {
    echo "🔄 بدء حلقة الإشعارات..." >> "$LOG_FILE"
    
    while true; do
        # تحميل الإعدادات في كل دورة
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
        else
            echo "❌ ملف الإعدادات مفقود" >> "$LOG_FILE"
            sleep 60
            continue
        fi
        
        # 1. إشعار الأذكار العشوائي
        if [ -f "$AZKAR_FILE" ]; then
            ZEKR=$(awk -v RS="%" '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>20) print $0}' "$AZKAR_FILE" | shuf -n 1)
            if [ -n "$ZEKR" ]; then
                notify-send "📿 ذكر" "$ZEKR"
                echo "📨 تم إرسال ذكر: $(echo "$ZEKR" | head -c 50)..." >> "$LOG_FILE"
            fi
        fi
        
        # 2. التحقق من مواقيت الصلاة
        TODAY=$(date +%Y-%m-%d)
        URL="$ALADHAN_API_URL/$TODAY?latitude=$LAT&longitude=$LON&method=$METHOD_ID"
        
        if curl -fsSL "$URL" -o "$TIMETABLE_FILE"; then
            PRAYERS=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
            AR_NAMES=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
            NOW_SECS=$(date +%s)
            
            for i in "${!PRAYERS[@]}"; do
                TIME=$(jq -r ".data.timings.${PRAYERS[$i]}" "$TIMETABLE_FILE" | cut -d" " -f1)
                if [ "$TIME" != "null" ]; then
                    PRAYER_SECS=$(date -d "$(date +%Y-%m-%d) $TIME" +%s 2>/dev/null || date -d "$TIME" +%s)
                    DIFF=$((PRAYER_SECS - NOW_SECS))
                    
                    # إشعار قبل الصلاة بـ10 دقائق
                    if [ "$PRE_PRAYER_NOTIFY" = "1" ] && [ $DIFF -le 600 ] && [ $DIFF -gt 0 ]; then
                        echo "⏰ إشعار قبل الصلاة: ${AR_NAMES[$i]} ($TIME)" >> "$LOG_FILE"
                        notify-send "🕌 صلاة قريبة" "تبقى 10 دقائق على صلاة ${AR_NAMES[$i]} ($TIME)"
                    fi
                    
                    # إشعار وقت الصلاة
                    if [ $DIFF -le 0 ] && [ $DIFF -gt -300 ]; then
                        echo "🕌 إشعار وقت الصلاة: ${AR_NAMES[$i]}" >> "$LOG_FILE"
                        notify-send "🕌 حان وقت الصلاة" "حان الآن وقت صلاة ${AR_NAMES[$i]} ($TIME)"
                        
                        # تشغيل الأذان إن وجد
                        if [ -f "$ADHAN_FILE" ]; then
                            if command -v mpv >/dev/null 2>&1; then
                                mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 &
                            elif command -v paplay >/dev/null 2>&1; then
                                paplay "$ADHAN_FILE" >/dev/null 2>&1 &
                            fi
                        fi
                    fi
                fi
            done
        else
            echo "❌ فشل جلب مواقيت الصلاة" >> "$LOG_FILE"
        fi
        
        # الانتظار 5 دقائق بين كل دورة
        sleep 300
    done
}

# ---------------- إدارة الإشعارات ----------------
start_notify() {
    cd "$SCRIPT_DIR" || { echo "❌ فشل الانتقال إلى $SCRIPT_DIR"; return 1; }
    
    # أوقف أي عمليات سابقة
    stop_notify >/dev/null 2>&1
    
    echo "🚀 بدء إشعارات GT-salat-dikr..."
    
    # ابدأ العملية في الخلفية
    nohup bash -c '
        cd "'"$SCRIPT_DIR"'"
        "'"$SCRIPT_DIR"'/gt-salat-dikr.sh" notify_loop
    ' > "$LOG_FILE" 2>&1 &
    
    local LOOP_PID=$!
    echo "$LOOP_PID" > "$PID_FILE"
    
    sleep 2
    if kill -0 "$LOOP_PID" 2>/dev/null; then
        echo "✅ تم بدء الإشعارات (PID: $LOOP_PID)"
        echo "📋 السجلات: $LOG_FILE"
    else
        echo "❌ فشل في بدء الإشعارات"
        rm -f "$PID_FILE"
    fi
}

stop_notify() {
    cd "$SCRIPT_DIR" || return 1
    
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
            sleep 1
            rm -f "$PID_FILE"
            echo "✅ تم إيقاف الإشعارات"
        else
            echo "ℹ️ لا توجد إشعارات شغالة"
            rm -f "$PID_FILE"
        fi
    else
        echo "ℹ️ لا توجد إشعارات شغالة"
    fi
    
    # تنظيف إضافي
    pkill -f "gt-salat-dikr" 2>/dev/null || true
}

# ---------------- الواجهة الرئيسية ----------------
case "${1:-}" in
    --show-timetable|t)
        show_timetable
        ;;
    --settings)
        setup_wizard
        ;;
    --notify-start)
        start_notify
        ;;
    --notify-stop)
        stop_notify
        ;;
    --update-azkar)
        echo "📥 جاري تحديث الأذكار..."
        if curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE"; then
            echo "✅ تم تحديث الأذكار بنجاح"
        else
            echo "❌ فشل تحديث الأذكار"
        fi
        ;;
    notify_loop)
        # هذا للاستخدام الداخلي فقط
        notify_loop
        ;;
    --help|-h)
        echo "🌙 GT-salat-dikr - مساعد الصلاة والأذكار"
        echo "======================================"
        echo "gtsalat                    عرض ذكر ومواقيت الصلاة"
        echo "gtsalat --show-timetable   عرض مواقيت الصلاة كاملة"
        echo "gtsalat --notify-start     بدء الإشعارات التلقائية"
        echo "gtsalat --notify-stop      إيقاف الإشعارات التلقائية"
        echo "gtsalat --settings         تغيير الإعدادات"
        echo "gtsalat --update-azkar     تحديث قائمة الأذكار"
        echo "gtsalat --help             عرض هذه المساعدة"
        ;;
    *)
        # الوضع العادي: عرض ذكر ومواقيت الصلاة
        if [ -f "$AZKAR_FILE" ]; then
            ZEKR=$(awk -v RS="%" '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>20) print $0}' "$AZKAR_FILE" | shuf -n 1)
            if [ -n "$ZEKR" ]; then
                echo "📿 $ZEKR"
                echo ""
            fi
        fi
        
        show_timetable
        ;;
esac
