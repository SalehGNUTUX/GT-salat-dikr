#!/bin/bash
#
# GT-salat-dikr - النسخة المُصلحة النهائية
# Author: gnutux
#
set -euo pipefail

# ---------------- متغيرات عامة ----------------
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"

# تحديد موقع السكربت
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_SOURCE_ABS="$SCRIPT_PATH"

AZKAR_FILE="${SCRIPT_DIR}/azkar.txt"
CONFIG_FILE="${SCRIPT_DIR}/settings.conf"
TIMETABLE_FILE="${SCRIPT_DIR}/timetable.json"
PID_FILE="${SCRIPT_DIR}/.gt-salat-dikr-notify.pid"
NOTIFY_LOG="${SCRIPT_DIR}/notify.log"
ADHAN_FILE="${SCRIPT_DIR}/adhan.ogg"
ADHAN_PLAYER_SCRIPT="${SCRIPT_DIR}/adhan-player.sh"

REPO_AZKAR_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt"
REPO_SCRIPT_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh"
ALADHAN_API_URL="https://api.aladhan.com/v1/timings"

DEFAULT_ZIKR_INTERVAL=300
DEFAULT_PRE_NOTIFY=1

# ---------------- أدوات مساعدة ----------------
log() { 
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

# دالة log صامتة للاستخدام الداخلي فقط
silent_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$NOTIFY_LOG" 2>/dev/null || true
}

fetch_if_missing() {
    local file="$1"; local url="$2"
    if [ ! -f "$file" ]; then
        log "تحميل $file ..."
        if curl -fsSL "$url" -o "$file" 2>/dev/null; then
            log "تم تحميل $file"
        else
            log "فشل تحميل $file من $url"
            return 1
        fi
    fi
    return 0
}

# ---------------- اكتشاف البيئة الرسومية ----------------
detect_gui_tools() {
    GUI_TOOL=""
    
    if command -v zenity >/dev/null 2>&1; then
        GUI_TOOL="zenity"
    elif command -v yad >/dev/null 2>&1; then
        GUI_TOOL="yad"
    elif command -v kdialog >/dev/null 2>&1; then
        GUI_TOOL="kdialog"
    fi
    
    silent_log "GUI Tool detected: ${GUI_TOOL:-none}"
}

# ---------------- فحص أدوات النظام ----------------
check_tools() {
    detect_gui_tools
    
    if ! command -v jq >/dev/null 2>&1; then
        silent_log "تحذير: jq غير مثبت. بعض الميزات (جلب المواعيد) قد تفشل."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        silent_log "تحذير: notify-send غير موجود. الإشعارات لن تعمل بدون libnotify."
    fi
}

# ------------- ضبط DBUS -------------
ensure_dbus() {
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        return 0
    fi
    
    local bus="/run/user/$(id -u)/bus"
    if [ -S "$bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus"
        silent_log "DBUS: استخدام المسار القياسي $bus"
        return 0
    fi
    
    local tmp_bus="/tmp/dbus-$(whoami)"
    if [ -d "$tmp_bus" ]; then
        local sock=$(find "$tmp_bus" -name "session-*" -type s 2>/dev/null | head -1)
        if [ -n "$sock" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$sock"
            silent_log "DBUS: استخدام $sock"
            return 0
        fi
    fi
    
    local dbus_pid=$(pgrep -u "$(id -u)" dbus-daemon 2>/dev/null | head -1)
    if [ -n "$dbus_pid" ]; then
        local dbus_addr=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$dbus_pid/environ 2>/dev/null | cut -d= -f2- | tr -d '\0')
        if [ -n "$dbus_addr" ]; then
            export DBUS_SESSION_BUS_ADDRESS="$dbus_addr"
            silent_log "DBUS: استخراج من العملية $dbus_pid"
            return 0
        fi
    fi
    
    silent_log "تحذير: لم يتم العثور على DBUS"
    return 1
}

# ---------------- إنشاء مشغل الأذان الرسومي ----------------
create_adhan_player() {
    cat > "$ADHAN_PLAYER_SCRIPT" << 'ADHAN_PLAYER_EOF'
#!/bin/bash
ADHAN_FILE="$1"
PRAYER_NAME="$2"
PLAYER_PID_FILE="/tmp/gt-adhan-player-$$.pid"

if command -v zenity >/dev/null 2>&1; then
    GUI="zenity"
elif command -v yad >/dev/null 2>&1; then
    GUI="yad"
elif command -v kdialog >/dev/null 2>&1; then
    GUI="kdialog"
else
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}" 2>/dev/null || true
    exit 0
fi

PLAYER=""
if command -v mpv >/dev/null 2>&1; then
    PLAYER="mpv"
elif command -v ffplay >/dev/null 2>&1; then
    PLAYER="ffplay"
elif command -v paplay >/dev/null 2>&1; then
    PLAYER="paplay"
elif command -v ogg123 >/dev/null 2>&1; then
    PLAYER="ogg123"
fi

if [ -z "$PLAYER" ] || [ ! -f "$ADHAN_FILE" ]; then
    notify-send "GT-salat-dikr" "حان الآن وقت صلاة ${PRAYER_NAME}" 2>/dev/null || true
    exit 0
fi

play_adhan() {
    case "$PLAYER" in
        mpv) mpv --no-video --really-quiet "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        ffplay) ffplay -nodisp -autoexit -loglevel quiet "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        paplay) paplay "$ADHAN_FILE" >/dev/null 2>&1 & ;;
        ogg123) ogg123 -q "$ADHAN_FILE" >/dev/null 2>&1 & ;;
    esac
    echo $! > "$PLAYER_PID_FILE"
}

