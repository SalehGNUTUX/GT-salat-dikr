#!/usr/bin/env bash
# GT-salat-dikr - مُنسخة مُحسّنة: إشعارات رسومية (zenity) + إشعارات النظام + طرفية جميلة
# وضع التثبيت يجب أن يستخدم --install من المثبّت لتجنب تكرار الsetup.
# Author: gnutux (modified)

set -euo pipefail

# ---- متغيرات عامة ----
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

# ---------------- utilities ----------------
log() {
    local msg="$*"
    echo "$(date '+%F %T') - $msg" >> "$NOTIFY_LOG" 2>/dev/null || true
}

# ensure install dir exists (useful when script run directly)
mkdir -p "$INSTALL_DIR"

# ---- detect package manager and try install zenity if requested ----
install_zenity() {
    if command -v zenity >/dev/null 2>&1; then
        return 0
    fi

    echo "🔍 لم أجد zenity. سأحاول تثبيته إن أمكن (قد يطلب sudo)..."
    log "attempting to install zenity"

    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zenity || return 1
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y zenity || return 1
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zenity || return 1
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm zenity || return 1
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y zenity || return 1
    else
        echo "⚠️ لم أتعرف على مدير الحزم تلقائيًا. الرجاء تثبيت zenity يدويًا (مثلاً: sudo apt install zenity)."
        return 1
    fi

    command -v zenity >/dev/null 2>&1 && { echo "✅ تم تثبيت zenity"; return 0; } || { echo "❌ فشل تثبيت zenity"; return 1; }
}

# ---- DBUS session check for notify-send/zenity ----
ensure_dbus() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        return 0
    fi
    local bus="/run/user/$(id -u)/bus"
    if [ -S "$bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        return 0
    fi
    # Try to discover DBUS via loginctl (systemd user)
    if command -v loginctl >/dev/null 2>&1; then
        local user_bus
        user_bus=$(loginctl show-user "$(id -u)" --property=Display --value 2>/dev/null || true)
    fi
    # If still none, we continue — graphical notifications may fail
    return 1
}

# ---- جمالية الطرفية للأذكار والوقت ----
# ألوان ANSI (إن كانت الطرفية تدعم)
CSI=$'\e['
RESET="${CSI}0m"
BOLD="${CSI}1m"
GREEN="${CSI}32m"
CYAN="${CSI}36m"
YELLOW="${CSI}33m"
MAGENTA="${CSI}35m"

show_terminal_dhikr() {
    local text="$*"
    # إزالة أية تنسيقات زائدة
    text="$(echo -e "$text" | sed 's/\r//g')"
    printf "\n${MAGENTA}╭─✦✦✦─────────✦✦✦─╮${RESET}\n"
    printf "${CYAN}   %s${RESET}\n" "$(echo "$text" | fold -s -w 60 | sed 's/^/   /')"
    printf "${MAGENTA}╰─✦✦✦─────────✦✦✦─╯${RESET}\n\n"
}

show_next_prayer_terminal() {
    local name="$1"
    local left_secs="$2"
    local hh=$((left_secs/3600))
    local mm=$(((left_secs%3600)/60))
    local ss=$((left_secs%60))
    printf "${YELLOW}🕌 الصلاة القادمة: %s — تبقى %02d:%02d:%02d${RESET}\n" "$name" "$hh" "$mm" "$ss"
}

# ---- إخراج رسومي أو notify-send أو طرفي ----
# title, message
show_notify() {
    local title="$1"; local message="$2"

    # Prefer zenity dialog for adhan (modal), otherwise notify-send, otherwise terminal
    if command -v zenity >/dev/null 2>&1; then
        # Zenity may require DBUS; ensure it
        ensure_dbus >/dev/null 2>&1 || true
        # Use info dialog non-blocking
        (zenity --info --title="$title" --text="$message" --timeout=0 >/dev/null 2>&1) &
        return 0
    elif command -v notify-send >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        notify-send "$title" "$message"
        return 0
    else
        # Fallback to terminal output
        printf "\n${BOLD}%s${RESET}\n%s\n\n" "$title" "$message"
        return 0
    fi
}

# ---- تشغيل الآذان ----
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

# ---- عرض رسالة الآذان: نافذة رسومية أولاً، ثم notify-send، ثم طرفي ----
show_adhan_dialog_and_notify() {
    local prayer_name="$1"
    local prayer_time="$2"
    local title="🔔 آذان — $prayer_name"
    local message="حان الآن وقت صلاة $prayer_name ($prayer_time)"

    # If zenity exists use a dialog with stop button (non-blocking) — we'll show dialog and also play adhan
    if command -v zenity >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        # Use a dialog with a single "إيقاف" button that closes dialog; run in background
        (
            # show dialog; when user clicks "إيقاف" the dialog closes.
            zenity --question --title="$title" --text="$message" --ok-label="إيقاف الآذان" --no-wrap >/dev/null 2>&1
        ) &
        play_adhan || true
        return 0
    fi

    # Fallback to notify-send then play sound
    if command -v notify-send >/dev/null 2>&1; then
        ensure_dbus >/dev/null 2>&1 || true
        notify-send "$title" "$message"
        play_adhan || true
        return 0
    fi

    # Terminal fallback
    printf "\n${BOLD}%s${RESET}\n%s\n\n" "$title" "$message"
    play_adhan || true
    return 0
}

