#!/usr/bin/env bash
# GT-salat-dikr - دمج النسخة القديمة (المستقرة) + إشعار الآذان الرسومي (zenity)
# موقع التثبيت المتوقع: ~/.GT-salat-dikr/gt-salat-dikr.sh
# تأكد من chmod +x بعد النسخ
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
SCRIPT_SOURCE_ABS="${INSTALL_DIR}/${SCRIPT_NAME}"
AZKAR_FILE="${INSTALL_DIR}/azkar.txt"
CONFIG_FILE="${INSTALL_DIR}/settings.conf"
TIMETABLE_FILE="${INSTALL_DIR}/timetable.json"
PID_FILE="${INSTALL_DIR}/.gt-salat-dikr-notify.pid"
NOTIFY_LOG="${INSTALL_DIR}/notify.log"
ADHAN_FILE="${INSTALL_DIR}/adhan.ogg"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

# ANSI colors (optional)
CSI=$'\e['
RESET="${CSI}0m"
BOLD="${CSI}1m"
CYAN="${CSI}36m"
YELLOW="${CSI}33m"
MAGENTA="${CSI}35m"
GREEN="${CSI}32m"

# Ensure install dir exists for logging even if not installed fully
mkdir -p "$INSTALL_DIR"

log() {
    # Append to notify.log (silently if not writable)
    echo "$(date '+%F %T') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

# ---------------- أدوات النظام ----------------
install_zenity_if_possible() {
    # Try to install zenity via common package managers. Do not fail installation on failure.
    if command -v zenity >/dev/null 2>&1; then
        return 0
    fi
    log "zenity not found — attempting install"
    echo "🔍 محاولة تثبيت zenity تلقائيًا (قد يطلب sudo)..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zenity || { log "apt-get install zenity failed"; return 1; }
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y zenity || { log "apt install zenity failed"; return 1; }
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zenity || { log "dnf install zenity failed"; return 1; }
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm zenity || { log "pacman install zenity failed"; return 1; }
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y zenity || { log "zypper install zenity failed"; return 1; }
    else
        log "No known package manager to install zenity"
        return 1
    fi

    command -v zenity >/dev/null 2>&1 && { log "zenity installed"; return 0; } || { log "zenity install not detected after attempt"; return 1; }
}

ensure_dbus() {
    # Ensure DBUS_SESSION_BUS_ADDRESS is set for notify-send / zenity to work in non-interactive contexts
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        return 0
    fi
    local bus="/run/user/$(id -u)/bus"
    if [ -S "$bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        return 0
    fi
    # best-effort; may still fail
    return 1
}

# ---------------- جمالية الطرفية ----------------
show_terminal_dhikr() {
    local text="$*"
    [ -z "$text" ] && return 1
    printf "\n${MAGENTA}╭─✦✦✦─────────✦✦✦─╮${RESET}\n"
    # wrap lines to ~70 chars
    echo "$text" | fold -s -w 70 | while IFS= read -r line; do
        printf "  ${CYAN}%s${RESET}\n" "$line"
    done
    printf "${MAGENTA}╰─✦✦✦─────────✦✦✦─╯${RESET}\n\n"
    return 0
}

show_next_prayer_terminal() {
    local name="$1"
    local left_secs="$2"
    if [ -z "$name" ]; then return 1; fi
    local hh=$((left_secs/3600))
    local mm=$(((left_secs%3600)/60))
    printf "${YELLOW}🕌 الصلاة القادمة: %s — تبقى %02d:%02d${RESET}\n" "$name" "$hh" "$mm"
}

# ---------------- إشعارات: zenity / notify-send / terminal ----------------
# show_notify "title" "message"
show_notify() {
    local title="$1"
    local message="$2"
    # prefer zenity (non-blocking)
    if command -v zenity >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        (zenity --notification --window-icon=info --text="$message" --title="$title" >/dev/null 2>&1) &
        return 0
    fi
    if command -v notify-send >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        notify-send "$title" "$message"
        return 0
    fi
    # fallback to terminal
    printf "\n${BOLD}%s${RESET}\n%s\n\n" "$title" "$message"
    return 0
}

# show_adhan_dialog_and_play "PrayerName" "Time"
show_adhan_dialog_and_play() {
    local prayer_name="$1"
    local prayer_time="$2"
    local title="آذان — $prayer_name"
    local message="حان الآن وقت صلاة $prayer_name ($prayer_time)"

    # prefer zenity dialog with stop button; if not, fallback to notify-send then play
    if command -v zenity >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        # run dialog in background so we can play audio; use --info with OK label "إيقاف"
        (
            # Use --question to show a button and allow localized label. It returns exit code 0 if OK
            zenity --question --title="$title" --text="$message" --ok-label="إيقاف الآذان" --no-wrap >/dev/null 2>&1
        ) &
        # play adhan sound
        play_adhan || true
        return 0
    fi

    if command -v notify-send >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        notify-send "$title" "$message"
        play_adhan || true
        return 0
    fi

    # terminal fallback
    printf "\n${BOLD}%s${RESET}\n%s\n\n" "$title" "$message"
    play_adhan || true
    return 0
}

# ---------------- تشغيل الآذان الصوتي ----------------
play_adhan() {
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

# ---------------- مواقيت الصلاة ----------------
fetch_timetable() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "fetch_timetable: curl or jq missing"
        return 1
    fi
    local today url resp
    today=$(date +%Y-%m-%d)
    url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}&date=${today}"
    if resp=$(curl -fsSL "$url"); then
        echo "$resp" > "$TIMETABLE_FILE"
        return 0
    fi
    return 1
}

read_timetable() {
    if [ ! -f "$TIMETABLE_FILE" ]; then
        fetch_timetable || return 1
    fi
    local tdate
    tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    if [ "$tdate" != "$(date +%d-%m-%Y)" ]; then
        fetch_timetable || return 1
    fi
    return 0
}

get_next_prayer() {
    read_timetable || return 1
    local names=( "Fajr" "Dhuhr" "Asr" "Maghrib" "Isha" )
    local arnames=( "الفجر" "الظهر" "العصر" "المغرب" "العشاء" )
    local now_secs; now_secs=$(date +%s)
    for i in "${!names[@]}"; do
        local time; time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        local h=${time%%:*}; local m=${time#*:}
        local prayer_secs; prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        local diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    # next day Fajr
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $PRAYER_TIME" +%s) - $(date +%s) ))
    return 0
}

# ---------------- الأذكار ----------------
show_random_zekr() {
    if [ ! -f "$AZKAR_FILE" ]; then
        return 1
    fi
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

# ---------------- حلقة الإشعارات (child) ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT
    log "notify_loop started"
    local notify_flag="$INSTALL_DIR/.last-prayer-notified"
    local pre_flag="$INSTALL_DIR/.last-preprayer-notified"

    while true; do
        # print dhikr to terminal (keep UX of old stable version)
        local zekr
        zekr=$(show_random_zekr 2>/dev/null || true)
        if [ -n "$zekr" ]; then
            show_terminal_dhikr "$zekr"
        fi

        if ! get_next_prayer; then
            sleep 30
            continue
        fi

        # show next prayer countdown in terminal
        show_next_prayer_terminal "$PRAYER_NAME" "$PRAYER_LEFT"

        # pre-notify (10 minutes)
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ]; then
            if [ ! -f "$pre_flag" ] || [ "$(cat "$pre_flag")" != "$PRAYER_NAME" ]; then
                show_notify "تذكير قبل الصلاة" "تبقى 10 دقائق على صلاة $PRAYER_NAME ($PRAYER_TIME)"
                echo "$PRAYER_NAME" > "$pre_flag"
            fi
        fi

        # notify at prayer time
        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag" ] || [ "$(cat "$notify_flag")" != "$PRAYER_NAME" ]; then
                # show adhan dialog (zenity) or notify-send fallback, and play adhan
                show_adhan_dialog_and_play "$PRAYER_NAME" "$PRAYER_TIME"
                echo "$PRAYER_NAME" > "$notify_flag"
                rm -f "$pre_flag" 2>/dev/null || true
            fi
        fi

        # smart sleep: default zikr interval
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
            sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        fi
        sleep "$sleep_for"
    done
}

# ---------------- start/stop wrapper ----------------
start_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "ℹ️ الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    ensure_dbus >/dev/null 2>&1 || true

    # Launch the script from its install location in child mode
    nohup bash -c "exec '$SCRIPT_SOURCE_ABS' --child-notify" >/dev/null 2>&1 &

    local child_pid=$!
    echo "$child_pid" > "$PID_FILE"
    sleep 1
    if kill -0 "$child_pid" 2>/dev/null; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $child_pid)"
        log "started notify loop (PID: $child_pid)"
        return 0
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
            echo "✅ تم إيقاف إشعارات GT-salat-dikr (PID: $pid)"
            log "stopped notify loop (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE" 2>/dev/null || true
            echo "⚠️ لم تكن هناك إشعارات قيد التشغيل."
            return 1
        fi
    else
        echo "ℹ️ لا توجد إشعارات قيد التشغيل."
        return 1
    fi
}