stop_adhan() {
    [ -f "$PLAYER_PID_FILE" ] && kill $(cat "$PLAYER_PID_FILE") 2>/dev/null
    pkill -f "$ADHAN_FILE" 2>/dev/null || true
    rm -f "$PLAYER_PID_FILE"
}

play_adhan

case "$GUI" in
    zenity)
        zenity --info --title="GT-salat-dikr" \
            --text="<b>حان الآن وقت صلاة ${PRAYER_NAME}</b>\n\n🕌 الله أكبر" \
            --width=400 --ok-label="إيقاف الأذان" 2>/dev/null
        stop_adhan
        ;;
    yad)
        yad --form --title="GT-salat-dikr" \
            --text="<b>حان الآن وقت صلاة ${PRAYER_NAME}</b>\n\n🕌 الله أكبر" \
            --button="إيقاف:0" --width=400 --center 2>/dev/null
        stop_adhan
        ;;
    kdialog)
        kdialog --title "GT-salat-dikr" \
            --msgbox "حان الآن وقت صلاة ${PRAYER_NAME}\n\n🕌 الله أكبر" 2>/dev/null
        stop_adhan
        ;;
esac

rm -f "$PLAYER_PID_FILE" 2>/dev/null
exit 0
ADHAN_PLAYER_EOF

    chmod +x "$ADHAN_PLAYER_SCRIPT"
    silent_log "تم إنشاء مشغل الأذان الرسومي"
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
    info=$(curl -fsSL "http://ip-api.com/json/" 2>/dev/null) || return 1
    LAT=$(echo "$info" | jq -r '.lat // empty' 2>/dev/null)
    LON=$(echo "$info" | jq -r '.lon // empty' 2>/dev/null)
    CITY=$(echo "$info" | jq -r '.city // empty' 2>/dev/null)
    COUNTRY=$(echo "$info" | jq -r '.country // empty' 2>/dev/null)
    [[ -z "$LAT" || -z "$LON" ]] && return 1
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
        [[ ! "$ans" =~ ^[Yy]$ ]] && manual_location
    else
        echo "تعذر اكتشاف الموقع تلقائيًا — أدخل البيانات يدويًا."
        manual_location
    fi
    choose_method
    read -p "تفعيل تنبيه قبل الصلاة بـ10 دقائق؟ [Y/n]: " p; p=${p:-Y}
    [[ "$p" =~ ^[Yy]$ ]] && PRE_PRAYER_NOTIFY=1 || PRE_PRAYER_NOTIFY=0
    read -p "فاصل الأذكار بالثواني (افتراضي $DEFAULT_ZIKR_INTERVAL): " z
    ZIKR_NOTIFY_INTERVAL=${z:-$DEFAULT_ZIKR_INTERVAL}
    read -p "تفعيل التحديث الذاتي؟ [y/N]: " up; up=${up:-N}
    [[ "$up" =~ ^[Yy]$ ]] && AUTO_SELF_UPDATE=1 || AUTO_SELF_UPDATE=0
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
    resp=$(curl -fsSL "$url" 2>/dev/null) || { log "تعذر جلب مواقيت الصلاة."; return 1; }
    echo "$resp" > "$TIMETABLE_FILE"
    log "تم جلب جدول المواقيت"
    return 0
}

read_timetable() {
    [ ! -f "$TIMETABLE_FILE" ] && { fetch_timetable || return 1; }
    local tdate=$(jq -r '.data.date.gregorian.date' "$TIMETABLE_FILE" 2>/dev/null || echo "")
    [ "$tdate" != "$(date +%d-%m-%Y)" ] && { fetch_timetable || return 1; }
    return 0
}

