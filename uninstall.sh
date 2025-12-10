#!/bin/bash
# uninstall.sh - إزالة كاملة ونظيفة لـ GT-salat-dikr v4.0

# ---------- نسخ السكريبت إلى مكان مؤقت ----------
# هذا يضمن أننا نستطيع حذف جميع الملفات بما فيها هذا السكريبت
TEMP_UNINSTALL="/tmp/gt-uninstall-$$.sh"
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

# نسخ السكريبت إلى الملف المؤقت
cat "$SCRIPT_PATH" > "$TEMP_UNINSTALL"
chmod +x "$TEMP_UNINSTALL"

# تشغيل النسخة المؤقتة وإلغاء النسخة الأصلية
exec "$TEMP_UNINSTALL" "$@"

# لن يصل التنفيذ إلى هنا أبداً لأنه تم استبدال العملية
exit 0

# -----------------------------------------------------------------
# بداية الكود الفعلي (سيتم تنفيذه من الملف المؤقت)
# -----------------------------------------------------------------
#!/bin/bash
# uninstall.sh - الإزالة الكاملة من الملف المؤقت

set -e

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# المتغيرات
INSTALL_DIR="$HOME/.GT-salat-dikr"
CONFIG_DIR="$HOME/.config/gt-salat-dikr"
BIN_DIR="$HOME/.local/bin"
TEMP_UNINSTALL="$0"  # هذا هو الملف المؤقت الآن

