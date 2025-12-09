#!/bin/bash
# تثبيت System Tray بشكل منفصل - يدعم التشغيل عن بعد ومحلياً

set -e  # إيقاف عند أي خطأ

echo "🖥️  إعداد System Tray لـ GT-salat-dikr..."

# تحديد مسار التثبيت
if [ -d "/opt/gt-salat-dikr" ]; then
    INSTALL_DIR="/opt/gt-salat-dikr"
elif [ -d "$HOME/.GT-salat-dikr" ]; then
    INSTALL_DIR="$HOME/.GT-salat-dikr"
else
    INSTALL_DIR="$HOME/.GT-salat-dikr"
    mkdir -p "$INSTALL_DIR"
fi

# إنشاء مسار ثانوي للأيقونات
ICON_DIR="$INSTALL_DIR/icons"
mkdir -p "$ICON_DIR"

# تشغيل script تبعيات Python أولاً
echo "📦 إعداد تبعيات Python..."
SCRIPT_DIR=$(dirname "$(realpath "$0")" 2>/dev/null || dirname "$(readlink -f "$0")" 2>/dev/null || echo ".")

# البحث عن script تبعيات Python
if [ -f "$SCRIPT_DIR/install-python-deps.sh" ]; then
    bash "$SCRIPT_DIR/install-python-deps.sh"
elif [ -f "./install-python-deps.sh" ]; then
    bash ./install-python-deps.sh
else
    # تحميل عن بعد إذا لم يوجد محلياً
    echo "⬇️  تحميل script تبعيات Python..."
    curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install-python-deps.sh" | bash
fi

# تحميل أو تحديث ملف System Tray
echo "⬇️  إعداد ملف System Tray..."
TRAY_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-tray.py"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TRAY_URL" -o "$INSTALL_DIR/gt-tray.py"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$TRAY_URL" -O "$INSTALL_DIR/gt-tray.py"
else
    echo "❌ يلزم تثبيت curl أو wget"
    exit 1
fi

chmod +x "$INSTALL_DIR/gt-tray.py"

# تحميل الأيقونات
echo "🖼️  تحميل الأيقونات..."
for size in 16 32 48 64 128 256; do
    ICON_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/icons/prayer-icon-${size}.png"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$ICON_URL" -o "$ICON_DIR/prayer-icon-${size}.png" 2>/dev/null || true
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$ICON_URL" -O "$ICON_DIR/prayer-icon-${size}.png" 2>/dev/null || true
    fi
done

# إنشاء رابط رمزي للاستخدام السهل
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/gt-tray.py" "$HOME/.local/bin/gt-tray" 2>/dev/null || true

# إضافة إلى PATH إذا لم يكن موجوداً
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

# إنشاء ملف تكوين تلقائي لـ System Tray
echo "⚙️  إنشاء إعدادات تلقائية..."
cat > "$INSTALL_DIR/tray-config.json" << EOF
{
    "auto_start": true,
    "notifications": true,
    "update_check": false,
    "icon_size": 32,
    "theme": "dark"
}
EOF

echo ""
echo "✅ تم إعداد System Tray بنجاح!"
echo ""
echo "🔧 الأوامر المتاحة:"
echo "   gt-tray              # تشغيل System Tray"
echo "   gtsalat --tray       # تشغيل System Tray من البرنامج"
echo "   gtsalat --tray-stop  # إيقاف System Tray"
echo ""
echo "📌 ملاحظة: سيتم تشغيل System Tray تلقائياً مع بدء الجلسة"
echo "🖱️  انقر بزر الماوس الأيمن على الأيقونة لعرض القائمة الكاملة"
