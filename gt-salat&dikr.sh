#!/bin/bash

# إعداد المسارات
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AZKAR_FILE="$SCRIPT_DIR/azkar.txt"
CONFIG_FILE="$SCRIPT_DIR/settings.conf"
TIMETABLE_FILE="$SCRIPT_DIR/timetable.json"
PID_FILE="$SCRIPT_DIR/.gt-salat&dikr-notify.pid"

ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

# قائمة طرق الحساب حسب https://aladhan.com/calculation-methods
METHODS=("Muslim World League"
"Islamic Society of North America"
"Egyptian General Authority of Survey"
"Umm Al-Qura University, Makkah"
"University of Islamic Sciences, Karachi"
"Institute of Geophysics, University of Tehran"
"Shia Ithna-Ashari, Leva Institute, Qum"
"Gulf Region"
"Kuwait"
"Qatar"
"Majlis Ugama Islam Singapura, Singapore"
"Union Organization islamic de France"
"Diyanet İşleri Başkanlığı, Turkey"
"Spiritual Administration of Muslims of Russia"
"Moonsighting Committee"
"Dubai, UAE"
"Jabatan Kemajuan Islam Malaysia (JAKIM)"
"Tunisia"
"Algeria"
"Kementerian Agama Republik Indonesia"
"Morocco"
"Comunidate Islamica de Lisboa (Portugal)")

METHOD_IDS=(3 2 5 4 1 7 8 9 10 11 12 13 14 15 16 18 24 19 20 21 22 23)

# ----------------- دوال مساعدة -----------------

# استعلام الموقع تلقائيا
auto_detect_location() {
    # استخدم ip-api.com
    local info
    info=$(curl -fsSL "http://ip-api.com/json/")
    LAT=$(echo "$info" | jq '.lat')
    LON=$(echo "$info" | jq '.lon')
    CITY=$(echo "$info" | jq -r '.city')
    COUNTRY=$(echo "$info" | jq -r '.country')
    if [[ -z "$LAT" || -z "$LON" || "$LAT" == "null" || "$LON" == "null" ]]; then
        return 1
    fi
    return 0
}

# استعلام الموقع يدويا
manual_location() {
    read -p "أدخل خط العرض (مثال 24.7136): " LAT
    read -p "أدخل خط الطول (مثال 46.6753): " LON
    read -p "أدخل المدينة: " CITY
    read -p "أدخل الدولة: " COUNTRY
}

# اختيار طريقة الحساب
choose_method() {
    echo "يرجى اختيار طريقة حساب مواقيت الصلاة:"
    for i in "${!METHODS[@]}"; do
        printf "%2d) %s\n" "$((i+1))" "${METHODS[$i]}"
    done
    while true; do
        read -p "اختر الرقم المناسب [افتراضي 1]: " idx
        idx=${idx:-1}
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#METHODS[@]} ]; then
            METHOD_IDX=$((idx-1))
            METHOD_NAME="${METHODS[$METHOD_IDX]}"
            METHOD_ID="${METHOD_IDS[$METHOD_IDX]}"
            break
        fi
        echo "اختيار غير صحيح! حاول مجددًا."
    done
}

# حفظ الإعدادات
save_config() {
    cat > "$CONFIG_FILE" <<EOF
LAT="$LAT"
LON="$LON"
CITY="$CITY"
COUNTRY="$COUNTRY"
METHOD_ID="$METHOD_ID"
METHOD_NAME="$METHOD_NAME"
PRE_PRAYER_NOTIFY=1
ZIKR_NOTIFY_INTERVAL=300
EOF
}

# قراءة الإعدادات
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        return 1
    fi
}

# تغيير الإعدادات
change_settings() {
    echo "---- إعدادات GT-salat&dikr ----"
    echo "1) الموقع الحالي: $CITY, $COUNTRY (خط العرض: $LAT, خط الطول: $LON)"
    echo "2) طريقة الحساب الحالية: $METHOD_NAME"
    echo "3) تفعيل تنبيه قبل الصلاة بـ10 دقائق: $( [ "$PRE_PRAYER_NOTIFY" -eq 1 ] && echo "مفعل" || echo "معطل" )"
    echo "4) الفاصل الزمني لإشعار الأذكار (بالثواني): $ZIKR_NOTIFY_INTERVAL"
    echo "5) تغيير جميع الإعدادات"
    echo "0) خروج"
    read -p "اختر رقم الإعداد لتغييره (أو 0 للخروج): " opt
    case "$opt" in
        1)
            manual_location
            save_config
            ;;
        2)
            choose_method
            save_config
            ;;
        3)
            if [ "$PRE_PRAYER_NOTIFY" -eq 1 ]; then
                PRE_PRAYER_NOTIFY=0
            else
                PRE_PRAYER_NOTIFY=1
            fi
            save_config
            ;;
        4)
            read -p "أدخل الفاصل الزمني بالإشعار (ثواني): " ZIKR_NOTIFY_INTERVAL
            save_config
            ;;
        5)
            setup_wizard
            ;;
        *)
            ;;
    esac
}

# معالج الإعدادات الأولية
setup_wizard() {
    echo "---- إعداد الموقع ----"
    if auto_detect_location; then
        echo "تم تحديد موقعك تلقائيًا: $CITY, $COUNTRY (خط العرض: $LAT, خط الطول: $LON)"
        read -p "هل ترغب باعتماد هذا الموقع؟ [Y/n]: " ans
        ans=${ans:-Y}
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            manual_location
        fi
    else
        echo "تعذر تحديد الموقع تلقائيًا، أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    save_config
}

