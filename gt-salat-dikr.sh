#!/bin/bash

# --- إصلاح PATH لإضافة ~/.local/bin تلقائيًا ---
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;; # موجود بالفعل
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# ----------------------------------------------------------------

# --- دعم جميع أنواع الطرفيات ---
if [ -n "$BASH" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
    SCRIPT_SOURCE="${(%):-%x}"
else
    SCRIPT_SOURCE="$0"
fi

while [ -h "$SCRIPT_SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"

AZKAR_FILE="$SCRIPT_DIR/azkar.txt"
CONFIG_FILE="$SCRIPT_DIR/settings.conf"
TIMETABLE_FILE="$SCRIPT_DIR/timetable.json"
PID_FILE="$SCRIPT_DIR/.gt-salat-dikr-notify.pid"

ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"

# --- جلب ملف إذا لم يوجد محلياً ---
fetch_if_missing() {
    local file="$1"
    local url="$2"
    if [ ! -f "$file" ]; then
        echo "يتم تحميل $file من المستودع..."
        curl -fsSL "$url" -o "$file" || { echo "فشل تحميل $file."; exit 1; }
        echo "تم التحميل."
    fi
}

# --- التحقق من تحديث الأذكار في المستودع ---
check_azkar_update() {
    local local_hash remote_hash
    if [ -f "$AZKAR_FILE" ]; then
        local_hash=$(sha1sum "$AZKAR_FILE" | awk '{print $1}')
    else
        local_hash=""
    fi
    remote_hash=$(curl -fsSL "$REPO_AZKAR_URL" | sha1sum | awk '{print $1}')
    if [ "$local_hash" != "" ] && [ "$remote_hash" != "$local_hash" ]; then
        echo "يوجد تحديث جديد لملف الأذكار في المستودع."
        read -p "هل ترغب في جلب آخر نسخة من الأذكار؟ [Y/n]: " ans
        ans=${ans:-Y}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE" && echo "تم تحديث الأذكار."
        else
            echo "تم الإبقاء على ملف الأذكار الحالي."
        fi
    fi
}

# --- تحقق من وجود البرنامج الأساسي وملف الأذكار وجلبهم عند الحاجة ---
fetch_if_missing "$0" "$REPO_SCRIPT_URL"
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL"
check_azkar_update

# --- طرق الحساب حسب Aladhan API ---
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

# ----------------- دوال -----------------
auto_detect_location() {
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

manual_location() {
    read -p "أدخل خط العرض (مثال 24.7136): " LAT
    read -p "أدخل خط الطول (مثال 46.6753): " LON
    read -p "أدخل المدينة: " CITY
    read -p "أدخل الدولة: " COUNTRY
}

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

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        return 1
    fi
}

change_settings() {
    echo "---- إعدادات GT-salat-dikr ----"
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

show_zekr_notify() {
    local zekr
    zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then
        notify-send "GT-salat-dikr" "لم يتم العثور على ذكر!"
    else
        notify-send "GT-salat-dikr" "$zekr"
    fi
}

show_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"
    local t="$PRAYER_TIME"
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة $p ($t)"
}

show_pre_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"
    local t="$PRAYER_TIME"
    notify-send "GT-salat-dikr" "تبقى 10 دقائق على صلاة $p ($t)"
}

notify_loop() {
    # تعيين trap لتنظيف PID عند الخروج
    trap 'rm -f "$PID_FILE" 2>/dev/null' EXIT
    
    while true; do
        show_zekr_notify
        get_next_prayer
        
        local now_secs=$(date +%s)
        local notify_flag_file="$SCRIPT_DIR/.last-prayer-notified"
        local pre_notify_flag_file="$SCRIPT_DIR/.last-preprayer-notified"
        
        # إشعار قبل الصلاة بـ10 دقائق
        if [ "$PRE_PRAYER_NOTIFY" = "1" ] && [ $PRAYER_LEFT -le 600 ] && [ $PRAYER_LEFT -gt 540 ]; then
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

start_notify() {
    # التحقق إذا كانت الإشعارات تعمل بالفعل
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo "الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        else
            # تنظيف ملف PID إذا كانت العملية غير موجودة
            rm -f "$PID_FILE"
        fi
    fi

    echo "بدء إشعارات GT-salat-dikr..."
    
    # بدء عملية الإشعارات في الخلفية بشكل صحيح
    nohup bash -c '
        while true; do
            # استدعاء دالة الإشعارات
            source "$0"  # إعادة تحميل الدوال
            notify_loop
        done
    ' "$SCRIPT_SOURCE" > /dev/null 2>&1 &
    
    local loop_pid=$!
    echo $loop_pid > "$PID_FILE"
    
    # الانتظار قليلاً للتأكد من بدء العملية
    sleep 2
    
    if kill -0 $loop_pid 2>/dev/null; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $loop_pid)"
    else
        echo "❌ فشل في بدء الإشعارات"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_notify() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        
        if kill -0 $pid 2>/dev/null; then
            # إيقاف العملية الرئيسية وكل العمليات الفرعية
            pkill -P $pid 2>/dev/null
            kill $pid 2>/dev/null
            
            # الانتظار للتأكد من التوقف
            sleep 1
            
            if kill -0 $pid 2>/dev/null; then
                # إذا لم تتوقف، استخدام kill قوي
                kill -9 $pid 2>/dev/null
            fi
            
            rm -f "$PID_FILE"
            echo "✅ تم إيقاف إشعارات GT-salat-dikr (PID: $pid)"
        else
            echo "⚠️  لم تكن هناك إشعارات قيد التشغيل (PID: $pid غير نشط)"
            rm -f "$PID_FILE"
        fi
    else
        echo "ℹ️  لا يوجد إشعارات قيد التشغيل (لا يوجد ملف PID)"
        
        # محاولة إيجاد وإيقاف أي عمليات متبقية
        local pids=$(pgrep -f "gt-salat-dikr" | grep -v $$ | tr '\n' ' ')
        if [ -n "$pids" ]; then
            echo "⚠️  وجد عمليات متبقية، يتم إيقافها: $pids"
            pkill -f "gt-salat-dikr" 2>/dev/null
            sleep 1
            pkill -9 -f "gt-salat-dikr" 2>/dev/null
            echo "✅ تم تنظيف العمليات المتبقية"
        fi
    fi
    
    # تنظيف ملفات flag
    rm -f "$SCRIPT_DIR/.last-prayer-notified" "$SCRIPT_DIR/.last-preprayer-notified" 2>/dev/null
}

# -------------- تنفيذ السكربت --------------

if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
fi

load_config

case "$1" in
    --show-timetable | t)
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
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE" && echo "✅ تم تحديث الأذكار بنجاح"
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
