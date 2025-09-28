#!/bin/bash
# GT-salat-dikr - نسخة مُعدّلة: دعم adhan.ogg + تحديث ذاتي + إصلاح notify loop
# ملاحظة: هذه النسخة مبنية على سكربتك الأصلية (راجع المستودع). :contentReference[oaicite:2]{index=2}

set -euo pipefail

# --- مسارات و URLs ---
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

if [ -n "${BASH_SOURCE-}" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION-}" ]; then
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

SCRIPT_NAME="$(basename "$SCRIPT_SOURCE")"
SCRIPT_SOURCE_ABS="$SCRIPT_DIR/$SCRIPT_NAME"

AZKAR_FILE="$SCRIPT_DIR/azkar.txt"
CONFIG_FILE="$SCRIPT_DIR/settings.conf"
TIMETABLE_FILE="$SCRIPT_DIR/timetable.json"
PID_FILE="$SCRIPT_DIR/.gt-salat-dikr-notify.pid"
ADHAN_FILE="$SCRIPT_DIR/adhan.ogg"

ALADHAN_API_URL="https://api.aladhan.com/v1/timings"
REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"

# ---------------- utilities ----------------
fetch_if_missing() {
    local file="$1"; local url="$2"
    if [ ! -f "$file" ]; then
        echo "يتم تحميل $file من المستودع..."
        curl -fsSL "$url" -o "$file" || { echo "فشل تحميل $file."; return 1; }
        echo "تم التحميل."
    fi
}

# check azkar update (كما في الأصل)
check_azkar_update() {
    local local_hash remote_hash
    if [ -f "$AZKAR_FILE" ]; then
        local_hash=$(sha1sum "$AZKAR_FILE" | awk '{print $1}')
    else
        local_hash=""
    fi
    remote_hash=$(curl -fsSL "$REPO_AZKAR_URL" | sha1sum | awk '{print $1}') || return 0
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

# ---------------- config default ----------------
# إذا لم يوجد ملف الإعداد، سيُنشئه setup_wizard
DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

# ---------------- حسابات Aladhan (نُسخة أصلية) ----------------
METHODS=( "Muslim World League" "Islamic Society of North America" "Egyptian General Authority of Survey" \
"Umm Al-Qura University, Makkah" "University of Islamic Sciences, Karachi" "Institute of Geophysics, University of Tehran" \
"Shia Ithna-Ashari, Leva Institute, Qum" "Gulf Region" "Kuwait" "Qatar" "Majlis Ugama Islam Singapura, Singapore" \
"Union Organization islamic de France" "Diyanet İşleri Başkanlığı, Turkey" "Spiritual Administration of Muslims of Russia" \
"Moonsighting Committee" "Dubai, UAE" "Jabatan Kemajuan Islam Malaysia (JAKIM)" "Tunisia" "Algeria" \
"Kementerian Agama Republik Indonesia" "Morocco" "Comunidate Islamica de Lisboa (Portugal)" )

METHOD_IDS=(3 2 5 4 1 7 8 9 10 11 12 13 14 15 16 18 24 19 20 21 22 23)

# ---------------- location & timetable ----------------
auto_detect_location() {
    local info
    info=$(curl -fsSL "http://ip-api.com/json/") || return 1
    LAT=$(echo "$info" | jq '.lat')
    LON=$(echo "$info" | jq '.lon')
    CITY=$(echo "$info" | jq -r '.city')
    COUNTRY=$(echo "$info" | jq -r '.country')
    if [[ -z "$LAT" || -z "$LON" || "$LAT" == "null" || "$LON" == "null" ]]; then return 1; fi
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
PRE_PRAYER_NOTIFY=${PRE_PRAYER_NOTIFY:-$DEFAULT_PRE_NOTIFY}
ZIKR_NOTIFY_INTERVAL=${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}
AUTO_SELF_UPDATE=${AUTO_SELF_UPDATE:-0}
EOF
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    else
        return 1
    fi
}

setup_wizard() {
    echo "---- إعداد الموقع ----"
    if auto_detect_location; then
        echo "تم تحديد موقعك تلقائيًا: $CITY, $COUNTRY (خط العرض: $LAT, خط الطول: $LON)"
        read -p "هل ترغب باعتماد هذا الموقع؟ [Y/n]: " ans
        ans=${ans:-Y}
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then manual_location; fi
    else
        echo "تعذر تحديد الموقع تلقائيًا، أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    read -p "هل تود تفعيل التنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; p=${p:-Y}; PRE_PRAYER_NOTIFY=$([ "$p" =~ ^[Yy]$ ] && echo 1 || echo 0)
    read -p "الفاصل الزمني لإشعارات الأذكار بالثواني (افتراضي 300): " z; ZIKR_NOTIFY_INTERVAL=${z:-300}
    read -p "هل تود تفعيل التحديث الذاتي للسكريبت عند توفر تحديث؟ [y/N]: " up; up=${up:-N}; AUTO_SELF_UPDATE=$([ "$up" =~ ^[Yy]$ ] && echo 1 || echo 0)
    save_config
}

# ---------------- timetable ----------------
fetch_timetable() {
    local today
    today=$(date +%Y-%m-%d)
    local url="$ALADHAN_API_URL?latitude=$LAT&longitude=$LON&method=$METHOD_ID&date=$today"
    local resp
    resp=$(curl -fsSL "$url") || { echo "تعذر جلب مواقيت الصلاة من الإنترنت."; return 1; }
    echo "$resp" > "$TIMETABLE_FILE"
    return 0
}

read_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ]; then fetch_timetable || return 1; fi
    local tdate
    tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE")
    if [ "$tdate" != "$(date +%d-%m-%Y)" ]; then fetch_timetable || return 1; fi
}

