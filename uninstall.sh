#!/bin/bash
# uninstall.sh - إزالة كاملة ونظيفة لـ GT-salat-dikr
# يعمل بدون صلاحيات root في معظم الحالات

set -e

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════╗
║         إزالة GT-salat-dikr             ║
╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo "هذا السكريبت سيزيل GT-salat-dikr بشكل كامل."
echo ""

# طلب التأكيد
read -p "هل تريد الاستمرار في الإزالة؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "بدء عملية الإزالة..."
echo "══════════════════════════════════════════════════"

# ---------- المرحلة 1: إيقاف جميع العمليات ----------
echo ""
echo "1. إيقاف جميع عمليات البرنامج..."

# قتل عمليات النظام
pkill -f "gt-tray.py" 2>/dev/null || true
pkill -f "python.*tray" 2>/dev/null || true
pkill -f "gt-salat-dikr" 2>/dev/null || true
pkill -f "gtsalat" 2>/dev/null || true

sleep 2

# ---------- المرحلة 2: إزالة الأوامر ----------
echo ""
echo "2. إزالة الأوامر..."

# إزالة الأوامر من النظام (إذا كانت بصلاحيات root)
if [ -f "/usr/local/bin/gtsalat" ]; then
    echo "  إزالة /usr/local/bin/gtsalat"
    sudo rm -f "/usr/local/bin/gtsalat" 2>/dev/null || true
fi

if [ -f "/usr/bin/gtsalat" ]; then
    echo "  إزالة /usr/bin/gtsalat"
    sudo rm -f "/usr/bin/gtsalat" 2>/dev/null || true
fi

# إزالة الأوامر من مجلد المستخدم
USER_COMMANDS=(
    "$HOME/.local/bin/gtsalat"
    "$HOME/.local/bin/gt-tray"
    "$HOME/.local/bin/gt-launcher"
    "$HOME/.local/bin/gt-salat-launcher"
)

for cmd in "${USER_COMMANDS[@]}"; do
    if [ -f "$cmd" ] || [ -L "$cmd" ]; then
        echo "  إزالة $cmd"
        rm -f "$cmd" 2>/dev/null || true
    fi
done

# ---------- المرحلة 3: إزالة ملفات النظام ----------
echo ""
echo "3. إزالة ملفات النظام..."

# إزالة ملفات systemd
if [ -f "/etc/systemd/system/gt-salat-dikr.service" ]; then
    echo "  إزالة خدمة systemd"
    sudo systemctl stop gt-salat-dikr.service 2>/dev/null || true
    sudo systemctl disable gt-salat-dikr.service 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/gt-salat-dikr.service" 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# إزالة init scripts
if [ -f "/etc/init.d/gt-salat-dikr" ]; then
    echo "  إزالة init script"
    sudo /etc/init.d/gt-salat-dikr stop 2>/dev/null || true
    sudo rm -f "/etc/init.d/gt-salat-dikr" 2>/dev/null || true
fi

# ---------- المرحلة 4: إزالة مهام cron ----------
echo ""
echo "4. إزالة مهام cron..."

if command -v crontab >/dev/null 2>&1; then
    # إزالة من crontab الخاص بالمستخدم
    if crontab -l 2>/dev/null | grep -q "gt-salat-dikr\|gtsalat"; then
        echo "  إزالة مهام cron"
        crontab -l 2>/dev/null | grep -v "gt-salat-dikr\|gtsalat" | crontab - 2>/dev/null || true
    fi
fi

# ---------- المرحلة 5: إزالة ملفات بدء التشغيل ----------
echo ""
echo "5. إزالة ملفات بدء التشغيل..."

AUTOSTART_FILES=(
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/autostart/gt-salat-dikr-autostart.desktop"
)

for file in "${AUTOSTART_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  إزالة $file"
        rm -f "$file" 2>/dev/null || true
    fi
done

# إزالة ملفات KDE
if [ -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" ]; then
    echo "  إزالة ملف KDE autostart"
    rm -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" 2>/dev/null || true
fi

# ---------- المرحلة 6: إزالة الملفات الرئيسية ----------
echo ""
echo "6. إزالة الملفات الرئيسية..."

# قائمة المجلدات للحذف
INSTALL_DIRS=(
    "$HOME/.GT-salat-dikr"
    "$HOME/GT-salat-dikr"
    "/opt/gt-salat-dikr"
)

CONFIG_DIRS=(
    "$HOME/.config/gt-salat-dikr"
    "$HOME/.gt-salat-dikr"
    "$HOME/.cache/gt-salat-dikr"
)

# حذف مجلدات التثبيت
for dir in "${INSTALL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  حذف مجلد: $dir"
        # لا تحذف المجلد الذي يحتوي على سكريبت الإزالة نفسه
        if [[ "$dir" == "$(dirname "$(realpath "$0")" 2>/dev/null || echo "")" ]]; then
            echo "    (تم تخطي المجلد الحالي لحفظ سكريبت الإزالة)"
        else
            rm -rf "$dir" 2>/dev/null || sudo rm -rf "$dir" 2>/dev/null || true
        fi
    fi
done

# حذف مجلدات التكوين
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  حذف إعدادات: $dir"
        rm -rf "$dir" 2>/dev/null || true
    fi
done

# ---------- المرحلة 7: إزالة أيقونات القائمة ----------
echo ""
echo "7. إزالة أيقونات القائمة..."

DESKTOP_FILES=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
    "/usr/share/applications/gt-salat-dikr.desktop"
    "/usr/local/share/applications/gt-salat-dikr.desktop"
)