# ---------------- timetable / next prayer calculation ----------------
fetch_timetable() {
    # requires curl & jq
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        log "curl أو jq غير متوفّر؛ لا يمكن جلب الجدول."
        return 1
    fi
    local today
    today=$(date +%Y-%m-%d)
    local url="${ALADHAN_API_URL}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}&date=${today}"
    if resp=$(curl -fsSL "$url"); then
        echo "$resp" > "$TIMETABLE_FILE"
        return 0
    else
        log "فشل في جلب مواقيت الصلاة."
        return 1
    fi
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
    # Next day Fajr
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $PRAYER_TIME" +%s) - $(date +%s) ))
    return 0
}

# ---- random dhikr extraction ----
show_random_zekr() {
    if [ ! -f "$AZKAR_FILE" ]; then
        echo ""
        return 1
    fi
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

# ---- notify loop (child) ----
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT
    log "notify_loop started (child mode)"
    local notify_flag="$INSTALL_DIR/.last-prayer-notified"
    local pre_flag="$INSTALL_DIR/.last-preprayer-notified"

    while true; do
        # عرض ذكر في الطرفية دائمًا (جمالية)
        local zekr; zekr=$(show_random_zekr || true)
        if [ -n "$zekr" ]; then
            show_terminal_dhikr "$zekr"
        fi

        # حساب الصلاة القادمة وإعلام الطرفية بالوقت المتبقي
        if ! get_next_prayer; then
            sleep 30
            continue
        fi
        show_next_prayer_terminal "$PRAYER_NAME" "$PRAYER_LEFT"

        # pre-prayer notify (10 min)
        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ]; then
            if [ ! -f "$pre_flag" ] || [ "$(cat "$pre_flag")" != "$PRAYER_NAME" ]; then
                # إرسال إشعار قبل الصلاة (رسومي أو notify-send أو طرفي)
                show_notify "تذكير قبل الصلاة" "تبقى 10 دقائق على صلاة $PRAYER_NAME ($PRAYER_TIME)"
                echo "$PRAYER_NAME" > "$pre_flag"
            fi
        fi

        # prayer time arrived
        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag" ] || [ "$(cat "$notify_flag")" != "$PRAYER_NAME" ]; then
                # عرض نافذة الآذان + تشغيل الصوت
                show_adhan_dialog_and_notify "$PRAYER_NAME" "$PRAYER_TIME"
                echo "$PRAYER_NAME" > "$notify_flag"
                rm -f "$pre_flag" 2>/dev/null || true
            fi
        fi

        # Sleep ذكي
        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        if [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ]; then
            sleep_for=$(( PRAYER_LEFT < 2 ? 1 : PRAYER_LEFT ))
        fi
        sleep "$sleep_for"
    done
}

# ---- start/stop notify (frontend) ----
start_notify_bg() {
    # already running?
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
    # Launch child mode: use absolute path to script
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
        echo "ℹ️ لا يوجد إشعارات قيد التشغيل."
        return 1
    fi
}

# ---- setup wizard (only once) ----
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
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

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

choose_method() {
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
        echo "اختيار غير صحيح! حاول مجددًا."
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

    choose_method
    read -p "تفعيل التنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; p=${p:-Y}; PRE_PRAYER_NOTIFY=$([ "$p" =~ ^[Yy]$ ] && echo 1 || echo 0)
    read -p "الفاصل الزمني لإشعارات الأذكار بالثواني (افتراضي $DEFAULT_ZIKR_INTERVAL): " z; ZIKR_NOTIFY_INTERVAL=${z:-$DEFAULT_ZIKR_INTERVAL}
    read -p "تفعيل التحديث الذاتي للسكريبت عند توفر تحديث؟ [y/N]: " up; up=${up:-N}; AUTO_SELF_UPDATE=$([ "$up" =~ ^[Yy]$ ] && echo 1 || echo 0)

    save_config
    echo "✅ انتهت إعدادات التهيئة."
}