# تنظيف عند الخروج
cleanup() {
    # حذف الملف المؤقت نفسه
    if [[ -f "$TEMP_UNINSTALL" && "$TEMP_UNINSTALL" == /tmp/gt-uninstall-*.sh ]]; then
        rm -f "$TEMP_UNINSTALL" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup EXIT INT TERM

# عرض البانر
echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════╗
║         إزالة GT-salat-dikr             ║
║           الإصدار 4.0                   ║
╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo "⚠️  هذا السكريبت سيزيل GT-salat-dikr بشكل كامل."
echo "⚠️  سيتم حذف جميع الملفات والإعدادات."
echo ""

# طلب التأكيد
read -p "هل أنت متأكد من الاستمرار في الإزالة؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    cleanup
fi

echo ""
echo "🚮 بدء عملية الإزالة..."
echo "══════════════════════════════════════════════════"

# ---------- المرحلة 1: إيقاف جميع العمليات ----------
echo ""
echo "1. 🛑 إيقاف جميع عمليات البرنامج..."

# قتل عمليات النظام
echo "   إيقاف عمليات gtsalat..."
pkill -f "gt-tray.py" 2>/dev/null || echo "   ℹ️  لا توجد عمليات gt-tray"
pkill -f "gt-salat-dikr" 2>/dev/null || echo "   ℹ️  لا توجد عمليات gt-salat-dikr"
pkill -f "python3.*gt-salat" 2>/dev/null || echo "   ℹ️  لا توجد عمليات python"

# انتظار لضمان إيقاف العمليات
sleep 2

# ---------- المرحلة 2: إزالة الأوامر ----------
echo ""
echo "2. 🔗 إزالة الأوامر..."

# إزالة الأوامر من النظام (إذا كانت بصلاحيات root)
if [ -f "/usr/local/bin/gtsalat" ]; then
    echo "   إزالة /usr/local/bin/gtsalat"
    sudo rm -f "/usr/local/bin/gtsalat" 2>/dev/null || echo "   ⚠️  تعذر حذف /usr/local/bin/gtsalat"
fi

if [ -f "/usr/bin/gtsalat" ]; then
    echo "   إزالة /usr/bin/gtsalat"
    sudo rm -f "/usr/bin/gtsalat" 2>/dev/null || echo "   ⚠️  تعذر حذف /usr/bin/gtsalat"
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
        echo "   إزالة $cmd"
        rm -f "$cmd" 2>/dev/null || echo "   ⚠️  تعذر حذف $cmd"
    fi
done

# ---------- المرحلة 3: إزالة ملفات النظام ----------
echo ""
echo "3. ⚙️  إزالة ملفات النظام..."

# إزالة ملفات systemd
if [ -f "/etc/systemd/system/gt-salat-dikr.service" ]; then
    echo "   إزالة خدمة systemd"
    sudo systemctl stop gt-salat-dikr.service 2>/dev/null || true
    sudo systemctl disable gt-salat-dikr.service 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/gt-salat-dikr.service" 2>/dev/null || echo "   ⚠️  تعذر حذف الخدمة"
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# إزالة init scripts
if [ -f "/etc/init.d/gt-salat-dikr" ]; then
    echo "   إزالة init script"
    sudo /etc/init.d/gt-salat-dikr stop 2>/dev/null || true
    sudo rm -f "/etc/init.d/gt-salat-dikr" 2>/dev/null || echo "   ⚠️  تعذر حذف init script"
fi

# ---------- المرحلة 4: إزالة مهام cron ----------
echo ""
echo "4. ⏰ إزالة مهام cron..."

if command -v crontab >/dev/null 2>&1; then
    # إزالة من crontab الخاص بالمستخدم
    if crontab -l 2>/dev/null | grep -q "gt-salat-dikr\|gtsalat"; then
        echo "   إزالة مهام cron"
        (crontab -l 2>/dev/null | grep -v "gt-salat-dikr\|gtsalat\|gt-tray") | crontab - 2>/dev/null || echo "   ⚠️  تعذر تحديث crontab"
    fi
fi

# ---------- المرحلة 5: إزالة ملفات بدء التشغيل ----------
echo ""
echo "5. 🚀 إزالة ملفات بدء التشغيل..."

AUTOSTART_FILES=(
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/autostart/gt-salat-dikr-autostart.desktop"
    "$HOME/.config/autostart/gt-tray.desktop"
)

for file in "${AUTOSTART_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   إزالة $file"
        rm -f "$file" 2>/dev/null || echo "   ⚠️  تعذر حذف $file"
    fi
done

# إزالة ملفات KDE
if [ -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" ]; then
    echo "   إزالة ملف KDE autostart"
    rm -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" 2>/dev/null || true
fi

# ---------- المرحلة 6: إزالة الملفات الرئيسية ----------
echo ""
echo "6. 📁 إزالة الملفات الرئيسية..."

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
    "$HOME/.local/share/gt-salat-dikr"
)

# حذف مجلدات التثبيت
for dir in "${INSTALL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   حذف مجلد: $dir"
        # لا نحاول حذف الملف المؤقت أو السكريبت نفسه
        if [[ "$dir" != "/tmp"* ]] && [[ "$dir" != *"gt-uninstall"* ]]; then
            rm -rf "$dir" 2>/dev/null || sudo rm -rf "$dir" 2>/dev/null || echo "   ⚠️  تعذر حذف $dir"
        fi
    fi
done

# حذف مجلدات التكوين
for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   حذف إعدادات: $dir"
        rm -rf "$dir" 2>/dev/null || echo "   ⚠️  تعذر حذف $dir"
    fi
done

# ---------- المرحلة 7: إزالة أيقونات القائمة ----------
echo ""
echo "7. 🎨 إزالة أيقونات القائمة..."

DESKTOP_FILES=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
    "$HOME/Desktop/GT-salat-dikr.desktop"
    "/usr/share/applications/gt-salat-dikr.desktop"
    "/usr/local/share/applications/gt-salat-dikr.desktop"
)

for desktop_file in "${DESKTOP_FILES[@]}"; do
    if [ -f "$desktop_file" ]; then
        echo "   إزالة $desktop_file"
        rm -f "$desktop_file" 2>/dev/null || sudo rm -f "$desktop_file" 2>/dev/null || echo "   ⚠️  تعذر حذف $desktop_file"
    fi
done

# تحديث قاعدة بيانات التطبيقات
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# ---------- المرحلة 8: تنظيف ملفات التهيئة (الطريقة الآمنة) ----------
echo ""
echo "8. 🧹 تنظيف ملفات التهيئة..."

clean_shell_file() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ ! -f "$shell_file" ]; then
        return
    fi
    
    echo "   تنظيف $shell_name..."
    
    # إنشاء ملف مؤقت
    temp_file="$(mktemp)"
    
    # استخدام Python للتنظيف الآمن (أكثر موثوقية)
    python3 -c "