show_timetable() {
    read_timetable || { echo "تعذر قراءة جدول المواقيت."; return 1; }
    echo "مواقيت الصلاة اليوم ($CITY):"
    local names=("Fajr" "Sunrise" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الشروق" "الظهر" "العصر" "المغرب" "العشاء")
    for i in "${!names[@]}"; do
        local time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        printf "%10s: %s\n" "${arnames[$i]}" "$time"
    done
}

# ---------------- zikr ----------------
show_random_zekr() {
    [ ! -f "$AZKAR_FILE" ] && { echo ""; return 1; }
    awk -v RS='%' '{gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $0); if(length($0)>0) print $0}' "$AZKAR_FILE" | shuf -n 1
}

show_zekr_notify() {
    local zekr=$(show_random_zekr)
    [ -z "$zekr" ] && zekr="لم يتم العثور على ذكر!"
    notify-send "GT-salat-dikr" "$zekr" 2>/dev/null || true
}

# ---------------- adhan play ----------------
play_adhan_gui() {
    local prayer_name="${1:-الصلاة}"
    [ ! -f "$ADHAN_PLAYER_SCRIPT" ] && create_adhan_player
    "$ADHAN_PLAYER_SCRIPT" "$ADHAN_FILE" "$prayer_name" &
}

# ---------------- next prayer ----------------
get_next_prayer() {
    read_timetable || return 1
    local names=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")
    local arnames=("الفجر" "الظهر" "العصر" "المغرب" "العشاء")
    local now_secs=$(date +%s)
    for i in "${!names[@]}"; do
        local time=$(jq -r ".data.timings.${names[$i]}" "$TIMETABLE_FILE" | cut -d' ' -f1)
        local h=${time%%:*}; local m=${time#*:}
        local prayer_secs=$(date -d "$(date +%Y-%m-%d) $h:$m" +%s)
        local diff=$((prayer_secs - now_secs))
        if [ $diff -ge 0 ]; then
            PRAYER_NAME="${arnames[$i]}"
            PRAYER_TIME="$time"
            PRAYER_LEFT=$diff
            return 0
        fi
    done
    PRAYER_NAME="الفجر"
    PRAYER_TIME=$(jq -r ".data.timings.Fajr" "$TIMETABLE_FILE" | cut -d' ' -f1)
    PRAYER_LEFT=$(( $(date -d "tomorrow $PRAYER_TIME" +%s) - now_secs ))
    return 0
}

# ---------------- prayer notifications ----------------
show_pre_prayer_notify() {
    get_next_prayer || return 1
    notify-send "GT-salat-dikr" "تبقى 10 دقائق على صلاة ${PRAYER_NAME} (${PRAYER_TIME})" 2>/dev/null || true
}

show_prayer_notify() {
    get_next_prayer || return 1
    play_adhan_gui "$PRAYER_NAME"
}

# ---------------- notify loop ----------------
notify_loop() {
    trap 'rm -f "$PID_FILE" 2>/dev/null; exit 0' EXIT INT TERM

    local notify_flag_file="${SCRIPT_DIR}/.last-prayer-notified"
    local pre_notify_flag_file="${SCRIPT_DIR}/.last-preprayer-notified"

    while true; do
        show_zekr_notify || true

        if ! get_next_prayer; then
            sleep 30
            continue
        fi

        if [ "${PRE_PRAYER_NOTIFY:-1}" = "1" ] && [ "$PRAYER_LEFT" -le 600 ] && [ "$PRAYER_LEFT" -gt 0 ]; then
            if [ ! -f "$pre_notify_flag_file" ] || [ "$(cat "$pre_notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                show_pre_prayer_notify
                echo "$PRAYER_NAME" > "$pre_notify_flag_file"
            fi
        fi

        if [ "$PRAYER_LEFT" -le 0 ]; then
            if [ ! -f "$notify_flag_file" ] || [ "$(cat "$notify_flag_file" 2>/dev/null)" != "$PRAYER_NAME" ]; then
                show_prayer_notify
                echo "$PRAYER_NAME" > "$notify_flag_file"
                rm -f "$pre_notify_flag_file" 2>/dev/null
            fi
        fi

        local sleep_for="${ZIKR_NOTIFY_INTERVAL:-$DEFAULT_ZIKR_INTERVAL}"
        [ "$PRAYER_LEFT" -gt 0 ] && [ "$PRAYER_LEFT" -lt "$sleep_for" ] && sleep_for=$((PRAYER_LEFT < 2 ? 2 : PRAYER_LEFT))
        sleep "$sleep_for"
    done
}

# ---------------- start/stop notify ----------------
start_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الإشعارات تعمل بالفعل (PID: $pid)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    ensure_dbus
    check_tools
    create_adhan_player

    # بدء العملية بطريقة مبسطة
    setsid bash -c "
        cd '$SCRIPT_DIR'
        export DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}'
        export DISPLAY='${DISPLAY:-:0}'
        '$SCRIPT_SOURCE_ABS' --child-notify >> '$NOTIFY_LOG' 2>&1
    " >/dev/null 2>&1 < /dev/null &
    
    local child_pid=$!
    echo "$child_pid" > "$PID_FILE"
    
    sleep 2
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
        echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $(cat "$PID_FILE"))"
        log "started notify loop (PID: $(cat "$PID_FILE"))"
        return 0
    else
        echo "❌ فشل في بدء الإشعارات - راجع السجل: gtsalat --logs"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_notify_bg() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            echo "✅ تم إيقاف الإشعارات"
            return 0
        fi
    fi
    echo "ℹ️ لا يوجد إشعارات قيد التشغيل"
    return 1
}