# جلب مواقيت الصلاة وتخزينها محليًا
fetch_timetable() {
    local today
    today=$(date +%Y-%m-%d)
    local url="$ALADHAN_API_URL?latitude=$LAT&longitude=$LON&method=$METHOD_ID&date=$today"
    local resp
    resp=$(curl -fsSL "$url")
    if [ $? -ne 0 ] || [[ "$resp" == "" ]]; then
        echo "تعذر جلب مواقيت الصلاة من الإنترنت."
        return 1
    fi
    echo "$resp" > "$TIMETABLE_FILE"
    return 0
}

# قراءة مواقيت الصلاة من الملف
read_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ]; then
        fetch_timetable || return 1
    fi
    local tdate
    tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE")
    today=$(date +%d-%m-%Y)
    if [ "$tdate" != "$(date +%d-%m-%Y)" ]; then
        fetch_timetable || return 1
    fi
}

# عرض جميع المواقيت
show_timetable() {
    read_timetable || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    local next_idx=-1
    local min_diff=99999
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        # تنسيق الوقت
        h=$(echo "$time" | cut -d: -f1)
        m=$(echo "$time" | cut -d: -f2)
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ] && [ $diff -lt $min_diff ]; then
            min_diff=$diff
            next_idx=$i
        fi
        printf "%10s: %s" "${arnames[$i]}" "$time"
        if [ $diff -ge 0 ]; then
            printf " (باقي %02d:%02d)" $((diff/3600)) $(((diff%3600)/60))
        fi
        [ $i -eq $next_idx ] && printf "  ← القادمة"
        echo
    done
}

# حساب الصلاة القادمة
get_next_prayer() {
    read_timetable || return 1
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        h=$(echo "$time" | cut -d: -f1)
        m=$(echo "$time" | cut -d: -f2)
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    # إذا انتهت كل الصلوات اليوم
    PRAYER_NAME="${arnames[0]}"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)" +%s) - now_secs ))
    return 0
}

# عرض ذكر عشوائي
show_random_zekr() {
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_terminal() {
    local zekr
    zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then
        echo "لم يتم العثور على ذكر!"
        return 1
    fi
    echo "$zekr"
}

# إشعار ذكر عشوائي
show_zekr_notify() {
    local zekr
    zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then
        notify-send "GT-salat&dikr" "لم يتم العثور على ذكر!"
    else
        notify-send "GT-salat&dikr" "$zekr"
    fi
}

# إشعار بالصلاة
show_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"
    local t="$PRAYER_TIME"
    notify-send "GT-salat&dikr" "حان الآن وقت صلاة $p ($t)"
}

# إشعار قبل الصلاة بـ10 دقائق
show_pre_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"
    local t="$PRAYER_TIME"
    notify-send "GT-salat&dikr" "تبقى 10 دقائق على صلاة $p ($t)"
}

# حلقة الإشعار الدورية
notify_loop() {
    while true; do
        # إشعار الذكر
        show_zekr_notify
        # تحقق من وقت الصلاة
        get_next_prayer
        local now_secs=$(date +%s)
        local notify_flag_file="$SCRIPT_DIR/.last-prayer-notified"
        local pre_notify_flag_file="$SCRIPT_DIR/.last-preprayer-notified"
        # إشعار قبل الصلاة بـ10 دقائق
        if [ "$PRE_PRAYER_NOTIFY" = "1" ] && [ $PRAYER_LEFT -le 600 ] && [ $PRAYER_LEFT -gt 540 ]; then
            # لا تعيد الإشعار لنفس الصلاة
            if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_pre_prayer_notify
                echo "$PRAYER_NAME" > "$pre_notify_flag_file"
            fi
        fi
        # إشعار دخول وقت الصلاة
        if [ $PRAYER_LEFT -le 10 ] && [ $PRAYER_LEFT -ge -10 ]; then
            if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_prayer_notify
                echo "$PRAYER_NAME" > "$notify_flag_file"
            fi
        fi
        sleep "$ZIKR_NOTIFY_INTERVAL"
    done
}

# بدء إشعارات النظام
start_notify() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "الإشعارات تعمل بالفعل (PID: $(cat "$PID_FILE"))"
        exit 0
    fi
    (notify_loop &)
    echo $! > "$PID_FILE"
    disown
    echo "تم بدء إشعارات GT-salat&dikr"
}

# إيقاف إشعارات النظام
stop_notify() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            echo "تم إيقاف إشعارات GT-salat&dikr (PID: $pid)"
        else
            echo "لم يكن هناك إشعارات قيد التشغيل."
        fi
        rm -f "$PID_FILE"
    else
        echo "لا يوجد إشعارات قيد التشغيل."
    fi
}

# -------------- تنفيذ السكربت --------------

if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
fi

load_config

case "$1" in
    --show-timetable)
        show_timetable
        ;;
    --settings)
        change_settings
        ;;
    --notify-start)
        start_notify
        ;;
    --notify-stop)
        stop_notify
        ;;
    *)
        # الوضع الافتراضي: عند فتح الطرفية
        show_zekr_terminal
        get_next_prayer
        leftmin=$((PRAYER_LEFT/60))
        lefth=$((leftmin/60))
        leftm=$((leftmin%60))
        printf "\e[1;34mالصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "$PRAYER_NAME" "$PRAYER_TIME" "$lefth" "$leftm"
        ;;
esac
