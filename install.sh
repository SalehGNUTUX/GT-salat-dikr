#!/bin/bash
#
# GT-salat-dikr Simplified Installation Script (2024)
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root، استخدم حساب المستخدم العادي."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
MAIN_SCRIPT="gt-salat-dikr.sh"

echo "🔍 فحص المتطلبات..."
MISSING_TOOLS=()
for tool in curl jq notify-send; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done
if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "❌ الأدوات الناقصة: ${MISSING_TOOLS[*]}"
    echo "يرجى تثبيت الأدوات الناقصة قبل متابعة التثبيت."
    exit 1
fi

echo ""
echo "📁 إنشاء مجلد التثبيت..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "⬇️  تحميل الملفات الأساسية..."
for file in "$MAIN_SCRIPT" "install.sh" "uninstall.sh" "azkar.txt" "adhan.ogg" "short_adhan.ogg" "prayer_approaching.ogg"; do
    echo "  تحميل: $file"
    curl -fsSL "$REPO_BASE/$file" -o "$file" || echo "  ⚠️ لم يتم تحميل $file"
done
chmod +x "$MAIN_SCRIPT" install.sh uninstall.sh

echo "🔗 إعداد المسار..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat"

echo ""
echo "🚀 إعداد التشغيل التلقائي..."

# الكشف التلقائي عن نظام الخدمة المتاح
if command -v systemctl >/dev/null 2>&1 && systemctl --user --quiet is-active dbus 2>/dev/null; then
    echo "  ↳ استخدام systemd للتشغيل التلقائي"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Times and Azkar Notifications
After=graphical-session.target default.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$MAIN_SCRIPT --child-notify
Restart=always
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="DISPLAY=:0"
Environment="XDG_RUNTIME_DIR=/run/user/%U"

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable gt-salat-dikr.service
    echo "✅ تم تفعيل خدمة systemd"
else
    echo "  ↳ استخدام autostart للتشغيل التلقائي"
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=$INSTALL_DIR/$MAIN_SCRIPT --child-notify
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    echo "✅ تم تفعيل autostart"
fi

echo ""
echo "🎉 تم التثبيت بنجاح!"
echo ""
echo "سيتم الآن فتح إعدادات البرنامج لإكمال الإعداد:"
echo "------------------------------------------------------------------"

# استدعاء إعدادات البرنامج مباشرة مع منع التكرار
echo "اضغط على [Enter] لبدء الإعدادات..."
read -p ""

# استخدام exec لاستبدال العملية الحالية بدلاً من إنشاء عملية جديدة
exec "$HOME/.local/bin/gtsalat" --settings

# هذا السطر لن يتم تنفيذه أبداً بسبب exec
echo ""
echo "✨ تم إكمال التثبيت والإعداد!"
echo "يمكنك تعديل الإعدادات لاحقًا عبر الأمر: gtsalat --settings"
echo "للمساعدة وعرض جميع الأوامر: gtsalat --help"