# ---------------- self-update ----------------
check_script_update() {
    if ! command -v curl >/dev/null 2>&1 || ! command -v sha1sum >/dev/null 2>&1; then
        silent_log "لا يمكن التحقق من التحديث."
        return 1
    fi
    local local_hash remote_hash
    [ -f "$SCRIPT_SOURCE_ABS" ] && local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}') || local_hash=""
    remote_hash=$(curl -fsSL "$REPO_SCRIPT_URL" 2>/dev/null | sha1sum | awk '{print $1}') || return 1
    if [ "$local_hash" != "" ] && [ "$local_hash" != "$remote_hash" ]; then
        # يوجد تحديث - لا نطبع شيء في الوضع الصامت
        silent_log "يوجد تحديث جديد للسكريبت"
        return 0
    else
        silent_log "لا يوجد تحديث"
    fi
    return 0
}

# ---------------- install ----------------
install_self() {
    mkdir -p "$INSTALL_DIR" "$HOME/.local/bin"

    cp -f "$SCRIPT_SOURCE_ABS" "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

    fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" || true
    fetch_if_missing "$ADHAN_FILE" "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/adhan.ogg" || true

    ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$HOME/.local/bin/gtsalat"
    chmod +x "$HOME/.local/bin/gtsalat"

    # --- إضافة إلى جميع shell RC files ---
    local added=false
    add_to_shell_rc() {
        local RC_FILE="$1"
        if [ -f "$RC_FILE" ]; then
            if ! grep -Fq "$INSTALL_DIR/$SCRIPT_NAME" "$RC_FILE"; then
                echo "" >> "$RC_FILE"
                echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$RC_FILE"
                echo "\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$RC_FILE"
                added=true
            fi
        fi
    }
    
    add_to_shell_rc "$HOME/.bashrc"
    add_to_shell_rc "$HOME/.zshrc"
    add_to_shell_rc "$HOME/.profile"
    
    # دعم Fish shell
    if [ -d "$HOME/.config/fish" ]; then
        local fish_config="$HOME/.config/fish/config.fish"
        if [ -f "$fish_config" ]; then
            if ! grep -q "GT-salat-dikr" "$fish_config"; then
                echo "" >> "$fish_config"
                echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$fish_config"
                echo "if test -f \$HOME/.GT-salat-dikr/gt-salat-dikr.sh" >> "$fish_config"
                echo "    \$HOME/.GT-salat-dikr/gt-salat-dikr.sh 2>/dev/null" >> "$fish_config"
                echo "end" >> "$fish_config"
                added=true
            fi
        fi
    fi
    
    # دعم Ksh
    if [ -f "$HOME/.kshrc" ]; then
        add_to_shell_rc "$HOME/.kshrc"
    fi
    
    # دعم Tcsh/Csh
    if [ -f "$HOME/.cshrc" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.cshrc"; then
            echo "" >> "$HOME/.cshrc"
            echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$HOME/.cshrc"
            echo "\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$HOME/.cshrc"
            added=true
        fi
    fi
    
    if [ "$added" = true ]; then
        echo "✅ تم إضافة عرض الذكر ووقت الصلاة عند فتح الطرفية"
    fi

    # --- XDG autostart للإشعارات ---
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Name[ar]=إشعارات الصلاة والأذكار
Exec=bash -c "sleep 30 && $INSTALL_DIR/$SCRIPT_NAME --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-MATE-Autostart-enabled=true
X-XFCE-autostart-enabled=true
StartupNotify=false
Terminal=false
Icon=preferences-system-time
Comment=Start prayer times and azkar notifications
Comment[ar]=بدء إشعارات أوقات الصلاة والأذكار
Categories=Utility;
EOF
    echo "✅ تم إنشاء ملف autostart للإشعارات"

    # --- systemd user service (للتوزيعات الحديثة) ---
    if command -v systemctl >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/systemd/user"
        cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Times and Azkar Notifications
After=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$SCRIPT_NAME --child-notify
Restart=on-failure
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="DISPLAY=:0"

[Install]
WantedBy=default.target
EOF
        
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable gt-salat-dikr.service 2>/dev/null || true
        echo "✅ تم إنشاء وتفعيل systemd service"
    fi

    # --- دعم i3wm ---
    if [ -f "$HOME/.config/i3/config" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.config/i3/config"; then
            echo "" >> "$HOME/.config/i3/config"
            echo "# GT-salat-dikr autostart" >> "$HOME/.config/i3/config"
            echo "exec --no-startup-id $INSTALL_DIR/$SCRIPT_NAME --notify-start" >> "$HOME/.config/i3/config"
            echo "✅ تم إضافة autostart إلى i3 config"
        fi
    fi

    # --- دعم Sway ---
    if [ -f "$HOME/.config/sway/config" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.config/sway/config"; then
            echo "" >> "$HOME/.config/sway/config"
            echo "# GT-salat-dikr autostart" >> "$HOME/.config/sway/config"
            echo "exec $INSTALL_DIR/$SCRIPT_NAME --notify-start" >> "$HOME/.config/sway/config"
            echo "✅ تم إضافة autostart إلى Sway config"
        fi
    fi

    # --- دعم Openbox ---
    if [ -f "$HOME/.config/openbox/autostart" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.config/openbox/autostart"; then
            echo "" >> "$HOME/.config/openbox/autostart"
            echo "# GT-salat-dikr autostart" >> "$HOME/.config/openbox/autostart"
            echo "$INSTALL_DIR/$SCRIPT_NAME --notify-start &" >> "$HOME/.config/openbox/autostart"
            echo "✅ تم إضافة autostart إلى Openbox"
        fi
    fi

    # --- دعم LXDE ---
    if [ -d "$HOME/.config/lxsession" ]; then
        local lxde_autostart="$HOME/.config/lxsession/LXDE/autostart"
        [ -f "$lxde_autostart" ] || lxde_autostart="$HOME/.config/lxsession/Lubuntu/autostart"
        if [ -f "$lxde_autostart" ]; then
            if ! grep -q "GT-salat-dikr" "$lxde_autostart"; then
                echo "" >> "$lxde_autostart"
                echo "@$INSTALL_DIR/$SCRIPT_NAME --notify-start" >> "$lxde_autostart"
                echo "✅ تم إضافة autostart إلى LXDE"
            fi
        fi
    fi

    # --- دعم Awesome WM ---
    if [ -f "$HOME/.config/awesome/rc.lua" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.config/awesome/rc.lua"; then
            echo "" >> "$HOME/.config/awesome/rc.lua"
            echo "-- GT-salat-dikr autostart" >> "$HOME/.config/awesome/rc.lua"
            echo "awful.spawn.with_shell(\"$INSTALL_DIR/$SCRIPT_NAME --notify-start\")" >> "$HOME/.config/awesome/rc.lua"
            echo "✅ تم إضافة autostart إلى Awesome WM"
        fi
    fi

    # --- دعم bspwm ---
    if [ -f "$HOME/.config/bspwm/bspwmrc" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.config/bspwm/bspwmrc"; then
            echo "" >> "$HOME/.config/bspwm/bspwmrc"
            echo "# GT-salat-dikr autostart" >> "$HOME/.config/bspwm/bspwmrc"
            echo "$INSTALL_DIR/$SCRIPT_NAME --notify-start &" >> "$HOME/.config/bspwm/bspwmrc"
            echo "✅ تم إضافة autostart إلى bspwm"
        fi
    fi

    # --- دعم dwm/startx ---
    if [ -f "$HOME/.xinitrc" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.xinitrc"; then
            echo "" >> "$HOME/.xinitrc"
            echo "# GT-salat-dikr autostart" >> "$HOME/.xinitrc"
            echo "$INSTALL_DIR/$SCRIPT_NAME --notify-start &" >> "$HOME/.xinitrc"
            echo "✅ تم إضافة autostart إلى .xinitrc"
        fi
    fi
    
    if [ -f "$HOME/.xsession" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.xsession"; then
            echo "" >> "$HOME/.xsession"
            echo "# GT-salat-dikr autostart" >> "$HOME/.xsession"
            echo "$INSTALL_DIR/$SCRIPT_NAME --notify-start &" >> "$HOME/.xsession"
            echo "✅ تم إضافة autostart إلى .xsession"
        fi
    fi

    echo ""
    echo "✅ تم التثبيت في $INSTALL_DIR"
    echo "💡 أعد فتح الطرفية لرؤية الذكر عند الفتح"
    echo "💡 سيبدأ البرنامج تلقائياً عند بدء تشغيل النظام"
    echo ""
    
    read -p "بدء الإشعارات الآن؟ [Y/n]: " start_now
    [[ "${start_now:-Y}" =~ ^[Yy]$ ]] && start_notify_bg
}

uninstall_self() {
    stop_notify_bg || true
    
    # إيقاف systemd service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop gt-salat-dikr.service 2>/dev/null || true
        systemctl --user disable gt-salat-dikr.service 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
    fi
    
    # حذف الملفات
    rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service" 2>/dev/null || true
    
    # إزالة من shell RC files
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.kshrc" "$HOME/.cshrc"; do
        if [ -f "$rc_file" ]; then
            sed -i '/# GT-salat-dikr/d' "$rc_file" 2>/dev/null || true
            sed -i "\|$INSTALL_DIR|d" "$rc_file" 2>/dev/null || true
        fi
    done
    
    # Fish shell
    if [ -f "$HOME/.config/fish/config.fish" ]; then
        sed -i '/# GT-salat-dikr/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
        sed -i "\|$INSTALL_DIR|d" "$HOME/.config/fish/config.fish" 2>/dev/null || true
    fi
    
    # WM configs
    for config_file in "$HOME/.config/i3/config" "$HOME/.config/sway/config" \
                       "$HOME/.config/openbox/autostart" "$HOME/.config/awesome/rc.lua" \
                       "$HOME/.config/bspwm/bspwmrc" "$HOME/.xinitrc" "$HOME/.xsession"; do
        if [ -f "$config_file" ]; then
            sed -i '/# GT-salat-dikr/d' "$config_file" 2>/dev/null || true
            sed -i '/GT-salat-dikr/d' "$config_file" 2>/dev/null || true
        fi
    done
    
    # LXDE
    for lxde_file in "$HOME/.config/lxsession/LXDE/autostart" "$HOME/.config/lxsession/Lubuntu/autostart"; do
        if [ -f "$lxde_file" ]; then
            sed -i '/GT-salat-dikr/d' "$lxde_file" 2>/dev/null || true
        fi
    done
    
    echo "✅ تم إزالة GT-salat-dikr بالكامل."
    echo "💡 أعد فتح الطرفية لتطبيق التغييرات."
}

# ---------------- child mode ----------------
if [[ "${1:-}" == "--child-notify" ]]; then
    ensure_dbus
    check_tools
    notify_loop
    exit 0
fi

# ---------------- تحميل الإعدادات ----------------
check_tools
fetch_if_missing "$AZKAR_FILE" "$REPO_AZKAR_URL" >/dev/null 2>&1 || true

if [ ! -f "$CONFIG_FILE" ]; then
    setup_wizard
else
    load_config || setup_wizard
fi

# التحديث التلقائي (صامت)
if [ "${AUTO_SELF_UPDATE:-0}" = "1" ]; then
    check_script_update >/dev/null 2>&1 || true
fi

# ---------------- CLI ----------------
case "${1:-}" in
    --install) install_self ;;
    --uninstall) uninstall_self ;;
    --settings) setup_wizard ;;
    --show-timetable|-t) show_timetable ;;
    --notify-start) start_notify_bg ;;
    --notify-stop) stop_notify_bg ;;
    --test-notify)
        ensure_dbus
        notify-send "GT-salat-dikr" "اختبار إشعار ✔" 2>/dev/null && echo "تم إرسال إشعار" || echo "فشل"
        ;;
    --test-adhan)
        ensure_dbus
        create_adhan_player
        play_adhan_gui "اختبار"
        ;;
    --update-azkar)
        echo "جلب أحدث نسخة من الأذكار..."
        curl -fsSL "$REPO_AZKAR_URL" -o "$AZKAR_FILE" 2>/dev/null && echo "✅ تم التحديث" || echo "فشل التحديث"
        ;;
    --self-update)
        if ! command -v curl >/dev/null 2>&1 || ! command -v sha1sum >/dev/null 2>&1; then
            echo "❌ curl أو sha1sum غير متوفر"
            exit 1
        fi
        local_hash=""
        [ -f "$SCRIPT_SOURCE_ABS" ] && local_hash=$(sha1sum "$SCRIPT_SOURCE_ABS" | awk '{print $1}')
        remote_hash=$(curl -fsSL "$REPO_SCRIPT_URL" 2>/dev/null | sha1sum | awk '{print $1}') || {
            echo "❌ فشل الاتصال بالإنترنت"
            exit 1
        }
        if [ "$local_hash" != "" ] && [ "$local_hash" != "$remote_hash" ]; then
            echo "✨ يوجد تحديث جديد!"
            read -p "تحديث الآن؟ [Y/n]: " ans
            ans=${ans:-Y}
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                tmpf=$(mktemp)
                curl -fsSL "$REPO_SCRIPT_URL" -o "$tmpf" 2>/dev/null || {
                    echo "❌ فشل التحميل"
                    rm -f "$tmpf"
                    exit 1
                }
                chmod +x "$tmpf"
                mv "$tmpf" "$SCRIPT_SOURCE_ABS" && echo "✅ تم التحديث بنجاح"
            else
                echo "تم إلغاء التحديث"
            fi
        else
            echo "✅ أنت تستخدم أحدث إصدار"
        fi
        ;;
    --status)
        echo "📊 حالة GT-salat-dikr:"
        echo "════════════════════════════════"
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE" 2>/dev/null)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "✅ الإشعارات: تعمل (PID: $pid)"
            else
                echo "❌ الإشعارات: متوقفة"
            fi
        else
            echo "❌ الإشعارات: متوقفة"
        fi
        echo ""
        if [ -f "$CONFIG_FILE" ]; then
            load_config
            echo "📍 الموقع: $CITY, $COUNTRY"
            echo "🧭 الإحداثيات: $LAT, $LON"
            echo "📖 طريقة الحساب: $METHOD_NAME"
        fi
        echo ""
        if get_next_prayer 2>/dev/null; then
            leftmin=$((PRAYER_LEFT/60))
            lefth=$((leftmin/60))
            leftm=$((leftmin%60))
            echo "🕌 الصلاة القادمة: $PRAYER_NAME"
            echo "⏰ الوقت: $PRAYER_TIME"
            printf "⏳ المتبقي: %02d:%02d\n" "$lefth" "$leftm"
        fi
        ;;
    --logs)
        if [ -f "$NOTIFY_LOG" ]; then
            echo "📋 آخر 20 سطر من السجل:"
            echo "════════════════════════════════"
            tail -n 20 "$NOTIFY_LOG"
        else
            echo "لا يوجد ملف سجل."
        fi
        ;;
    --debug)
        echo "🔍 معلومات التشخيص:"
        echo "════════════════════════════════"
        echo "DBUS_SESSION_BUS_ADDRESS: ${DBUS_SESSION_BUS_ADDRESS:-غير معرف}"
        echo "DISPLAY: ${DISPLAY:-غير معرف}"
        echo "USER: $(whoami)"
        echo "HOME: $HOME"
        echo "SCRIPT_DIR: $SCRIPT_DIR"
        echo ""
        echo "الأدوات المثبتة:"
        command -v jq >/dev/null 2>&1 && echo "  ✓ jq" || echo "  ✗ jq"
        command -v notify-send >/dev/null 2>&1 && echo "  ✓ notify-send" || echo "  ✗ notify-send"
        command -v zenity >/dev/null 2>&1 && echo "  ✓ zenity" || echo "  ✗ zenity"
        command -v yad >/dev/null 2>&1 && echo "  ✓ yad" || echo "  ✗ yad"
        command -v kdialog >/dev/null 2>&1 && echo "  ✓ kdialog" || echo "  ✗ kdialog"
        command -v mpv >/dev/null 2>&1 && echo "  ✓ mpv" || echo "  ✗ mpv"
        echo ""
        echo "ملفات البرنامج:"
        [ -f "$SCRIPT_SOURCE_ABS" ] && echo "  ✓ السكربت الرئيسي" || echo "  ✗ السكربت الرئيسي"
        [ -f "$AZKAR_FILE" ] && echo "  ✓ ملف الأذكار" || echo "  ✗ ملف الأذكار"
        [ -f "$ADHAN_FILE" ] && echo "  ✓ ملف الأذان" || echo "  ✗ ملف الأذان"
        [ -f "$CONFIG_FILE" ] && echo "  ✓ ملف الإعدادات" || echo "  ✗ ملف الإعدادات"
        [ -f "$ADHAN_PLAYER_SCRIPT" ] && echo "  ✓ مشغل الأذان" || echo "  ✗ مشغل الأذان"
        echo ""
        if [ -f "$NOTIFY_LOG" ]; then
            echo "آخر 5 أسطر من السجل:"
            tail -n 5 "$NOTIFY_LOG"
        fi
        ;;
    --help|-h)
        cat <<EOF
