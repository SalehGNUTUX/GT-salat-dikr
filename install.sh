#!/bin/bash
#
# GT-salat-dikr Enhanced Installation Script (2025)
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
CONFIG_FILE="$INSTALL_DIR/settings.conf"

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

# الكشف التلقائي عن نظام الخدمة
if command -v systemctl >/dev/null 2>&1; then
    SYSTEMD_AVAILABLE=1
    NOTIFY_SYSTEM="systemd"
else
    SYSTEMD_AVAILABLE=0
    NOTIFY_SYSTEM="sysvinit"
fi

# إعدادات افتراضية (بدون أسئلة)
ENABLE_SALAT_NOTIFY=1
ENABLE_ZIKR_NOTIFY=1

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
echo "📝 حفظ الإعدادات الأولية..."
cat > "$CONFIG_FILE" <<EOF
ENABLE_SALAT_NOTIFY=$ENABLE_SALAT_NOTIFY
ENABLE_ZIKR_NOTIFY=$ENABLE_ZIKR_NOTIFY
NOTIFY_SYSTEM="$NOTIFY_SYSTEM"
EOF

echo ""
echo "🚀 إعداد التشغيل التلقائي..."

if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
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
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=$INSTALL_DIR/$MAIN_SCRIPT --notify-start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    echo "✅ تم تفعيل autostart بطريقة sysvinit"
fi

# هنا تفعيل إعدادات الموقع وطريقة الحساب مباشرة
echo ""
echo "⚙️ إعداد الموقع وطريقة حساب المواقيت..."
"$INSTALL_DIR/$MAIN_SCRIPT" --settings

# الآن بعد اكتمال الإعدادات، نسأل عن بدء الإشعارات
echo ""
echo "🔔 بدء الإشعارات الآن؟"
read -p "  [Y/n]: " START_NOTIFY
START_NOTIFY=${START_NOTIFY:-Y}
if [[ "$START_NOTIFY" =~ ^[Yy]$ ]]; then
    echo "🚀 بدء تشغيل الإشعارات..."
    
    # التحقق من وجود الإعدادات أولاً
    if [ -f "$CONFIG_FILE" ] && grep -q "LAT" "$CONFIG_FILE" 2>/dev/null; then
        if "$INSTALL_DIR/$MAIN_SCRIPT" --notify-start; then
            echo "✅ تم بدء تشغيل الإشعارات بنجاح!"
        else
            echo "⚠️  تعذر بدء الإشعارات تلقائياً"
            echo "   يمكنك تشغيلها يدوياً لاحقاً: gtsalat --notify-start"
        fi
    else
        echo "❌ لم تكتمل إعدادات الموقع بعد"
        echo "   الرجاء تشغيل الإعدادات أولاً: gtsalat --settings"
        echo "   ثم بدء الإشعارات: gtsalat --notify-start"
    fi
else
    echo "ℹ️  يمكنك بدء الإشعارات لاحقاً: gtsalat --notify-start"
fi

echo ""
echo "🎉 تم التثبيت بنجاح!"
echo "الإعدادات الحالية:"
echo "  إشعارات الصلاة: $([ "$ENABLE_SALAT_NOTIFY" = "1" ] && echo 'مفعلة' || echo 'معطلة')"
echo "  إشعارات الذكر: $([ "$ENABLE_ZIKR_NOTIFY" = "1" ] && echo 'مفعلة' || echo 'معطلة')"
echo "  نظام الخدمة: $NOTIFY_SYSTEM"
echo ""
echo "💡 يمكنك التحكم بالبرنامج عبر:"
echo "  gtsalat --notify-start        بدء الإشعارات"
echo "  gtsalat --notify-stop         إيقاف الإشعارات"
echo "  gtsalat --status              عرض الحالة"
echo "  gtsalat --settings            تعديل الإعدادات"
echo "  gtsalat --show-timetable      عرض مواقيت الصلاة"
echo ""
echo "للمساعدة: gtsalat --help"