# ---------------- إعداد وحفظ الإعدادات مرة واحدة ----------------
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
SETUP_DONE=true
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
    echo "✅ تم حفظ الإعدادات في $CONFIG_FILE"
    log "config saved"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# auto-detect location using ip-api.com if possible
auto_detect_location() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local info
    info=$(curl -fsSL "http://ip-api.com/json/") || return 1
    LAT=$(echo "$info" | jq -r '.lat // empty')
    LON=$(echo "$info" | jq -r '.lon // empty')
    CITY=$(echo "$info" | jq -r '.city // empty')
    COUNTRY=$(echo "$info" | jq -r '.country // empty')
    if [[ -z "$LAT" || -z "$LON" ]]; then return 1; fi
    return 0
}

choose_method_interactive() {
    METHODS=( "Muslim World League" "Islamic Society of North America" "Egyptian General Authority of Survey" \
    "Umm Al-Qura University, Makkah" "University of Islamic Sciences, Karachi" "Institute of Geophysics, University of Tehran" \
    "Shia Ithna-Ashari, Leva Institute, Qum" "Gulf Region" "Kuwait" "Qatar" "Majlis Ugama Islam Singapura, Singapore" \
    "Union Organization islamic de France" "Diyanet İşleri Başkanlığı, Turkey" "Spiritual Administration of Muslims of Russia" \
    "Moonsighting Committee" "Dubai, UAE" "Jabatan Kemajuan Islam Malaysia (JAKIM)" "Tunisia" "Algeria" \
    "Kementerian Agama Republik Indonesia" "Morocco" "Comunidate Islamica de Lisboa (Portugal)" )
    METHOD_IDS=(3 2 5 4 1 7 8 9 10 11 12 13 14 15 16 18 24 19 20 21 22 23)

    echo "يرجى اختيار طريقة حساب مواقيت الصلاة:"
    for i in "${!METHODS[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${METHODS[$i]}"
    done
    while true; do
        read -p "اختر الرقم المناسب [1]: " idx
        idx=${idx:-1}
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#METHODS[@]} ]; then
            METHOD_IDX=$((idx-1))
            METHOD_NAME="${METHODS[$METHOD_IDX]}"
            METHOD_ID="${METHOD_IDS[$METHOD_IDX]}"
            break
        fi
        echo "اختيار غير صحيح! حاول مجدداً."
    done
}

