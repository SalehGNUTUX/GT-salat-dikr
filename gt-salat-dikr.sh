#!/bin/bash
#
# GT-salat-dikr - Script كامل وجاهز للتنفيذ
# Author: gnutux (مرتكز على الكود المرسل من المستخدم)
#
# الطريقة: ضع هذا الملف في ~/.GT-salat-dikr/gt-salat-dikr.sh ثم شغّل:
#   chmod +x ~/.GT-salat-dikr/gt-salat-dikr.sh
#   ~/.GT-salat-dikr/gt-salat-dikr.sh --install   # لتثبيت (اختياري)
# أو ضع رابط/اختصار: ln -s ~/.GT-salat-dikr/gt-salat-dikr.sh ~/.local/bin/gtsalat
#
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="$(basename "${0}")"
# إذا نُسخَ أو رُبط، نحسب موقع السكربت الحقيقي:
if [ -n "${BASH_SOURCE:-}" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
else
    SCRIPT_SOURCE="$0"
fi
# حل الروابط
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

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

# ---------------- أدوات مساعدة ----------------
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"; echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG"; }
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

# ---------------- فحص أدوات النظام ----------------
check_tools() {
    # jq مطلوب لمعالجة JSON
    if ! command -v jq >/dev/null 2>&1; then
        log "تحذير: jq غير مثبت. بعض الميزات (جلب المواعيد) قد تفشل."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        log "تحذير: notify-send غير موجود. الإشعارات لن تعمل بدون libnotify."
    fi
}

# ------------- ضبط DBUS لتمكين notify-send -------------
ensure_dbus() {
    # إذا لم تكن متغيرات جلسة DBUS موجودة، حاول تعيينها إلى المسار المتوقع
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        local bus="/run/user/$(id -u)/bus"
        if [ -S "$bus" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
            log "تم تعيين DBUS_SESSION_BUS_ADDRESS إلى unix:path=$bus"
        else
            log "لم أجد DBUS bus في $bus — قد تفشل الإشعارات."
        fi
    fi
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
        # shellcheck disable=SC1090
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
    if [ ! -f "$TIMETABLE_FILE" ]; then fetch_timetable || return 1; fi
    local tdate
    tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    if [ "$tdate" != "$(date +%d-%m-%Y)" ]; then
        fetch_timetable || return 1
    fi
    return 0
}

show_timetable() {
    read_timetable || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    for i in "${!names[@]}"; do
        time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        printf "%10s: %s\n" "${arnames[$i]}" "$time"
    done
}

# ---------------- zikr ----------------
show_random_zekr() {
    if [ ! -f "$AZKAR_FILE" ]; then echo ""; return 1; fi
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_terminal() {
    local zekr; zekr=$(show_random_zekr) || { echo "لا يوجد أذكار."; return 1; }
    echo "$zekr"
}

show_zekr_notify() {
    local zekr; zekr=$(show_random_zekr)
    if [ -z "$zekr" ]; then
        notify-send "GT-salat-dikr" "لم يتم العثور على ذكر!"
    else
        notify-send "GT-salat-dikr" "$zekr"
    fi
}

# ---------------- adhan play ----------------
play_adhan() {
    [ -z "${ADHAN_FILE:-}" ] && return 1
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
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    # إذا انتهى اليوم، اعتبر الفجر غدًا
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)" +%s) - now_secs ))
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
    play_adhan || true
}

# ---------------- notify loop ----------------
notify_loop() {
    # احرص على تنظيف PID عند الخروج
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT

    local notify_flag_file="$SCRIPT_DIR/.last-prayer-notified"
    local pre_notify_flag_file="$SCRIPT_DIR/.last-preprayer-notified"

    while true; do
        # إرسال ذكر عشوائي كإشعار دوري
        show_zekr_notify || true

        if ! get_next_prayer; then
            sleep 30
            continue
        fi

        # تنبيه قبل الصلاة
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ]; then
            if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_pre_prayer_notify
                echo "$PRAYER_NAME" > "$pre_notify_flag_file"
            fi
        fi

        # تنبيه عند وقت الصلاة
        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file")" != "$PRAYER_NAME" ]; then
                show_prayer_notify
                echo "$PRAYER_NAME" > "$notify_flag_file"
                rm -f "$pre_notify_flag_file" 2>/dev/null || true
            fi
        fi

        # تحديد مدة النوم الذكية
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
            sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        fi
        sleep "$sleep_for"
    done
}

