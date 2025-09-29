#!/bin/bash
# GT-salat-dikr - نسخة كاملة للإشعارات + الآذان + تحديث ذاتي
# موقع التثبيت: ~/.GT-salat-dikr

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="$INSTALL_DIR/azkar.txt"
CONFIG_FILE="$INSTALL_DIR/settings.conf"
TIMETABLE_FILE="$INSTALL_DIR/timetable.json"
PID_FILE="$INSTALL_DIR/.gt-salat-dikr-notify.pid"
ADHAN_FILE="$INSTALL_DIR/adhan.ogg"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

METHODS=( "Muslim World League" "Islamic Society of North America" "Egyptian General Authority of Survey" \
"Umm Al-Qura University, Makkah" "University of Islamic Sciences, Karachi" "Institute of Geophysics, University of Tehran" \
"Shia Ithna-Ashari, Leva Institute, Qum" "Gulf Region" "Kuwait" "Qatar" "Majlis Ugama Islam Singapura, Singapore" \
"Union Organization islamic de France" "Diyanet İşleri Başkanlığı, Turkey" "Spiritual Administration of Muslims of Russia" \
"Moonsighting Committee" "Dubai, UAE" "Jabatan Kemajuan Islam Malaysia (JAKIM)" "Tunisia" "Algeria" \
"Kementerian Agama Republik Indonesia" "Morocco" "Comunidate Islamica de Lisboa (Portugal)" )

METHOD_IDS=(3 2 5 4 1 7 8 9 10 11 12 13 14 15 16 18 24 19 20 21 22 23)

# ---------------- utilities ----------------
fetch_if_missing() {
    local file="$1"; local url="$2"
    if [ ! -f "$file" ]; then
        curl -fsSL "$url" -o "$file" || { echo "❌ فشل تحميل $file"; return 1; }
    fi
}

check_azkar_update() {
    if [ ! -f "$AZKAR_FILE" ]; then return 0; fi
    local local_hash remote_hash
    local_hash=$(sha1sum "$AZKAR_FILE" | awk '{print $1}')
    remote_hash=$(curl -fsSL "$REPO_RAW_URL/azkar.txt" | sha1sum | awk '{print $1}') || return 0
    if [ "$local_hash" != "$remote_hash" ]; then
        echo "يوجد تحديث جديد للأذكار."
        read -p "هل ترغب بتحديثه؟ [Y/n]: " ans; ans=${ans:-Y}
        [[ "$ans" =~ ^[Yy]$ ]] && curl -fsSL "$REPO_RAW_URL/azkar.txt" -o "$AZKAR_FILE"
    fi
}

# ---------------- config ----------------
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
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

auto_detect_location() {
    local info
    info=$(curl -fsSL "http://ip-api.com/json/") || return 1
    LAT=$(echo "$info" | jq '.lat')
    LON=$(echo "$info" | jq '.lon')
    CITY=$(echo "$info" | jq -r '.city')
    COUNTRY=$(echo "$info" | jq -r '.country')
    [[ -z "$LAT" || -z "$LON" ]] && return 1
}

manual_location() {
    read -p "أدخل خط العرض: " LAT
    read -p "أدخل خط الطول: " LON
    read -p "أدخل المدينة: " CITY
    read -p "أدخل الدولة: " COUNTRY
}

choose_method() {
    echo "اختر طريقة الحساب:"
    for i in "${!METHODS[@]}"; do printf "%2d) %s\n" "$((i+1))" "${METHODS[$i]}"; done
    while true; do
        read -p "رقم الطريقة [1]: " idx; idx=${idx:-1}
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#METHODS[@]} ]; then
            METHOD_IDX=$((idx-1))
            METHOD_NAME="${METHODS[$METHOD_IDX]}"
            METHOD_ID="${METHOD_IDS[$METHOD_IDX]}"
            break
        fi
    done
}

setup_wizard() {
    echo "---- إعداد الموقع ----"
    if auto_detect_location; then
        echo "تم اكتشاف موقعك: $CITY, $COUNTRY"
        read -p "اعتماد الموقع؟ [Y/n]: " ans; ans=${ans:-Y}
        [[ ! "$ans" =~ ^[Yy]$ ]] && manual_location
    else
        echo "تعذر الاكتشاف التلقائي، أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    read -p "تفعيل إشعار قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; PRE_PRAYER_NOTIFY=$([ "${p:-Y}" =~ ^[Yy]$ ] && echo 1 || echo 0)
    read -p "الفاصل الزمني للأذكار بالثواني [300]: " z; ZIKR_NOTIFY_INTERVAL=${z:-300}
    read -p "تفعيل التحديث التلقائي؟ [y/N]: " up; AUTO_SELF_UPDATE=$([ "${up:-N}" =~ ^[Yy]$ ] && echo 1 || echo 0)
    save_config
}

# ---------------- timetable ----------------
fetch_timetable() {
    local today url resp
    today=$(date +%Y-%m-%d)
    url="$ALADHAN_API_URL?latitude=$LAT&longitude=$LON&method=$METHOD_ID&date=$today"
    resp=$(curl -fsSL "$url") || { echo "فشل جلب المواقيت."; return 1; }
    echo "$resp" > "$TIMETABLE_FILE"
}

