#!/bin/bash
#
# GT-salat-dikr Quick Fix Script
# لإصلاح المشاكل الحالية
#

echo "🔧 إصلاح GT-salat-dikr..."

# إيقاف أي عمليات قيد التشغيل
echo "→ إيقاف العمليات النشطة..."
pkill -f gt-salat-dikr 2>/dev/null || true

# حذف الملفات المعطوبة
echo "→ تنظيف الملفات المعطوبة..."
rm -f ~/.GT-salat-dikr/.gt-salat-dikr-notify.pid
rm -f ~/.GT-salat-dikr/notify.log

# إعادة تحميل السكربت الأساسي
echo "→ تحميل نسخة محدثة..."
cd ~/.GT-salat-dikr

# تحميل السكربت الأصلي (الآن مع الإصلاحات)
curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh -o gt-salat-dikr.sh.new

if [ -f gt-salat-dikr.sh.new ]; then
    # التحقق من أن الملف صحيح
    if bash -n gt-salat-dikr.sh.new 2>/dev/null; then
        mv gt-salat-dikr.sh.new gt-salat-dikr.sh
        chmod +x gt-salat-dikr.sh
        echo "✅ تم تحديث السكربت بنجاح"
    else
        echo "❌ السكربت المحمل يحتوي على أخطاء"
        rm -f gt-salat-dikr.sh.new
        exit 1
    fi
else
    echo "❌ فشل تحميل السكربت"
    exit 1
fi

# اختبار السكربت
echo ""
echo "→ اختبار السكربت..."
if ./gt-salat-dikr.sh --help >/dev/null 2>&1; then
    echo "✅ السكربت يعمل بشكل صحيح"
else
    echo "❌ السكربت لا يزال يحتوي على مشاكل"
    exit 1
fi

echo ""
echo "✅ تم الإصلاح بنجاح!"
echo ""
echo "الخطوات التالية:"
echo "1. gtsalat --settings   # لإعداد الموقع"
echo "2. gtsalat --notify-start  # لبدء الإشعارات"
echo "3. gtsalat --status     # للتحقق من الحالة"