setup_wizard() {
    echo "---- إعداد GT-salat-dikr (مرة واحدة فقط) ----"
    if auto_detect_location; then
        echo "تم تحديد موقعك تلقائيًا: $CITY, $COUNTRY (LAT=$LAT LON=$LON)"
        read -p "هل ترغب باعتماد هذا الموقع؟ [Y/n]: " ans
        ans=${ans:-Y}
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            read -p "أدخل خط العرض: " LAT
            read -p "أدخل خط الطول: " LON
            read -p "أدخل المدينة: " CITY
            read -p "أدخل الدولة: " COUNTRY
        fi
    else
        echo "تعذر تحديد الموقع تلقائيًا، أدخل البيانات يدويًا."
        read -p "أدخل خط العرض: " LAT
        read -p "أدخل خط الطول: " LON
        read -p "أدخل المدينة: " CITY
        read -p "أدخل الدولة: " COUNTRY
    fi

    choose_method_interactive
    read -p "تفعيل التنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; p=${p:-Y}; PRE_PRAYER_NOTIFY=$([ "$p" =~ ^[Yy]$ ] && echo 1 || echo 0)
    read -p "الفاصل الزمني لإشعارات الأذكار بالثواني (افتراضي $DEFAULT_ZIKR_INTERVAL): " z; ZIKR_NOTIFY_INTERVAL=${z:-$DEFAULT_ZIKR_INTERVAL}
    read -p "تفعيل التحديث الذاتي للسكريبت عند توفر تحديث؟ [y/N]: " up; up=${up:-N}; AUTO_SELF_UPDATE=$([ "$up" =~ ^[Yy]$ ] && echo 1 || echo 0)

    save_config
}

