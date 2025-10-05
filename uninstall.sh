#!/bin/bash
#
# GT-salat-dikr Uninstall Script
# إزالة كاملة للنظام وإعداداته
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  إزالة تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من الصلاحيات
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  تحذير: لا تشغل هذا السكربت بصلاحيات root"
    echo "   استخدم حساب المستخدم العادي."
    exit 1
fi

# المتغيرات
INSTALL_DIR="$HOME/.GT-salat-dikr"

# طلب التأكيد
echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل:"
echo "   - مجلد التثبيت ($INSTALL_DIR)"
echo "   - الاختصارات والروابط"
echo "   - إعدادات البدء التلقائي"
echo "   - خدمات systemd"
echo "   - الإعدادات المحفوظة"
echo ""

read -p "هل أنت متأكد من أنك تريد المتابعة؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🗑️  جاري إزالة التثبيت..."

# 1. إيقاف الخدمات والإشعارات النشطة
echo "  → إيقاف الخدمات النشطة..."
if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
    "$INSTALL_DIR/gt-salat-dikr.sh" --notify-stop 2>/dev/null || true
fi

# 2. إيقاف وإزالة خدمة systemd
echo "  → إزالة خدمة systemd..."
if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
    systemctl --user stop gt-salat-dikr.service
    systemctl --user disable gt-salat-dikr.service
fi
rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true

# 3. إزالة ملف autostart
echo "  → إزالة بدء التشغيل التلقائي..."
rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true

# 4. إزالة الاختصارات
echo "  → إزالة الاختصارات..."
rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
rm -f "$HOME/.local/bin/gt-salat-dikr" 2>/dev/null || true

# 5. إزالة الإضافات من ملفات shell
echo "  → تنظيف ملفات shell..."
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rc_file" ]; then
        # إزالة إضافة PATH لـ .local/bin (إذا كانت من تثبيتنا فقط)
        if grep -q '# Added by GT-salat-dikr' "$rc_file" 2>/dev/null; then
            sed -i '/# Added by GT-salat-dikr/d' "$rc_file"
            sed -i '/export PATH="$HOME\/.local\/bin:$PATH"/d' "$rc_file"
        fi
        
        # إزالة استدعاء GT-salat-dikr
        if grep -q 'GT-salat-dikr' "$rc_file"; then
            sed -i '/GT-salat-dikr/d' "$rc_file"
        fi
    fi
done

# 6. إزالة مجلد التثبيت
echo "  → إزالة ملفات البرنامج..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "     ✓ تم حذف $INSTALL_DIR"
else
    echo "     ⓘ مجلد التثبيت غير موجود"
fi

# 7. تنظيف ملفات التكوين المتبقية
echo "  → تنظيف ملفات التكوين..."
rm -f "$HOME/.config/gt-salat-dikr" 2>/dev/null || true
rm -f "$HOME/.gt-salat-dikr" 2>/dev/null || true

# 8. تنظيف ملفات السجل
echo "  → تنظيف ملفات السجل..."
rm -f "/tmp/gt-salat-dikr-*.log" 2>/dev/null || true
rm -f "/tmp/gt-salat-dikr.pid" 2>/dev/null || true

echo ""
echo "✅ تمت الإزالة بنجاح!"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  تم إزالة:"
echo "════════════════════════════════════════════════════════"
echo ""
echo "✓ ملفات البرنامج ($INSTALL_DIR)"
echo "✓ الاختصارات (gtsalat)"
echo "✓ بدء التشغيل التلقائي"
echo "✓ خدمة systemd"
echo "✓ الإعدادات من ملفات shell"
echo "✓ ملفات التكوين المؤقتة"
echo ""
echo "💡 ملاحظة: تم الاحتفاظ بإعداداتك الشخصية في:"
echo "   $HOME/.config/gt-salat-dikr/settings.conf (إن وجدت)"
echo ""
echo "🔁 لإعادة التثبيت لاحقاً:"
echo "   bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
echo "════════════════════════════════════════════════════════"