for desktop_file in "${DESKTOP_FILES[@]}"; do
    if [ -f "$desktop_file" ]; then
        echo "  إزالة $desktop_file"
        rm -f "$desktop_file" 2>/dev/null || sudo rm -f "$desktop_file" 2>/dev/null || true
    fi
done

# تحديث قاعدة بيانات التطبيقات
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# ---------- المرحلة 8: تنظيف ملفات التهيئة ----------
echo ""
echo "8. تنظيف ملفات التهيئة..."

# إزالة من .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if grep -q "GT-salat-dikr\|gtsalat" "$HOME/.bashrc" 2>/dev/null; then
        echo "  تنظيف .bashrc"
        grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|gt-launcher" "$HOME/.bashrc" > "$HOME/.bashrc.tmp" 2>/dev/null && \
        mv "$HOME/.bashrc.tmp" "$HOME/.bashrc" 2>/dev/null || true
    fi
fi

# إزالة من .zshrc
if [ -f "$HOME/.zshrc" ]; then
    if grep -q "GT-salat-dikr\|gtsalat" "$HOME/.zshrc" 2>/dev/null; then
        echo "  تنظيف .zshrc"
        grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|gt-launcher" "$HOME/.zshrc" > "$HOME/.zshrc.tmp" 2>/dev/null && \
        mv "$HOME/.zshrc.tmp" "$HOME/.zshrc" 2>/dev/null || true
    fi
fi

# إزالة من fish config
if [ -f "$HOME/.config/fish/config.fish" ]; then
    if grep -q "GT-salat-dikr\|gtsalat" "$HOME/.config/fish/config.fish" 2>/dev/null; then
        echo "  تنظيف fish config"
        grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|gt-launcher" "$HOME/.config/fish/config.fish" > "$HOME/.config/fish/config.fish.tmp" 2>/dev/null && \
        mv "$HOME/.config/fish/config.fish.tmp" "$HOME/.config/fish/config.fish" 2>/dev/null || true
    fi
fi

# ---------- المرحلة 9: تنظيف الملفات المؤقتة ----------
echo ""
echo "9. تنظيف الملفات المؤقتة..."

# حذف ملفات PID
rm -f /tmp/gt-*.pid 2>/dev/null || true
rm -f /tmp/gt-*.lock 2>/dev/null || true
rm -f /tmp/gt-salat-* 2>/dev/null || true

# حذف سجلات البرنامج
rm -f /var/log/gt-salat-*.log 2>/dev/null || true

# ---------- المرحلة 10: التحقق النهائي ----------
echo ""
echo "10. التحقق النهائي..."

REMAINING_FILES=()

# التحقق من الملفات المتبقية
CHECK_PATHS=(
    "$HOME/.GT-salat-dikr"
    "$HOME/.local/bin/gtsalat"
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "/usr/local/bin/gtsalat"
)

for path in "${CHECK_PATHS[@]}"; do
    if [ -e "$path" ]; then
        REMAINING_FILES+=("$path")
    fi
done

echo ""
echo "══════════════════════════════════════════════════"
echo ""

if [ ${#REMAINING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ تمت الإزالة الكاملة بنجاح!${NC}"
    echo ""
    echo "تم حذف:"
    echo "• جميع ملفات البرنامج"
    echo "• جميع الأوامر والروابط"
    echo "• جميع إعدادات بدء التشغيل"
    echo "• جميع الإعدادات والسجلات"
    echo "• جميع أيقونات القائمة"
else
    echo -e "${YELLOW}⚠️  بعض الملفات لا تزال موجودة:${NC}"
    for file in "${REMAINING_FILES[@]}"; do
        echo "  • $file"
    done
    echo ""
    echo "يمكنك حذفها يدوياً."
fi

# إزالة مكتبات Python (اختياري)
echo ""
read -p "هل تريد إزالة مكتبات Python أيضاً؟ [y/N]: " remove_python
if [[ "$remove_python" =~ ^[Yy]$ ]]; then
    echo "إزالة مكتبات Python..."
    python3 -m pip uninstall -y pystray pillow 2>/dev/null || true
    echo "✅ تمت إزالة مكتبات Python"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo ""
echo "شكراً لك على استخدام GT-salat-dikr!"
echo ""
echo "لإعادة التثبيت في أي وقت:"
echo "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
echo "مع السلامة! 👋"

# إزالة هذا الملف نفسه فقط إذا كان العملية ناجحة وتم الرد على السؤال
# لا تحذف الملف أثناء تشغيله
if [[ -n "$remove_python" && "$(dirname "$(realpath "$0")" 2>/dev/null || echo "")" == *"GT-salat-dikr"* ]]; then
    echo ""
    echo "إزالة سكريبت الإزالة نفسه..."
    SCRIPT_PATH="$(realpath "$0")"
    rm -f "$SCRIPT_PATH" 2>/dev/null || true
fi

exit 0