read_timetable() {
    [ ! -f "$TIMETABLE_FILE" ] && fetch_timetable || true
    local tdate
    tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE")
    [[ "$tdate" != "$(date +%d-%m-%Y)" ]] && fetch_timetable
}

show_timetable() {
    read_timetable || { echo "تعذر قراءة الجدول"; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    local now=$(date +%s) next_idx=-1 min_diff=99999
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        h=${time%%:*}; m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now))
        [ $diff -ge 0 ] && [ $diff -lt $min_diff ] && min_diff=$diff && next_idx=$i
        printf "%10s: %s" "${arnames[$i]}" "$time"
        [ $diff -ge 0 ] && printf " (باقي %02d:%02d)" $((diff/3600)) $(((diff%3600)/60))
        [ $i -eq $next_idx ] && printf "  ← القادمة"
        echo
    done
}

# ---------------- zikr ----------------
show_random_zekr() {
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_terminal() { show_random_zekr; }
show_zekr_notify() {
    local z; z=$(show_random_zekr)
    [ -z "$z" ] && notify-send "GT-salat-dikr" "لم يتم العثور على ذكر!" || notify-send "GT-salat-dikr" "$z"
}

# ---------------- adhan ----------------
play_adhan() {
    [ ! -f "$ADHAN_FILE" ] && return 1
    if command -v mpv >/dev/null 2>&1; then mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v ffplay >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v ogg123 >/dev/null 2>&1; then ogg123 -q "$ADHAN_FILE" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then paplay "$ADHAN_FILE" >/dev/null 2>&1 &
    else (sleep 0.1; printf '\a') & fi
}

# ---------------- prayer notify ----------------
get_next_prayer() {
    read_timetable || return 1
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now=$(date +%s)
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        h=${time%%:*}; m=${time#*:}
        prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        diff=$((prayer_secs - now))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    # إذا انتهى اليوم
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $PRAYER_TIME" +%s) - now ))
}

show_pre_prayer_notify() {
    get_next_prayer
    notify-send "GT-salat-dikr" "تبقى 10 دقائق على صلاة $PRAYER_NAME ($PRAYER_TIME)"
}

show_prayer_notify() {
    get_next_prayer
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة $PRAYER_NAME ($PRAYER_TIME)"
    play_adhan
}

# ---------------- notify loop ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT
    local notify_flag="$INSTALL_DIR/.last-prayer-notified"
    local pre_flag="$INSTALL_DIR/.last-preprayer-notified"
    while true; do
        show_zekr_notify
        ! get_next_prayer && sleep 30 && continue

        # إشعار قبل الصلاة
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ]; then
            [ ! -f "$pre_flag" ] || [ "$(cat "$pre_flag")" != "$PRAYER_NAME" ] && { show_pre_prayer_notify; echo "$PRAYER_NAME" > "$pre_flag"; }
        fi
        # إشعار وقت الصلاة
        if [ "$PRAYER_LEFT" -le 0 ]; then
            [ ! -f "$notify_flag" ] || [ "$(cat "$notify_flag")" != "$PRAYER_NAME" ] && { show_prayer_notify; echo "$PRAYER_NAME" > "$notify_flag"; rm -f "$pre_flag"; }
        fi

        # Sleep ذكي
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ] && sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        sleep "$sleep_for"
    done
}

# ---------------- start/stop ----------------
start_notify() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        kill -0 "$pid" 2>/dev/null && { echo "الإشعارات تعمل بالفعل (PID: $pid)"; return 0; }
        rm -f "$PID_FILE"
    fi
    nohup bash -c "source '$SCRIPT_NAME'; notify_loop" > /dev/null 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1
    kill -0 $(cat "$PID_FILE") 2>/dev/null && echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $(cat "$PID_FILE"))" || echo "❌ فشل بدء الإشعارات"
}

stop_notify() {
    [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null && rm -f "$PID_FILE"
    rm -f "$INSTALL_DIR/.last-prayer-notified" "$INSTALL_DIR/.last-preprayer-notified"
    echo "✅ تم إيقاف الإشعارات"
}

# ---------------- self-update ----------------
check_script_update() {
    [ ! -f "$SCRIPT_SOURCE_ABS" ] && return 1
    [ ! command -v sha1sum >/dev/null 2>&1 ] && return 1
    local local_hash remote_hash tmpf
    local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}')
    remote_hash=$(curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" | sha1sum | awk '{print $1}') || return 1
    if [ "$local_hash" != "$remote_hash" ]; then
        echo "يوجد تحديث جديد للسكريبت."
        read -p "هل تريد التحديث الآن؟ [Y/n]: " ans; ans=${ans:-Y}
        [[ "$ans" =~ ^[Yy]$ ]] && curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$SCRIPT_SOURCE_ABS" && chmod +x "$SCRIPT_SOURCE_ABS" && echo "✅ تم تحديث السكربت."
    fi
}

# ---------------- main ----------------
SCRIPT_SOURCE_ABS="$(readlink -f "$0")"
load_config

case "${1:-}" in
    --notify-start) start_notify ;;
    --notify-stop) stop_notify ;;
    --show-timetable) show_timetable ;;
    --settings) setup_wizard ;;
    --check-update) check_script_update ;;
    *) echo "GT-salat-dikr"
       echo "استخدام: $0 [--notify-start|--notify-stop|--show-timetable|--settings|--check-update]"
       exit 0 ;;
esac
