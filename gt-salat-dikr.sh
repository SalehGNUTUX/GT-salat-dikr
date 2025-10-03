#!/bin/bash
# ملف مؤقت لإصلاح المشكلة

INSTALL_DIR="$HOME/.GT-salat-dikr"

# إعادة تثبيت كامل
echo "🔧 إعادة التثبيت..."

# حذف النسخة المعطوبة
rm -rf "$INSTALL_DIR"

# إعادة إنشاء المجلد
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# تحميل الملفات
echo "→ تحميل الملفات..."
curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-salat-dikr.sh -o gt-salat-dikr.sh
curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/azkar.txt -o azkar.txt
curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/adhan.ogg -o adhan.ogg 2>/dev/null || true

# صلاحيات
chmod +x gt-salat-dikr.sh

# إنشاء الاختصار
ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat"

echo "✅ تم!"
echo "الآن شغّل: gtsalat --settings"