# ---------------- start/stop notify (frontend) ----------------
start_notify_bg() {
    # إذا هناك PID نشط، لا نفعل شيئًا
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

    # شغّل نسخة الطفل (child) من السكربت في الخلفية، بدون تكرار تعريف الدوال
    # سنمرّر وسيطة خاصة --child-notify
    nohup bash -c '
        # تعيين DBUS إذا لم يكن مُعرّفًا
        if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
        fi
        # تشغيل السكربت كطفل notify loop
        exec "'"$SCRIPT_SOURCE_ABS"'" --child-notify
    ' >/dev/null 2>&1 &

    local child_pid=$!
    echo "$child_pid" > "$PID_FILE"
    sleep 1
    if kill -0 "$child_pid" 2>/dev/null; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $child_pid)"
        log "started notify loop (PID: $child_pid)"
    else
        echo "❌ فشل في بدء الإشعارات"
        rm -f "$PID_FILE" 2>/dev/null || true
        log "failed to start notify loop"
        return 1
    fi
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

# ---------------- install/uninstall helper ----------------
install_self() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.local/bin"

    # انسخ السكربت إلى المجلد كما هو لو لم يكن هناك
    cp -f "$SCRIPT_SOURCE_ABS" "$INSTALL_DIR/$SCRIPT_NAME"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

    # جلب الأذكار والآذان إن لم تكن موجودة
    fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true
    # أذان إن وجد في الريبو
    fetch_if_missing "$ADHAN_FILE" "$(dirname "$REPO_SCRIPT_URL")/adhan.ogg" >/dev/null 2>&1 || true || true

    # إنشاء اختصار
    ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$HOME/.local/bin/gtsalat"
    chmod +x "$HOME/.local/bin/gtsalat"

    # إنشاء ملف autostart بسيط (مسار مطلق)
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 30 && $INSTALL_DIR/$SCRIPT_NAME --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Automatic prayer times and azkar notifications
EOF

    echo "✅ تم التثبيت في $INSTALL_DIR"
    echo "يمكنك الآن تشغيل الإشعارات: gtsalat --notify-start"
}

uninstall_self() {
    stop_notify_bg || true
    rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true
    echo "✅ تم إزالة GT-salat-dikr."
}

# ---------------- child mode ----------------
# عند التشغيل بالوسيطة --child-notify، نريد فقط تنفيذ حلقة الإشعارات
if [[ "${1:-}" == "--child-notify" ]]; then
    ensure_dbus
    check_tools
    notify_loop
    exit 0
fi

# ---------------- تحميل الإعدادات وتهيئة أولية ----------------
check_tools
# جلب الملفات الناقصة بصمت
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true

if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
else
    load_config || setup_wizard
fi

# تفعيل التحديث التلقائي إن تم الاختيار
if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update || true
fi

# ---------------- CLI ----------------
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
            echo "تم إرسال إشعار تجريبي (تحقق من ظهور النافذة)."
        else
            echo "notify-send غير متوفرة."
            exit 1
        fi
        ;;
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        if curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE"; then
            echo "✅ تم تحديث الأذكار."
        else
            echo "فشل في تحديث الأذكار."
        fi
        ;;
    --self-update)
        check_script_update
        ;;
    --help|-h)
        cat <<EOF
GT-salat-dikr usage:
  --install           تثبيت السكربت (نسخ الملفات، إنشاء اختصار autostart)
  --uninstall         إزالة التثبيت
  --settings          إعداد / تعديل الإعدادات
  --show-timetable    عرض مواقيت اليوم
  --notify-start      تشغيل إشعارات الخلفية (يكتب PID)
  --notify-stop       إيقاف إشعارات الخلفية
  --test-notify       إرسال إشعار تجريبي
  --update-azkar      جلب آخر نسخة من azkar.txt
  --self-update       التحقق من تحديث السكربت وتثبيته تفاعليًا
EOF
        ;;
    '') # الوضع الافتراضي: عند فتح الطرفية
        show_zekr_terminal || true
        get_next_prayer || true
        leftmin=$((PRAYER_LEFT/60))
        lefth=$((leftmin/60))
        leftm=$((leftmin%60))
        printf "\e[1;34mالصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "${PRAYER_NAME:-?}" "${PRAYER_TIME:-??:??}" "$lefth" "$leftm"
        ;;
    *)
        echo "خيار غير معروف. استخدم --help لعرض الخيارات."
        exit 2
        ;;
esac

exit 0
