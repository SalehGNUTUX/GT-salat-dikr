#!/bin/bash
# GT-salat-dikr — Prayer and Dhikr Notifications
# by gnutux | License: GPLv3
# الإصدار: 2.0 (2025-10-05)

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOCK_FILE="/tmp/gt-salat-dikr.lock"
LOG_FILE="$SCRIPT_DIR/gt-salat-dikr.log"

# ========== [ 🔒 منع التشغيل المتكرر ] ==========
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "⚠️ البرنامج يعمل بالفعل (PID=$OLD_PID)" >&2
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ========== [ 🌐 إعداد البيئة الرسومية ] ==========
if [ -z "${DISPLAY:-}" ]; then
    export DISPLAY=:0
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    elif [ -S "/run/user/$(id -u)/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    fi
fi

# ========== [ 🕋 الوظائف الأساسية ] ==========
notify_prayer() {
    local PRAYER_NAME="$1"
    local PRAYER_TIME="$2"
    notify-send "🕌 $PRAYER_NAME" "الوقت الآن: $PRAYER_TIME" -i prayer-symbolic || true
    echo "$(date '+%F %T') — $PRAYER_NAME at $PRAYER_TIME" >> "$LOG_FILE"
}

play_adhan() {
    local SOUND_FILE="$SCRIPT_DIR/adhan.ogg"
    if [ -f "$SOUND_FILE" ]; then
        paplay "$SOUND_FILE" &>/dev/null || aplay "$SOUND_FILE" &>/dev/null || true
    fi
}

# ========== [ 🚀 المعالجة الأساسية ] ==========
case "${1:-}" in
    --notify-start)
        notify-send "🌙 GT-salat-dikr" "بدأ البرنامج في الخلفية بنجاح."
        ;;
    --child-notify)
        sleep 15
        notify-send "🌙 GT-salat-dikr" "الخدمة بدأت مع النظام."
        ;;
    --uninstall)
        echo "🗑 جاري إزالة GT-salat-dikr..."
        read -rp "هل تريد حذف مجلد التثبيت $SCRIPT_DIR نهائيًا؟ [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -rf "$SCRIPT_DIR"
            echo "✅ تمت إزالة $SCRIPT_DIR"
        fi
        rm -f ~/.config/autostart/gt-salat-dikr.desktop
        systemctl --user disable --now gt-salat-dikr.service 2>/dev/null || true
        rm -f ~/.config/systemd/user/gt-salat-dikr.service
        echo "✅ تم إلغاء التثبيت بنجاح."
        exit 0
        ;;
    *)
        echo "📿 GT-salat-dikr يعمل..."
        ;;
esac