show_timetable() {
    read_timetable || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    local next_idx=-1; local min_diff=99999
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        h=${time%%:*}; m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ] && [ $diff -lt $min_diff ]; then min_diff=$diff; next_idx=$i; fi
        printf "%10s: %s" "${arnames[$i]}" "$time"
        if [ $diff -ge 0 ]; then printf " (باقي %02d:%02d)" $((diff/3600)) $(((diff%3600)/60)); fi
        [ $i -eq $next_idx ] && printf "  ← القادمة"
        echo
    done
}

# ---------------- zikr selection ----------------
show_random_zekr() {
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_terminal() {
    local zekr; zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then echo "لم يتم العثور على ذكر!"; return 1; fi
    echo "$zekr"
}

show_zekr_notify() {
    local zekr; zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then notify-send "GT-salat-dikr" "لم يتم العثور على ذكر!"; else notify-send "GT-salat-dikr" "$zekr"; fi
}

# ---------------- adhan play ----------------
play_adhan() {
    [ -z "${ADHAN_FILE-}" ] && return 1
    [ ! -f "$ADHAN_FILE" ] && return 1

    if command -v mpv >/dev/null 2>&1; then
        mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v ogg123 >/dev/null 2>&1; then
        ogg123 -q "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then
        paplay "$ADHAN_FILE" >/dev/null 2>&1 &
    else
        (sleep 0.1; printf '\a') &
    fi
    return 0
}

# ---------------- prayer notify messages ----------------
show_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"; local t="$PRAYER_TIME"
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة $p ($t)"
    play_adhan || true
}

show_pre_prayer_notify() {
    get_next_prayer
    local p="$PRAYER_NAME"; local t="$PRAYER_TIME"
    notify-send "GT-salat-dikr" "تبقى 10 دقائق على صلاة $p ($t)"
}

# ---------------- next prayer ----------------
get_next_prayer() {
    read_timetable || return 1
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        h=${time%%:*}; m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then PRAYER_NAME="${arnames[$i]}"; PRAYER_TIME="$time"; PRAYER_LEFT=$diff; return 0; fi
    done
    # بعد انتهاء اليوم: نُعيد الفجر القادم غدًا
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)" +%s) - now_secs ))
    return 0
}

# ---------------- notify loop (مُحسّن) ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT

    local notify_flag_file="$SCRIPT_DIR/.last-prayer-notified"
    local pre_notify_flag_file="$SCRIPT_DIR/.last-preprayer-notified"

    while true; do
        show_zekr_notify

        if ! get_next_prayer; then
            sleep 30
            continue
        fi

        # إشعار قبل الصلاة بـ10 دقائق: نفعلها مرة واحدة لكل صلاة
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ]; then
            if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_pre_prayer_notify
                echo "$PRAYER_NAME" > "$pre_notify_flag_file"
            fi
        fi

        # إشعار دخول وقت الصلاة: نعتبر الوقت قد وصل عندما PRAYER_LEFT <= 0
        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_prayer_notify
                echo "$PRAYER_NAME" > "$notify_flag_file"
                rm -f "$pre_notify_flag_file" 2>/dev/null
            fi
        fi

        # Sleep ذكي: نم حتى أقرب فترة (بحد أدنى 1s)
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
            sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        fi
        sleep "$sleep_for"
    done
}

# ---------------- start/stop notify ----------------
start_notify() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        else rm -f "$PID_FILE"; fi
    fi

    echo "بدء إشعارات GT-salat-dikr..."
    nohup bash -c '
        # إعادة تحميل السكربت في بيئة مستقلة
        source "$0"
        notify_loop
    ' "$SCRIPT_SOURCE_ABS" > /dev/null 2>&1 &

    local loop_pid=$!
    echo "$loop_pid" > "$PID_FILE"
    sleep 1
    if kill -0 "$loop_pid" 2>/dev/null; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $loop_pid)"
    else
        echo "❌ فشل في بدء الإشعارات"
        rm -f "$PID_FILE" 2>/dev/null
        return 1
    fi
}