import sys
import re

file_path = sys.argv[1]
temp_path = sys.argv[2]

# قراءة الملف
with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

in_gt_block = False
gt_block_start = 0
output_lines = []

for i, line in enumerate(lines):
    stripped = line.strip()
    
    # اكتشاف بداية بلوك GT-salat-dikr
    if stripped.startswith('# GT-salat-dikr') or \
       stripped.startswith('# إضافة GT-salat-dikr') or \
       'GT-salat-dikr' in line:
        in_gt_block = True
        gt_block_start = i
        print(f'   🔍 وجدت بلوك GT-salat-dikr في سطر {i+1}')
        continue
    
    # إذا كنا داخل بلوك GT
    if in_gt_block:
        # نهاية بلوك if
        if stripped == 'fi' or re.match(r'^\s*fi\s*(#.*)?$', stripped):
            in_gt_block = False
            print(f'   ✅ نهاية بلوك GT في سطر {i+1}')
        continue
    
    # تخطي الأسطر التي تحتوي على كلمات مفتاحية
    if any(keyword in line for keyword in [
        'gtsalat', 'GT-salat-dikr', 'gt-tray', 
        'gt-launcher', '~/.GT-salat-dikr',
        '.GT-salat-dikr', 'gt-salat-dikr.py'
    ]):
        continue
    
    # حفظ السطر
    output_lines.append(line)

# كتابة الملف المؤقت
with open(temp_path, 'w', encoding='utf-8') as f:
    f.writelines(output_lines)
" "$shell_file" "$temp_file"
    
    # التحقق من الملف المؤقت واستبدال الأصلي
    if [ -s "$temp_file" ] && [ "$(wc -l < "$temp_file" 2>/dev/null)" -gt 0 ]; then
        # نسخ الملف المؤقت إلى الأصلي
        cp "$temp_file" "$shell_file"
        echo "   ✅ تم تنظيف $shell_name بنجاح"
    else
        echo "   ⚠️  الملف المؤقت فارغ أو به مشكلة"
    fi
    
    # تنظيف الملف المؤقت
    rm -f "$temp_file" 2>/dev/null || true
}

# تنظيف ملفات shell المختلفة
clean_shell_file "$HOME/.bashrc" ".bashrc"
clean_shell_file "$HOME/.zshrc" ".zshrc"
clean_shell_file "$HOME/.profile" ".profile"
clean_shell_file "$HOME/.bash_profile" ".bash_profile"

# تنظيف fish config
if [ -f "$HOME/.config/fish/config.fish" ]; then
    echo "   تنظيف fish config"
    grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|~/.GT-salat-dikr" \
        "$HOME/.config/fish/config.fish" > "$HOME/.config/fish/config.fish.tmp" 2>/dev/null && \
    mv "$HOME/.config/fish/config.fish.tmp" "$HOME/.config/fish/config.fish" 2>/dev/null || true
fi

# ---------- المرحلة 9: تنظيف الملفات المؤقتة ----------
echo ""
echo "9. 🗑️  تنظيف الملفات المؤقتة..."

# حذف ملفات PID والlock
rm -f /tmp/gt-*.pid 2>/dev/null || true
rm -f /tmp/gt-*.lock 2>/dev/null || true
rm -f /tmp/gt-salat-* 2>/dev/null || true
rm -f /tmp/GT-salat-* 2>/dev/null || true

# حذف سجلات البرنامج
rm -f /var/log/gt-salat-*.log 2>/dev/null || true
rm -f "$HOME/.cache/gt-*" 2>/dev/null || true
rm -f "$HOME/.cache/GT-*" 2>/dev/null || true

# حذف أي ملفات مؤقتة أخرى
find /tmp -name "*gt-salat*" -delete 2>/dev/null || true
find /tmp -name "*GT-salat*" -delete 2>/dev/null || true

# ---------- المرحلة 10: إزالة متغيرات البيئة ----------
echo ""
echo "10. 🌐 إزالة متغيرات البيئة..."