# ---------------- تثبيت ذاتي من السكربت ----------------
install_self() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.local/bin"

    # if script run from other path, copy it to install dir
    if [ "$(readlink -f "$0")" != "$SCRIPT_SOURCE_ABS" ]; then
        cp -f "$(readlink -f "$0")" "$SCRIPT_SOURCE_ABS"
        chmod +x "$SCRIPT_SOURCE_ABS"
    fi

    # fetch azkar and adhan if missing
    if [ ! -f "$AZKAR_FILE" ]; then
        if curl -fsSL "$REPO_RAW_URL/azkar.txt" -o "$AZKAR_FILE"; then
            echo "✅ تم جلب azkar.txt"
        else
            echo "⚠️ فشل جلب azkar.txt — تأكد من وجود الملف محليًا إذا رغبت."
        fi
    fi
    # adhan optional
    if [ ! -f "$ADHAN_FILE" ]; then
        curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$ADHAN_FILE" >/dev/null 2>&1 || true
    fi

    # symlink
    ln -sf "$SCRIPT_SOURCE_ABS" "$HOME/.local/bin/gtsalat"
    chmod +x "$HOME/.local/bin/gtsalat"

    # attempt to install zenity quietly
    install_zenity_if_possible >/dev/null 2>&1 || true

    # create autostart .desktop (absolute path) with delay to allow session bus
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 25 && '$SCRIPT_SOURCE_ABS' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Automatic prayer times and azkar notifications
EOF

    echo "✅ تم التثبيت في $INSTALL_DIR"
    # If settings absent, run setup once (this prevents double prompt if installer later triggers --notify-start)
    if ! load_config || [ "${SETUP_DONE:-}" != "true" ]; then
        "$SCRIPT_SOURCE_ABS" --settings
    fi

    # start notifications in background (installer convenience)
    "$SCRIPT_SOURCE_ABS" --notify-start || true
}

# ---------------- إلغاء التثبيت (موجه) ----------------
uninstall_self() {
    echo "🗑️ جاري إزالة GT-salat-dikr..."
    # stop notifications
    stop_notify_bg >/dev/null 2>&1 || true
    # remove symlink
    rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    # remove install dir (ask)
    if [ -d "$INSTALL_DIR" ]; then
        read -p "هل تريد حذف مجلد التثبيت $INSTALL_DIR نهائياً؟ [y/N]: " ans
        ans=${ans:-N}
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            echo "✅ تمت إزالة $INSTALL_DIR"
        else
            echo "ℹ️ أبقيت مجلد التثبيت."
        fi
    fi
    # remove autostart
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true
    echo "✅ تم إلغاء التثبيت (أُنجزت الخطوات الأساسية)."
}

# ---------------- self-update (simple) ----------------
self_update() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v sha1sum >/dev/null 2>&1; then
        echo "🔄 لا يمكن التحقق عن التحديث (curl أو sha1sum مفقود)."
        return 1
    fi
    remote_hash=$(curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" | sha1sum | awk '{print $1}') || return 1
    local_hash=""
    if [ -f "$SCRIPT_SOURCE_ABS" ]; then local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}'); fi
    if [ -n "$remote_hash" ] && [ "$remote_hash" != "$local_hash" ]; then
        echo "يوجد تحديث جديد للسكريبت."
        read -p "هل تريد التحديث الآن؟ [Y/n]: " a; a=${a:-Y}
        if [[ "$a" =~ ^[Yy]$ ]]; then
            tmpf=$(mktemp) || return 1
            curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$tmpf" && chmod +x "$tmpf" && mv "$tmpf" "$SCRIPT_SOURCE_ABS"
            echo "✅ تم تحديث السكربت."
            return 0
        fi
    else
        echo "لا يوجد تحديث."
    fi
    return 0
}

# ---------------- اختبارات مساعدة ----------------
test_notify() {
    ensure_dbus >/dev/null 2>&1 || true
    show_notify "GT-salat-dikr" "اختبار إشعار: إذا ظهر هذا الإشعار فالنظام يدعم الإشعارات."
}

test_adhan() {
    # Show GUI adhan dialog (or fallback)
    show_adhan_dialog_and_play "اختبار" "$(date '+%H:%M')"
}

