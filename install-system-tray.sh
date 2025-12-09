#!/bin/bash
# تثبيت System Tray بشكل منفصل

echo "🖥️  تثبيت System Tray لـ GT-salat-dikr..."

INSTALL_DIR="$HOME/.GT-salat-dikr"

# التحقق من Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "📦 تثبيت Python3..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y python3 python3-pip
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python python-pip
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip
    fi
fi

# تثبيت المكتبات
echo "📦 تثبيت مكتبات Python..."
if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y python3-pystray python3-pil
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm python-pystray python-pillow
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3-pystray python3-pillow
else
    pip3 install --user pystray pillow
fi

# تحميل ملف System Tray إذا لم يكن موجوداً
if [ ! -f "$INSTALL_DIR/gt-tray.py" ]; then
    echo "⬇️  تحميل ملف System Tray..."
    curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-tray.py" \
        -o "$INSTALL_DIR/gt-tray.py"
    chmod +x "$INSTALL_DIR/gt-tray.py"
fi

# تحميل الأيقونات
mkdir -p "$INSTALL_DIR/icons"
echo "🖼️  تحميل الأيقونات..."
for size in 32 64 128; do
    curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/icons/prayer-icon-${size}.png" \
        -o "$INSTALL_DIR/icons/prayer-icon-${size}.png" 2>/dev/null || true
done

# إنشاء رابط للاستخدام السهل
ln -sf "$INSTALL_DIR/gt-tray.py" "$HOME/.local/bin/gt-tray" 2>/dev/null || true

echo ""
echo "✅ تم التثبيت!"
echo ""
echo "🔧 الأوامر المتاحة:"
echo "   gt-tray              # تشغيل System Tray"
echo "   gtsalat --tray       # تشغيل System Tray من البرنامج"
echo "   gtsalat --tray-stop  # إيقاف System Tray"
echo ""
echo "📌 ستظهر الأيقونة في شريط المهام بجانب الساعة"
echo "🖱️  انقر بزر الماوس الأيمن لعرض القائمة الكاملة"