═══════════════════════════════════════════════════════════
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار
═══════════════════════════════════════════════════════════

📦 التثبيت:
  --install           تثبيت البرنامج مع autostart
  --uninstall         إزالة البرنامج

⚙️  الإعدادات:
  --settings          تعديل الموقع والإعدادات

📊 العرض:
  --show-timetable    عرض مواقيت الصلاة
  --status            عرض حالة البرنامج
  --logs              عرض السجل
  --debug             معلومات التشخيص

🔔 الإشعارات:
  --notify-start      بدء الإشعارات
  --notify-stop       إيقاف الإشعارات

🧪 الاختبار:
  --test-notify       اختبار إشعار
  --test-adhan        اختبار الأذان

🔄 التحديث:
  --update-azkar      تحديث الأذكار
  --self-update       تحديث البرنامج

ℹ️  --help, -h        هذه المساعدة

═══════════════════════════════════════════════════════════
💡 الاستخدام الافتراضي: تشغيل بدون خيارات يعرض ذكر ووقت الصلاة
═══════════════════════════════════════════════════════════
EOF
        ;;
    '')
        # الوضع الافتراضي: عرض الذكر والصلاة القادمة فقط (بدون رسائل إضافية)
        zekr=$(show_random_zekr 2>/dev/null)
        if [ -n "$zekr" ]; then
            echo "$zekr"
            echo ""
        fi
        
        if get_next_prayer 2>/dev/null; then
            leftmin=$((PRAYER_LEFT/60))
            lefth=$((leftmin/60))
            leftm=$((leftmin%60))
            printf "\e[1;34m🕌 الصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "$PRAYER_NAME" "$PRAYER_TIME" "$lefth" "$leftm"
        fi
        ;;
    *)
        echo "❌ خيار غير معروف: $1"
        echo "استخدم --help لعرض الخيارات"
        exit 2
        ;;