# ---- install helper (called by installer) ----
install_self() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$HOME/.local/bin"
    # copy if running from elsewhere
    if [ "$(readlink -f "$0")" != "$SCRIPT_SOURCE_ABS" ]; then
        cp -f "$(readlink -f "$0")" "$SCRIPT_SOURCE_ABS"
        chmod +x "$SCRIPT_SOURCE_ABS"
    fi

    # fetch azkar and adhan if missing
    if ! curl -fsSL "$REPO_RAW_URL/azkar.txt" -o "$AZKAR_FILE"; then
        echo "⚠️ فشل جلب azkar.txt (استمرّ إذا كان لديك ملف محلي)"
    fi
    curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$ADHAN_FILE" >/dev/null 2>&1 || true

    # create symlink
    ln -sf "$SCRIPT_SOURCE_ABS" "$HOME/.local/bin/gtsalat"
    chmod +x "$HOME/.local/bin/gtsalat"

    # ensure zenity installed if possible
    install_zenity >/dev/null 2>&1 || true

    # create autostart .desktop with absolute path, delayed to allow session bus
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
    echo "🔔 يمكنك فحص الإشعارات مع: gtsalat --test-notify"

    # Run settings once if not done
    if ! load_config || [ "${SETUP_DONE:-}" != "true" ]; then
        "$SCRIPT_SOURCE_ABS" --settings
    fi

    # Start notifications once (installer behavior was to start notifications)
    "$SCRIPT_SOURCE_ABS" --notify-start || true
}

# ---- child mode entry ----
if [[ "${1:-}" == "--child-notify" ]]; then
    # Child mode must use script from INSTALL_DIR to ensure paths are correct
    # load config silently
    load_config || true
    notify_loop
    exit 0
fi

# ---- CLI ----
case "${1:-}" in
    --install)
        install_self
        exit 0
        ;;
    --settings)
        setup_wizard
        exit 0
        ;;
    --notify-start)
        # Do not run setup here; assume installer already did it. If not, check config and ask once.
        if ! load_config || [ "${SETUP_DONE:-}" != "true" ]; then
            echo "مطلوب إعداد بسيط قبل تشغيل الإشعارات."
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
        ensure_dbus >/dev/null 2>&1 || true
        show_notify "GT-salat-dikr" "اختبار: إذا ظهر هذا الإشعار فالنظام يدعم الإشعارات."
        exit 0
        ;;
    --show-timetable|-t)
        load_config || { echo "لا توجد إعدادات. شغّل: gtsalat --settings"; exit 1; }
        show_timetable || exit 1
        exit 0
        ;;
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        curl -fsSL "$REPO_RAW_URL/azkar.txt" -o "$AZKAR_FILE" && echo "✅ تم تحديث الأذكار." || echo "❌ فشل تحديث الأذكار."
        exit 0
        ;;
    --self-update)
        echo "فحص تحديث السكربت..."
        # simple check: compare remote sha1 if possible
        if command -v curl >/dev/null 2>&1 && command -v sha1sum >/dev/null 2>&1; then
            remote_hash=$(curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" | sha1sum | awk '{print $1}') || true
            local_hash=""
            if [ -f "$SCRIPT_SOURCE_ABS" ]; then local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}'); fi
            if [ -n "$remote_hash" ] && [ "$remote_hash" != "$local_hash" ]; then
                echo "يوجد تحديث جديد."
                read -p "هل تريد التحديث الآن؟ [Y/n]: " a; a=${a:-Y}
                if [[ "$a" =~ ^[Yy]$ ]]; then
                    tmpf=$(mktemp)
                    curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$tmpf" && chmod +x "$tmpf" && mv "$tmpf" "$SCRIPT_SOURCE_ABS" && echo "✅ تم تحديث السكربت."
                fi
            else
                echo "لا يوجد تحديث."
            fi
        else
            echo "خدمات الشبكة أو sha1sum غير متوفرة."
        fi
        exit 0
        ;;
    --uninstall)
        echo "من فضلك استعمل سكربت uninstall.sh المخصص لإلغاء التثبيت."
        exit 0
        ;;
    --help|-h)
        cat <<EOF
GT-salat-dikr - usage:
  --install         تثبيت السكربت وإعداد autostart (ينسخ الملفات إلى $INSTALL_DIR)
  --settings        إعداد الموقع وطريقة الحساب (مرة واحدة)
  --notify-start    بدء إشعارات الخلفية (يكتب PID في $PID_FILE)
  --notify-stop     إيقاف إشعارات الخلفية
  --test-notify     إرسال إشعار تجريبي
  --show-timetable  عرض مواقيت اليوم
  --update-azkar    تحديث ملف الأذكار
  --self-update     التحقق من تحديث السكربت وتثبيته تفاعليًا
EOF
        exit 0
        ;;
    "")
        # Default: show a random dhikr + next prayer summary
        load_config || true
        # show terminal dhikr
        zekr=$(show_random_zekr 2>/dev/null || true)
        if [ -n "$zekr" ]; then
            show_terminal_dhikr "$zekr"
        fi
        if load_config; then
            if get_next_prayer; then
                show_next_prayer_terminal "$PRAYER_NAME" "$PRAYER_LEFT"
            else
                echo "ℹ️ تعذر جلب جدول الصلاة (تأكد من اتصالك بالإنترنت ووجود jq/curl)."
            fi
        else
            echo "ℹ️ إعدادات غير مفعّلة. شغّل: gtsalat --settings"
        fi
        exit 0
        ;;
    *)
        echo "خيار غير معروف. استعمل --help لعرض الخيارات."
        exit 2
        ;;
esac