# إزالة من /etc/environment إذا وجد
if [ -f "/etc/environment" ] && sudo grep -q "GT_SALAT" "/etc/environment" 2>/dev/null; then
    echo "   تنظيف /etc/environment"
    sudo sed -i '/GT_SALAT/d' "/etc/environment" 2>/dev/null || true
fi

# ---------- المرحلة 11: إزالة مكتبات Python (اختياري) ----------
echo ""
read -p "هل تريد إزالة مكتبات Python أيضاً؟ [y/N]: " remove_python
if [[ "$remove_python" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️  إزالة مكتبات Python..."
    
    # قائمة المكتبات الممكنة
    PYTHON_LIBS=(
        "pystray"
        "Pillow"
        "geocoder"
        "prayer-times"
        "islamic-prayer"
    )
    
    for lib in "${PYTHON_LIBS[@]}"; do
        echo "   إزالة $lib..."
        python3 -m pip uninstall -y "$lib" 2>/dev/null || \
        pip3 uninstall -y "$lib" 2>/dev/null || true
    done
    
    echo "   ✅ تمت إزالة مكتبات Python"
fi

# ---------- المرحلة 12: التحقق النهائي ----------
echo ""
echo "12. 🔍 التحقق النهائي..."

REMAINING_FILES=()
CHECK_PATHS=(
    "$HOME/.GT-salat-dikr"
    "$HOME/.local/bin/gtsalat"
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/gt-salat-dikr"
    "/usr/local/bin/gtsalat"
)

echo ""
echo "   البحث عن الملفات المتبقية..."
for path in "${CHECK_PATHS[@]}"; do
    if [ -e "$path" ]; then
        REMAINING_FILES+=("$path")
        echo "   ⚠️  وجد: $path"
    fi
done

# البحث في مجلدات أخرى
find_remaining() {
    local search_path="$1"
    local pattern="$2"
    find "$search_path" -name "*gt*salat*" -o -name "*GT*salat*" -o -name "*gt*salat*" 2>/dev/null | head -5
}

# تحقق سريع في أماكن شائعة
EXTRA_PATHS=$(find_remaining "$HOME" "*gt*")
if [ -n "$EXTRA_PATHS" ]; then
    while IFS= read -r path; do
        if [ -n "$path" ] && [ -e "$path" ]; then
            REMAINING_FILES+=("$path")
        fi
    done <<< "$EXTRA_PATHS"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo ""

if [ ${#REMAINING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ تمت الإزالة الكاملة بنجاح!${NC}"
    echo ""
    echo "📋 ملخص ما تم إزالته:"
    echo "   • 📁 جميع ملفات البرنامج"
    echo "   • 🔗 جميع الأوامر والروابط"
    echo "   • 🚀 جميع إعدادات بدء التشغيل"
    echo "   • ⚙️  جميع الإعدادات والتكوينات"
    echo "   • 🎨 جميع الأيقونات وقوائم التطبيقات"
    echo "   • 🧹 جميع الملفات المؤقتة والسجلات"
else
    echo -e "${YELLOW}⚠️  بعض الملفات لا تزال موجودة:${NC}"
    echo ""
    for file in "${REMAINING_FILES[@]}"; do
        echo "   • $file"
    done
    echo ""
    echo -e "${YELLOW}يمكنك حذفها يدوياً باستخدام:${NC}"
    echo "   sudo rm -rf /path/to/file"
fi

# إزالة هذا الملف المؤقت (سيتم بواسطة trap)
echo ""
echo "🧽 تنظيف الملفات المؤقتة..."

# إزالة أي ملفات مؤقتة متبقية
rm -f /tmp/gt-uninstall-*.sh 2>/dev/null || true
rm -f /tmp/uninstall-gt-salat.sh 2>/dev/null || true

echo ""
echo "══════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}شكراً لك على استخدام GT-salat-dikr!${NC}"
echo ""
echo "🔄 لإعادة التثبيت في أي وقت:"
echo "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
echo "📚 للمساعدة والدعم:"
echo "https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
echo -e "${GREEN}مع السلامة! 👋${NC}"
echo ""

# التنظيف النهائي سيتم بواسطة trap
exit 0