stop_notify() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            pkill -P "$pid" 2>/dev/null || true
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "✅ تم إيقاف إشعارات GT-salat-dikr (PID: $pid)"
        else
            echo "⚠️ لم تكن هناك إشعارات قيد التشغيل (PID: $pid غير نشط)"
            rm -f "$PID_FILE" 2>/dev/null
        fi
    else
        echo "ℹ️ لا يوجد إشعارات قيد التشغيل"
        # محاولة تنظيف أية عمليات متبقية
        pkill -f "gt-salat-dikr" 2>/dev/null || true
    fi
    rm -f "$SCRIPT_DIR/.last-prayer-notified" "$SCRIPT_DIR/.last-preprayer-notified" 2>/dev/null || true
}

# ---------------- self-update ----------------
check_script_update() {
    if ! command -v sha1sum >/dev/null 2>&1; then return 1; fi
    local local_hash remote_hash tmpf
    if [ -f "$SCRIPT_SOURCE_ABS" ]; then
        local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}')
    else
        local_hash=""
    fi
    remote_hash=$(curl -fsSL "$REPO_SCRIPT_URL" | sha1sum | awk '{print $1}') || return 1
    if [ "$local_hash" != "" ] && [ "$local_hash" != "$remote_hash" ]; then
        echo "يوجد تحديث جديد للسكريبت في المستودع."
        read -p "هل ترغب بتحديث السكربت تلقائياً الآن؟ [Y/n]: " ans; ans=${ans:-Y}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            tmpf=$(mktemp) || return 1
            curl -fsSL "$REPO_SCRIPT_URL" -o "$tmpf" || { echo "فشل تحميل النسخة الجديدة."; rm -f "$tmpf"; return 1; }
            chmod +x "$tmpf"
            mv "$tmpf" "$SCRIPT_SOURCE_ABS" && echo "تم تحديث السكربت. أعد تشغيله لاستخدام النسخة الجديدة."
            return 0
        else
            echo "تم تأجيل تحديث السكربت."
        fi
    fi
    return 0
}

# ---------------- bootup tasks ----------------
# جلب الملفات إذا افتقدت
fetch_if_missing "$SCRIPT_SOURCE_ABS" "$REPO_SCRIPT_URL" >/dev/null 2>&1 || true
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true
check_azkar_update >/dev/null 2>&1 || true

# تحميل الإعدادات
if [ ! -f "$CONFIG_FILE" ]; then setup_wizard; fi
load_config || true

# إذا فُعّل التحديث التلقائي، جرّب التحديث عند بداية التشغيل (غير إجباري)
if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update || true
fi

# ---------------- CLI ----------------
case "${1:-}" in
    --show-timetable|t) show_timetable ;;
    --settings) change_settings() { setup_wizard; }; change_settings ;;
    --notify-start) start_notify ;;
    --notify-stop) stop_notify ;;
    --update-azkar) echo "جلب أحدث نسخة من الأذكار..."; curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE" && echo "✅ تم تحديث الأذكار بنجاح" || echo "فشل التحديث" ;;
    --self-update) check_script_update ;;
    --help|-h) echo "Usage: $0 [--notify-start|--notify-stop|--settings|--update-azkar|--self-update|--show-timetable]"; exit 0 ;;
    *) # الوضع الافتراضي: عند فتح الطرفية
        show_zekr_terminal || true
        get_next_prayer || true
        leftmin=$((PRAYER_LEFT/60))
        lefth=$((leftmin/60))
        leftm=$((leftmin%60))
        printf "\e[1;34mالصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "${PRAYER_NAME:-?}" "${PRAYER_TIME:-??:??}" "$lefth" "$leftm"
    ;;
esac

exit 0


# ==== إضافات جديدة: إدارة الإشعارات بالاختصارات ====
INSTALL_DIR="$HOME/.GT-salat-dikr"
PID_FILE="$INSTALL_DIR/notify.pid"

start_notify() {
    echo "بدء إشعارات GT-salat-dikr..."
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⚠️ الإشعارات تعمل مسبقًا."
        exit 0
    fi

    nohup "$INSTALL_DIR/notify-service.sh" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo "✅ تم تشغيل الإشعارات."
}

stop_notify() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
        echo "🛑 تم إيقاف الإشعارات."
    else
        echo "⚠️ الإشعارات غير مفعّلة."
    fi
}

# دعم الاختصارات nsr / nsp
case "${1:-}" in
    nsr) start_notify ;;
    nsp) stop_notify ;;
esac
