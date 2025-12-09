#!/bin/bash
#
# GT-salat-dikr - Uninstall Script
# إزالة كاملة لنظام إشعارات الصلاة والأذكار
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  إزالة GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# منع التشغيل بصلاحيات root
if [ "$EUID" -eq 0 ]; then
    echo "❌ لا تشغل هذا السكربت بصلاحيات root، استخدم حساب المستخدم العادي."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
INSTALL_DIR_ALT="$HOME/GT-salat-dikr"  # المسار البديل القديم

# ---------- المرحلة 1: إيقاف جميع الخدمات ----------
echo "⏸️  إيقاف جميع الخدمات والإشعارات..."

# إيقاف System Tray
echo "  إيقاف System Tray..."
pkill -f "gt-tray.py" 2>/dev/null || true
pkill -f "pystray" 2>/dev/null || true

# إيقاف إشعارات الخلفية
echo "  إيقاف إشعارات الخلفية..."
if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
    "$INSTALL_DIR/gt-salat-dikr.sh" --notify-stop 2>/dev/null || true
fi

# إيقاف خدمات systemd
echo "  إيقاف خدمات systemd..."
if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
    systemctl --user stop gt-salat-dikr.service 2>/dev/null || true
    systemctl --user disable gt-salat-dikr.service 2>/dev/null || true
    echo "  ✅ تم إيقاف خدمة systemd"
fi

# إزالة ملف PID
rm -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null || true

# ---------- المرحلة 2: إزالة الملفات التنفيذية ----------
echo ""
echo "🗑️  إزالة الملفات التنفيذية..."

# إزالة الروابط
echo "  إزالة روابط الأوامر..."
rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
rm -f "$HOME/.local/bin/gt-tray" 2>/dev/null || true
rm -f "$HOME/bin/gtsalat" 2>/dev/null || true

# إزالة ملفات التثبيت
echo "  إزالة ملفات البرنامج..."
if [ -d "$INSTALL_DIR" ]; then
    echo "  📁 حذف مجلد التثبيت: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR_ALT" ]; then
    echo "  📁 حذف المجلد البديل: $INSTALL_DIR_ALT"
    rm -rf "$INSTALL_DIR_ALT"
fi

# ---------- المرحلة 3: إزالة خدمات النظام ----------
echo ""
echo "🔧 إزالة خدمات النظام..."

# إزالة خدمة systemd
if [ -f "$HOME/.config/systemd/user/gt-salat-dikr.service" ]; then
    echo "  إزالة خدمة systemd..."
    rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
fi

# إزالة autostart
if [ -f "$HOME/.config/autostart/gt-salat-dikr.desktop" ]; then
    echo "  إزالة autostart..."
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true
fi

# إزالة أي ملفات desktop أخرى
find "$HOME/.local/share/applications" -name "*gt-salat*" -delete 2>/dev/null || true
find "$HOME/.local/share/applications" -name "*salat*" -delete 2>/dev/null || true

# ---------- المرحلة 4: تنظيف إعدادات الطرفية ----------
echo ""
echo "💻 تنظيف إعدادات الطرفية..."

clean_shell_config() {
    local shell_file="$1"
    local shell_name="$2"

    if [ -f "$shell_file" ]; then
        echo "  تنظيف $shell_name..."

        # إنشاء نسخة احتياطية
        cp "$shell_file" "${shell_file}.backup.gtsalat" 2>/dev/null || true

        # إزالة إعدادات GT-salat-dikr
        grep -v "GT-salat-dikr" "$shell_file" > "${shell_file}.temp" 2>/dev/null && \
            mv "${shell_file}.temp" "$shell_file" 2>/dev/null || true

        # إزالة الأوامر المحددة
        sed -i '/gtsalat/d' "$shell_file" 2>/dev/null || true
        sed -i '/GT-salat-dikr/d' "$shell_file" 2>/dev/null || true
        sed -i '/\.GT-salat-dikr/d' "$shell_file" 2>/dev/null || true

        echo "  ✅ تم تنظيف $shell_name"
    fi
}

# تنظيف ملفات التهيئة
clean_shell_config "$HOME/.bashrc" "Bash"
clean_shell_config "$HOME/.bash_profile" "Bash Profile"
clean_shell_config "$HOME/.zshrc" "Zsh"
clean_shell_config "$HOME/.profile" "Profile"

# ---------- المرحلة 5: إزالة ملفات السجل والبيانات ----------
echo ""
echo "📊 إزالة ملفات السجل والبيانات..."

# إزالة ملفات السجل
echo "  إزالة ملفات السجل..."
rm -f "$HOME/.gt-salat-dikr.log" 2>/dev/null || true
rm -f "$HOME/gt-salat-dikr.log" 2>/dev/null || true
rm -f "/tmp/gt-salat-*.log" 2>/dev/null || true
rm -f "/tmp/gt-tray-*.log" 2>/dev/null || true