esac

exit 0ad" || echo "  ✗ yad"
        command -v kdialog >/dev/null 2>&1 && echo "  ✓ kdialog" || echo "  ✗ kdialog"
        command -v mpv >/dev/null 2>&1 && echo "  ✓ mpv" || echo "  ✗ mpv"
        echo ""
        echo "ملفات البرنامج:"
        [ -f "$SCRIPT_SOURCE_ABS" ] && echo "  ✓ السكربت الرئيسي" || echo "  ✗ السكربت الرئيسي"
        [ -f "$AZKAR_FILE" ] && echo "  ✓ ملف الأذكار" || echo "  ✗ ملف الأذكار"
        [ -f "$ADHAN_FILE" ] && echo "  ✓ ملف الأذان" || echo "  ✗ ملف الأذان"
        [ -f "$CONFIG_FILE" ] && echo "  ✓ ملف الإعدادات" || echo "  ✗ ملف الإعدادات"
        [ -f "$ADHAN_PLAYER_SCRIPT" ] && echo "  ✓ مشغل الأذان" || echo "  ✗ مشغل الأذان"
        echo ""
        if [ -f "$NOTIFY_LOG" ]; then
            echo "آخر 5 أسطر من السجل:"
            tail -n 5 "$NOTIFY_LOG"
        fi
        ;;
    --help|-h)
        cat <<EOF
