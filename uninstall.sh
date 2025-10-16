#!/bin/bash
#
# GT-salat-dikr Uninstall Script (2024)
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

echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل."
read -p "هل أنت متأكد؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🛑 إيقاف جميع الخدمات والإشعارات..."

# إيقاف جميع عمليات البرنامج
pkill -f "gt-salat-dikr" 2>/dev/null || true
pkill -f "adhan-player" 2>/dev/null || true
pkill -f "approaching-player" 2>/dev/null || true

# إزالة خدمات systemd
if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
    systemctl --user stop gt-salat-dikr.service
    systemctl --user disable gt-salat-dikr.service
    echo "✅ تم إيقاف خدمة systemd."
fi
rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service"
systemctl --user daemon-reload 2>/dev/null || true

# إزالة autostart
rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop"

# إزالة الملفات المؤقتة وبيانات التشغيل
rm -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null
rm -f "$INSTALL_DIR/.last-prayer-notified" 2>/dev/null
rm -f "$INSTALL_DIR/.last-preprayer-notified" 2>/dev/null
rm -f "$INSTALL_DIR/notify.log" 2>/dev/null
rm -f "$INSTALL_DIR/timetable.json" 2>/dev/null

# إزالة الملفات التنفيذية
rm -f "$INSTALL_DIR/adhan-player.sh" 2>/dev/null
rm -f "$INSTALL_DIR/approaching-player.sh" 2>/dev/null

# إزالة الرابط الرمزي
rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null

echo "✅ تم إيقاف جميع الخدمات والإشعارات."

echo ""
echo "📁 اختيار ملفات الإبقاء:"
echo "1) حذف كل شيء بما فيهم ملفات التثبيت والإزالة"
echo "2) الإبقاء على ملفات التثبيت والإزالة فقط (موصى به)"
read -p "اختر الخيار [2]: " keep_choice
keep_choice=${keep_choice:-2}

if [ "$keep_choice" = "1" ]; then
    echo "🗑️  حذف جميع الملفات..."
    rm -rf "$INSTALL_DIR"
    echo "✅ تم حذف مجلد التثبيت بالكامل."
else
    echo "💾 الإبقاء على ملفات التثبيت الأساسية..."
    
    # حذف جميع الملفات ما عدا الأساسية
    cd "$INSTALL_DIR"
    find . -maxdepth 1 -type f ! -name "install.sh" ! -name "uninstall.sh" ! -name "*.ogg" -exec rm -f {} \; 2>/dev/null || true
    rm -f "$INSTALL_DIR/gt-salat-dikr.sh" 2>/dev/null
    rm -f "$INSTALL_DIR/azkar.txt" 2>/dev/null
    rm -f "$INSTALL_DIR/settings.conf" 2>/dev/null
    
    echo "✅ تم حذف ملفات التشغيل مع الإبقاء على ملفات التثبيت."
fi

# تنظيف ملفات النظام المؤقتة
rm -f "/tmp/gt-adhan-player-"* 2>/dev/null || true
rm -f "/tmp/gt-approaching-"* 2>/dev/null || true

echo ""
echo "🔍 التحقق من الإزالة النهائية..."

# التحقق من عدم وجود عمليات نشطة
if pgrep -f "gt-salat-dikr" >/dev/null 2>&1; then
    echo "⚠️  لا يزال هناك عمليات نشطة، جاري إجبار الإيقاف..."
    pkill -9 -f "gt-salat-dikr" 2>/dev/null || true
    sleep 1
fi

# التحقق من الإزالة
if [ "$keep_choice" = "1" ] && [ -d "$INSTALL_DIR" ]; then
    echo "❌ فشل في حذف مجلد التثبيت."
else
    echo "✅ تمت الإزالة بنجاح."
fi

if [ -f "$HOME/.local/bin/gtsalat" ]; then
    echo "❌ فشل في إزالة الرابط الرمزي."
else
    echo "✅ تم إزالة الرابط الرمزي."
fi

echo ""
echo "💡 ملاحظات:"
if [ "$keep_choice" = "2" ] && [ -d "$INSTALL_DIR" ]; then
    echo "   - تم الإبقاء على ملفات التثبيت في: $INSTALL_DIR"
    echo "   - يمكنك إعادة التثبيت لاحقًا عن طريق: bash $INSTALL_DIR/install.sh"
else
    echo "   - يمكنك إعادة التثبيت لاحقًا عن طريق:"
    echo "     bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
fi

echo ""
echo "🎉 تمت إزالة التثبيت بالكامل!"