# إزالة ملفات التكوين
echo "  إزالة ملفات التكوين..."
rm -f "$HOME/.config/gt-salat-dikr.conf" 2>/dev/null || true
rm -f "$HOME/.gt-salat-dikr.conf" 2>/dev/null || true

# إزالة ملفات مؤقتة
echo "  إزالة الملفات المؤقتة..."
rm -f "/tmp/gt-*.pid" 2>/dev/null || true
rm -f "/tmp/gt-salat-*" 2>/dev/null || true
rm -f "/tmp/gt-tray-*" 2>/dev/null || true
rm -f "/tmp/*.gt-salat*" 2>/dev/null || true

# ---------- المرحلة 6: تنظيف حزم Python (اختياري) ----------
echo ""
echo "🐍 تنظيف حزم Python (اختياري)..."

read -p "هل تريد إزالة حزم Python المثبتة للبرنامج؟ [y/N]: " remove_python
remove_python=${remove_python:-N}

if [[ "$remove_python" =~ ^[Yy]$ ]]; then
    echo "  إزالة حزم Python..."

    # إزالة باستخدام pip
    if command -v pip3 >/dev/null 2>&1; then
        pip3 uninstall -y pystray pillow 2>/dev/null || true
    fi

    if command -v pip >/dev/null 2>&1; then
        pip uninstall -y pystray pillow 2>/dev/null || true
    fi

    echo "  ✅ تم إزالة حزم Python"
else
    echo "  ⏭️  تخطي إزالة حزم Python"
fi

# ---------- المرحلة 7: التحقق النهائي ----------
echo ""
echo "🔍 التحقق النهائي..."

# التحقق من بقايا الملفات
REMAINING_FILES=0

echo "  البحث عن الملفات المتبقية..."

# البحث في المسارات الشائعة
SEARCH_PATHS=(
    "$HOME/.GT-salat-dikr"
    "$HOME/GT-salat-dikr"
    "$HOME/.local/bin/gtsalat"
    "$HOME/.local/bin/gt-tray"
    "$HOME/.config/systemd/user/gt-salat-dikr.service"
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -e "$path" ]; then
        echo "  ⚠️  يوجد ملف متبقي: $path"
        REMAINING_FILES=1
    fi
done

# التحقق من العمليات النشطة
if pgrep -f "gt-salat" >/dev/null 2>&1 || \
   pgrep -f "gt-tray" >/dev/null 2>&1 || \
   pgrep -f "pystray" >/dev/null 2>&1; then
    echo "  ⚠️  توجد عمليات نشطة للبرنامج"
    echo "  📌 يمكنك إعادة تشغيل الجهاز للتأكد من إزالة كل شيء"
    REMAINING_FILES=1
fi

if [ $REMAINING_FILES -eq 0 ]; then
    echo "✅ لم يتم العثور على ملفات متبقية"
else
    echo "⚠️  توجد بعض الملفات المتبقية، يمكنك حذفها يدوياً"
fi

# ---------- المرحلة 8: إعادة تعيين الأوامر ----------
echo ""
echo "🔄 إعادة تعيين جلسة الطرفية..."

echo "  🔄 إعادة تحميل ملفات التهيئة..."
# إعادة تحميل bashrc
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc" 2>/dev/null || true
fi

# إعادة تحميل zshrc
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc" 2>/dev/null || true
fi

# ---------- المرحلة 9: الرسالة النهائية ----------
echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 تم إزالة GT-salat-dikr بنجاح!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 ملخص الإزالة:"
echo "════════════════════════════════════════════════════════"
echo "✅ تم إيقاف جميع الخدمات والإشعارات"
echo "✅ تم إزالة الملفات التنفيذية والروابط"
echo "✅ تم إزالة خدمات النظام (systemd/autostart)"
echo "✅ تم تنظيف إعدادات الطرفية"
echo "✅ تم إزالة ملفات السجل والبيانات"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📝 ملاحظات مهمة:"
echo "════════════════════════════════════════════════════════"
echo "• تم إنشاء نسخ احتياطية لملفات التهيئة:"
echo "  *.backup.gtsalat"
echo ""
echo "• إذا أردت إعادة التثبيت:"
echo "  قم بتنزيل install.sh وتشغيله"
echo ""
echo "• لاستعادة إعدادات الطرفية الأصلية:"
echo "  يمكنك استعادة الملفات من النسخة الاحتياطية"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🔧 للحصول على مساعدة إضافية أو الإبلاغ عن مشاكل:"
echo "   https://github.com/SalehGNUTUX/GT-salat-dikr"
echo "════════════════════════════════════════════════════════"

# إظهار رسالة وداع
echo ""
echo "🕌 شكراً لاستخدامك GT-salat-dikr"
echo "📅 نتمنى لك أوقاتاً مليئة بالذكر والصلاة"
echo "👋 إلى اللقاء في تحديثات قادمة إن شاء الله"
