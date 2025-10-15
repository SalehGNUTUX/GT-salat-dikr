#!/bin/bash
#
# GT-salat-dikr Uninstall Script (2024 متوافق مع فصل الإشعارات واختيار النظام)
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  إزالة تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
CONFIG_FILE="$INSTALL_DIR/settings.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل."
read -p "هل أنت متأكد؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🗑️  إزالة التثبيت..."

# إيقاف الخدمات
if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
        systemctl --user stop gt-salat-dikr.service
        systemctl --user disable gt-salat-dikr.service
    fi
    rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service"
    systemctl --user daemon-reload
    echo "✅ تمت إزالة خدمة systemd."
else
    # إذا كان هناك PID من sysvinit
    PID_FILE="$INSTALL_DIR/.gt-salat-dikr-notify.pid"
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null || true
        rm -f "$PID_FILE"
        echo "✅ تم إيقاف إشعارات sysvinit."
    fi
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop"
    echo "✅ تمت إزالة autostart."
fi

rm -f "$HOME/.local/bin/gtsalat"
rm -rf "$INSTALL_DIR"
echo "✅ تم حذف ملفات البرنامج."

echo ""
echo "💡 يمكنك إعادة التثبيت لاحقًا عن طريق:"
echo "   bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
echo "✅ تمت الإزالة بالكامل!"
