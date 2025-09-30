#!/bin/bash
#
# GT-salat-dikr Uninstallation Script
# إزالة كاملة من جميع بيئات سطح المكتب
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  🚫 إزالة GT-salat-dikr"
echo "════════════════════════════════════════════════════════"
echo ""

# تأكيد الإزالة
read -p "⚠️  هل أنت متأكد من إزالة GT-salat-dikr؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🧹 جاري إزالة GT-salat-dikr..."

INSTALL_DIR="$HOME/.GT-salat-dikr"

# إيقاف الإشعارات النشطة
echo "  → إيقاف الإشعارات النشطة..."
if [ -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" ]; then
    pid=$(cat "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        sleep 1
        kill -9 "$pid" 2>/dev/null || true
        echo "     ✓ تم إيقاف العملية (PID: $pid)"
    fi
fi

# إيقاف systemd service
echo "  → إيقاف خدمة systemd..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop gt-salat-dikr.service 2>/dev/null || true
    systemctl --user disable gt-salat-dikr.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    echo "     ✓ تمت إزالة خدمة systemd"
fi

# حذف ملفات autostart
echo "  → إزالة ملفات autostart..."

# XDG autostart
if [ -f "$HOME/.config/autostart/gt-salat-dikr.desktop" ]; then
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop"
    echo "     ✓ تمت إزالة XDG autostart"
fi

# إزالة من .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if grep -q "GT-salat-dikr" "$HOME/.bashrc"; then
        sed -i '/# GT-salat-dikr autostart/,+5d' "$HOME/.bashrc" 2>/dev/null || true
        echo "     ✓ تمت إزالة autostart من .bashrc"
    fi
fi

# إزالة من .zshrc
if [ -f "$HOME/.zshrc" ]; then
    if grep -q "GT-salat-dikr" "$HOME/.zshrc"; then
        sed -i '/# GT-salat-dikr autostart/,+5d' "$HOME/.zshrc" 2>/dev/null || true
        echo "     ✓ تمت إزالة autostart من .zshrc"
    fi
fi

# إزالة من i3 config
if [ -f "$HOME/.config/i3/config" ]; then
    if grep -q "GT-salat-dikr" "$HOME/.config/i3/config"; then
        sed -i '/GT-salat-dikr/d' "$HOME/.config/i3/config" 2>/dev/null || true
        echo "     ✓ تمت إزالة من i3 config"
    fi
fi

# إزالة من Openbox autostart
if [ -f "$HOME/.config/openbox/autostart" ]; then
    if grep -q "GT-salat-dikr" "$HOME/.config/openbox/autostart"; then
        sed -i '/GT-salat-dikr/d' "$HOME/.config/openbox/autostart" 2>/dev/null || true
        echo "     ✓ تمت إزالة من Openbox autostart"
    fi
fi

# إزالة من XFCE autostart
if [ -f "$HOME/.config/xfce4/xinitrc" ]; then
    if grep -q "GT-salat-dikr" "$HOME/.config/xfce4/xinitrc"; then
        sed -i '/GT-salat-dikr/d' "$HOME/.config/xfce4/xinitrc" 2>/dev/null || true
        echo "     ✓ تمت إزالة من XFCE autostart"
    fi
fi

# إزالة من KDE autostart
if [ -d "$HOME/.config/autostart-scripts" ]; then
    rm -f "$HOME/.config/autostart-scripts/gt-salat-dikr.sh" 2>/dev/null || true
    echo "     ✓ تمت إزالة من KDE autostart"
fi

# حذف الاختصار
echo "  → إزالة الاختصار..."
if [ -f "$HOME/.local/bin/gtsalat" ]; then
    rm -f "$HOME/.local/bin/gtsalat"
    echo "     ✓ تمت إزالة gtsalat"
fi

# حذف مجلد التثبيت
echo "  → إزالة ملفات البرنامج..."
if [ -d "$INSTALL_DIR" ]; then
    # سؤال عن الاحتفاظ بالإعدادات
    read -p "   هل تريد الاحتفاظ بملف الإعدادات؟ [y/N]: " keep_settings
    if [[ "$keep_settings" =~ ^[Yy]$ ]]; then
        if [ -f "$INSTALL_DIR/settings.conf" ]; then
            cp "$INSTALL_DIR/settings.conf" "$HOME/.gt-salat-dikr-settings.backup"
            echo "     ✓ تم حفظ الإعدادات في: ~/.gt-salat-dikr-settings.backup"
        fi
    fi
    
    rm -rf "$INSTALL_DIR"
    echo "     ✓ تمت إزالة مجلد التثبيت"
fi

# تنظيف العمليات المتبقية
echo "  → تنظيف العمليات المتبقية..."
pkill -f "gt-salat-dikr.sh" 2>/dev/null || true
pkill -f "adhan-player.sh" 2>/dev/null || true

# إزالة النسخ الاحتياطية القديمة
rm -f "$HOME/.gt-salat-dikr-notify.pid" 2>/dev/null || true
rm -f "$HOME/.gt-salat-dikr-settings.backup~" 2>/dev/null || true

echo ""
echo "════════════════════════════════════════════════════════"
echo " ✅ تم إلغاء تثبيت GT-salat-dikr بالكامل."
echo "════════════════════════════════════════════════════════"