═══════════════════════════════════════════════════════════
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار
═══════════════════════════════════════════════════════════

📦 التثبيت:
  --install           تثبيت البرنامج مع autostart
  --uninstall         إزالة البرنامج

⚙️  الإعدادات:
  --settings          تعديل الموقع والإعدادات

📊 العرض:
  --show-timetable    عرض مواقيت الصلاة
  --status            عرض حالة البرنامج
  --logs              عرض السجل
  --debug             معلومات التشخيص

🔔 الإشعارات:
  --notify-start      بدء الإشعارات
  --notify-stop       إيقاف الإشعارات

🧪 الاختبار:
  --test-notify       اختبار إشعار
  --test-adhan        اختبار الأذان

🔄 التحديث:
  --update-azkar      تحديث الأذكار
  --self-update       تحديث البرنامج

ℹ️  --help, -h        هذه المساعدة

═══════════════════════════════════════════════════════════
EOF
        ;;
    '')
        local zekr=$(show_random_zekr)
        [ -n "$zekr" ] && echo "$zekr"
        if get_next_prayer 2>/dev/null; then
            local leftmin=$((PRAYER_LEFT/60))
            local lefth=$((leftmin/60))
            local leftm=$((leftmin%60))
            printf "\n\e[1;34m🕌 الصلاة القادمة: %s عند %s (باقي %02d:%02d)\e[0m\n" "$PRAYER_NAME" "$PRAYER_TIME" "$lefth" "$leftm"
        fi
        ;;
    *)
        echo "❌ خيار غير معروف: $1"
        echo "استخدم --help لعرض الخيارات"
        exit 2
        ;;
esac

exit 0