# ---------------- CLI ----------------
show_help() {
cat <<'EOF'
═══════════════════════════════════════════════════════════
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن
═══════════════════════════════════════════════════════════

📦 التثبيت والإزالة:
  --install           تثبيت البرنامج مع autostart التلقائي
  --uninstall         إزالة البرنامج بالكامل

⚙️  الإعدادات:
  --settings          تعديل الموقع والإعدادات

📊 العرض:
  --show-timetable    عرض جدول مواقيت الصلاة لليوم
  --status            عرض حالة البرنامج التفصيلية

🔔 الإشعارات:
  --notify-start      بدء إشعارات الخلفية
  --notify-stop       إيقاف إشعارات الخلفية

🧪 الاختبار:
  --test-notify       اختبار الإشعارات العادية
  --test-adhan        اختبار مشغل الأذان الرسومي

🔄 التحديث:
  --update-azkar      تحديث ملف الأذكار
  --self-update       تحديث البرنامج

ℹ️  المساعدة:
  --help, -h          عرض هذه المساعدة

═══════════════════════════════════════════════════════════
💡 الاستخدام الافتراضي (بدون خيارات):
   عرض ذكر عشوائي ووقت الصلاة القادمة
═══════════════════════════════════════════════════════════
EOF
}

status() {
    echo "حالة GT-salat-dikr:"
    echo "  تثبيت في: $INSTALL_DIR"
    [ -f "$AZKAR_FILE" ] && echo "  azkar: موجود" || echo "  azkar: غير موجود"
    [ -f "$ADHAN_FILE" ] && echo "  adhan.ogg: موجود" || echo "  adhan.ogg: غير موجود"
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "  إشعارات: تعمل (PID: $pid)"
        else
            echo "  إشعارات: غير نشطة (PID file موجود لكن العملية غير نشطة)"
        fi
    else
        echo "  إشعارات: غير نشطة"
    fi
    if load_config; then
        echo "  إعدادات: موجودة (SETUP_DONE=${SETUP_DONE:-})"
        echo "  المدينة: ${CITY:-(غير محددة)}"
    else
        echo "  إعدادات: غير موجودة"
    fi
}

# ---------------- CLI dispatch ----------------
case "${1:-}" in
    --install)
        install_self
        exit 0
        ;;
    --uninstall)
        uninstall_self
        exit 0
        ;;
    --settings)
        setup_wizard
        exit 0
        ;;
    --show-timetable|-t)
        load_config || { echo "الإعدادات غير موجودة. شغّل: gtsalat --settings"; exit 1; }
        if fetch_timetable; then
            # Nicely print timetable (simple)
            echo "مواقيت الصلاة اليوم ($CITY):"
            jq -r '.data.timings | to_entries[] | "\(.key): \(.value)"' "$TIMETABLE_FILE" 2>/dev/null | sed -E 's/(Fajr|Dhuhr|Asr|Maghrib|Isha|Sunrise)/\1/;'
        else
            echo "تعذر جلب الجدول. تأكد من اتصال الإنترنت ووجود curl/jq."
        fi
        exit 0
        ;;
    --status)
        status
        exit 0
        ;;
    --notify-start)
        # Ensure setup done, otherwise ask once
        if ! load_config || [ "${SETUP_DONE:-}" != "true" ]; then
            echo "مطلوب إجراء الإعداد قبل تشغيل الإشعارات."
            setup_wizard
        fi
        start_notify_bg
        exit $?
        ;;
    --notify-stop)
        stop_notify_bg
        exit $?
        ;;
    --test-notify)
        test_notify
        exit 0
        ;;
    --test-adhan)
        test_adhan
        exit 0
        ;;
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        if curl -fsSL "$REPO_RAW_URL/azkar.txt" -o "$AZKAR_FILE"; then
            echo "✅ تم تحديث الأذكار."
        else
            echo "❌ فشل في تحديث الأذكار."
        fi
        exit 0
        ;;
    --self-update)
        self_update
        exit $?
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    --child-notify)
        # child mode: run notify loop (used by start_notify_bg)
        # ensure we're running from install location
        notify_loop
        exit 0
        ;;
    "" )
        # default behavior: print random dhikr and next prayer countdown
        load_config || true
        zekr=$(show_random_zekr 2>/dev/null || echo "")
        if [ -n "$zekr" ]; then
            show_terminal_dhikr "$zekr"
        fi
        if load_config; then
            if get_next_prayer; then
                show_next_prayer_terminal "$PRAYER_NAME" "$PRAYER_LEFT"
            else
                echo "ℹ️ تعذر جلب مواقيت الصلاة. تأكد من اتصالك بالإنترنت ووجود curl/jq."
            fi
        else
            echo "ℹ️ إعدادات غير مفعّلة. شغّل: gtsalat --settings"
        fi
        exit 0
        ;;
    *)
        echo "خيار غير معروف. استخدم --help لعرض الخيارات."
        exit 2
        ;;
esac
