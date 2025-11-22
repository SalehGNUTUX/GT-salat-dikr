#!/bin/bash
#
# GT-salat-dikr Enhanced Installation Script (2025) - v3.1
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
TERMINAL_SALAT_NOTIFY=1
TERMINAL_ZIKR_NOTIFY=1
SYSTEM_SALAT_NOTIFY=1
SYSTEM_ZIKR_NOTIFY=1

echo ""
echo "📁 إنشاء مجلد التثبيت..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📁 إنشاء هيكل المجلدات الإضافية..."
mkdir -p "$INSTALL_DIR/monthly_timetables"

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
TERMINAL_SALAT_NOTIFY=$TERMINAL_SALAT_NOTIFY
TERMINAL_ZIKR_NOTIFY=$TERMINAL_ZIKR_NOTIFY
SYSTEM_SALAT_NOTIFY=$SYSTEM_SALAT_NOTIFY
SYSTEM_ZIKR_NOTIFY=$SYSTEM_ZIKR_NOTIFY
EOF

echo ""
echo "🚀 إعداد التشغيل التلقائي..."

if [ "$NOTIFY_SALAT_DIKR" = "systemd" ]; then
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

echo ""
echo "🔧 إعدادات الطرفية التلقائية..."
setup_terminal_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # التحقق إذا كانت الإعدادات موجودة مسبقاً
        if ! grep -q "gtsalat" "$shell_file" 2>/dev/null; then
            echo "" >> "$shell_file"
            echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$shell_file"
            echo "alias gtsalat='~/.local/bin/gtsalat'" >> "$shell_file"
            echo "echo ''" >> "$shell_file"
            echo "~/.local/bin/gtsalat" >> "$shell_file"
            echo "✅ تم إضافة إعدادات GT-salat-dikr إلى $shell_name"
        else
            echo "ℹ️  إعدادات GT-salat-dikr موجودة مسبقاً في $shell_name"
        fi
    else
        echo "⚠️  ملف $shell_name غير موجود، تخطي الإعدادات"
    fi
}

# إعدادات لأنواع الطرفيات المختلفة
setup_terminal_config "$HOME/.bashrc" "Bash"
setup_terminal_config "$HOME/.zshrc" "Zsh"
setup_terminal_config "$HOME/.bash_profile" "Bash Profile"

echo "✅ تم إعداد الطرفية لعرض الذكر وموعد الصلاة عند الافتتاح"

# هنا تفعيل إعدادات الموقع وطريقة الحساب مباشرة
echo ""
echo "⚙️ إعداد الموقع وطريقة حساب المواقيت..."
"$INSTALL_DIR/$MAIN_SCRIPT" --settings

# تحميل مواقيت الصلاة للأشهر القادمة
echo ""
echo "📥 جلب مواقيت الصلاة للأشهر القادمة للتخزين المحلي..."
"$INSTALL_DIR/$MAIN_SCRIPT" --update-timetables

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

# عرض الذكر وموعد الصلاة التالية (مثل السكربت الرئيسي)
echo ""
echo "📊 عرض المعلومات الحالية:"
echo "------------------------------------------------------------------"

# تشغيل السكربت الرئيسي بدون خيارات لعرض الذكر وموعد الصلاة
"$INSTALL_DIR/$MAIN_SCRIPT"

echo ""
echo "------------------------------------------------------------------"
echo ""
echo "💻 إعدادات الطرفية المضافة:"
echo "  - عند فتح أي طرفية، سيظهر تلقائياً:"
echo "    * ذكر عشوائي من الأذكار"
echo "    * موعد الصلاة القادمة والوقت المتبقي"
echo ""
echo "🔧 يمكنك التحكم بالبرنامج عبر:"
echo "  gtsalat                      عرض ذكر وموعد الصلاة التالية"
echo "  gtsalat --notify-start       بدء الإشعارات"
echo "  gtsalat --notify-stop        إيقاف الإشعارات"
echo "  gtsalat --status             عرض الحالة"
echo "  gtsalat --settings           تعديل الإعدادات"
echo "  gtsalat --show-timetable     عرض مواقيت الصلاة"
echo "  gtsalat --update-timetables  تحديث مواقيت الصلاة للأشهر القادمة"
echo ""
echo "🔄 الميزة الجديدة في الإصدار 3.1: التحديث التلقائي!"
echo "   - يمكن تفعيل التحديث التلقائي الأسبوعي"
echo "   - البرنامج سيتحقق تلقائياً من تحديثات مواقيت الصلاة"
echo "   - استخدم: gtsalat --enable-auto-update"
echo ""
echo "💾 الميزة الجديدة: التخزين المحلي لمواقيت الصلاة لعدة أشهر"
echo "   - يمكن للبرنامج العمل بدون اتصال بالإنترنت"
echo "   - يتم تخزين بيانات 3 أشهر مسبقاً"
echo ""
echo "للمساعدة: gtsalat --help"
