#!/bin/bash
# uninstall.sh - إزالة كاملة ونظيفة لـ GT-salat-dikr
# يعمل بدون صلاحيات root في معظم الحالات

# إصلاح: نسخ الملف إلى مكان مؤقت أولاً
TEMP_UNINSTALL="/tmp/gt-uninstall-$$.sh"
cat "$0" > "$TEMP_UNINSTALL"
chmod +x "$TEMP_UNINSTALL"
exec "$TEMP_UNINSTALL" "$@"

# -----------------------------------------------------------------
# بداية الكود الفعلي (سيتم تنفيذه من الملف المؤقت)
# -----------------------------------------------------------------

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
    # حذف الملف المؤقت قبل الخروج
    rm -f "/tmp/gt-uninstall-"*.sh 2>/dev/null || true
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
        # لا نحاول حذف الملف المؤقت نفسه
        if [[ "$dir" != "/tmp/gt-uninstall-"* ]]; then
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

# ---------- المرحلة 8: تنظيف ملفات التهيئة (الطريقة المحسنة) ----------
echo ""
echo "8. تنظيف ملفات التهيئة..."

clean_shell_file_safe() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ ! -f "$shell_file" ]; then
        return
    fi
    
    echo "  تنظيف $shell_name..."
    
    # إنشاء ملف مؤقت
    TEMP_FILE=$(mktemp)
    
    # تنظيف الملف بطريقة آمنة
    awk '
    BEGIN { 
        in_gt_block = 0
        if_count = 0
        block_start = 0
    }
    
    # بداية بلوك GT-salat-dikr
    /^# GT-salat-dikr/ || /^# إضافة GT-salat-dikr/ || /^# عرض ذكر/ {
        if (in_gt_block == 0) {
            in_gt_block = 1
            block_start = NR
        }
        next
    }
    
    # داخل بلوك GT
    in_gt_block {
        # عدّ أسطر if
        if (/^if \[/ || /^if test /) {
            if_count++
        }
        
        # نهاية بلوك
        if (/^fi$/ || /^end$/) {
            if (if_count > 0) {
                if_count--
            }
            if (if_count == 0) {
                in_gt_block = 0
                next
            }
        }
        next
    }
    
    # خارج بلوك GT
    !in_gt_block {
        # إزالة أي أسطر متبقية تحتوي على كلمات مفتاحية
        if (!/\bGT-salat-dikr\b/ && !/\bgtsalat\b/ && !/\bgt-tray\b/ && !/\.GT-salat-dikr\b/) {
            print
        }
    }
    ' "$shell_file" > "$TEMP_FILE"
    
    # استبدال الملف الأصلي إذا كان الملف المؤقت ليس فارغاً
    if [ -s "$TEMP_FILE" ]; then
        mv "$TEMP_FILE" "$shell_file"
        echo "    ✅ تم تنظيف $shell_name"
    else
        echo "    ⚠️  الملف المؤقت فارغ، الاحتفاظ بالملف الأصلي"
        rm -f "$TEMP_FILE"
    fi
}

# تنظيف ملفات shell
clean_shell_file_safe "$HOME/.bashrc" ".bashrc"
clean_shell_file_safe "$HOME/.zshrc" ".zshrc"

# تنظيف fish config (بطريقة أبسط)
if [ -f "$HOME/.config/fish/config.fish" ]; then
    echo "  تنظيف fish config"
    grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|\.GT-salat-dikr" \
        "$HOME/.config/fish/config.fish" > "$HOME/.config/fish/config.fish.tmp" 2>/dev/null && \
    mv "$HOME/.config/fish/config.fish.tmp" "$HOME/.config/fish/config.fish" 2>/dev/null || true
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

# حذف الملف المؤقت نفسه
rm -f "/tmp/gt-uninstall-"*.sh 2>/dev/null || true

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

exit 0
