#!/bin/bash
# uninstall.sh - إزالة كاملة لـ GT-salat-dikr
# يزيل جميع الملفات، الخدمات، الإعدادات، وأيقونات بدء التشغيل

set -e

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# عرض عنوان الإزالة
clear
echo -e "${RED}"
cat << "EOF"
      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
     
  إزالة GT-salat-dikr بشكل كامل
EOF
echo -e "${NC}"

# التحقق من أن المستخدم ليس root
if [ "$EUID" -eq 0 ]; then 
    print_error "لا تشغل هذا السكريبت كـ root!"
    print_info "استخدم: bash uninstall.sh"
    exit 1
fi

# ---------- المرحلة 0: توقف تام لجميع العمليات ----------
print_info "المرحلة 1: إيقاف كامل لجميع عمليات GT-salat-dikr..."

# قتل جميع عمليات البرنامج
print_info "إيقاف جميع العمليات النشطة..."

# 1. قتل عمليات python (System Tray)
pkill -f "gt-tray.py" >/dev/null 2>&1 || true
pkill -f "python.*tray" >/dev/null 2>&1 || true
pkill -f "python.*gt-salat" >/dev/null 2>&1 || true

# 2. قتل عمليات bash الرئيسية
pkill -f "gt-salat-dikr.sh" >/dev/null 2>&1 || true
pkill -f "gtsalat" >/dev/null 2>&1 || true
pkill -f "gt-launcher" >/dev/null 2>&1 || true

# 3. قتل عمليات الإشعارات
pkill -f "notify-send.*GT-salat" >/dev/null 2>&1 || true
pkill -f "notify-send.*صلاة" >/dev/null 2>&1 || true
pkill -f "notify-send.*أذكار" >/dev/null 2>&1 || true

# 4. قتل عمليات الصوت
pkill -f "mpv.*adhan" >/dev/null 2>&1 || true
pkill -f "mpv.*أذان" >/dev/null 2>&1 || true

# 5. تأكيد القتل مع انتظار
sleep 2

# ---------- المرحلة 1: إيقاف وإزالة جميع الخدمات ----------
print_info "المرحلة 2: إيقاف وإزالة جميع الخدمات..."

# 1. خدمات systemd
if systemctl list-unit-files | grep -q "gt-salat-dikr" 2>/dev/null; then
    print_info "إزالة خدمة systemd..."
    sudo systemctl stop gt-salat-dikr.service >/dev/null 2>&1 || true
    sudo systemctl disable gt-salat-dikr.service >/dev/null 2>&1 || true
    sudo rm -f /etc/systemd/system/gt-salat-dikr.service >/dev/null 2>&1 || true
    sudo rm -f /usr/lib/systemd/system/gt-salat-dikr.service >/dev/null 2>&1 || true
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
fi

# 2. خدمات init.d
if [ -f "/etc/init.d/gt-salat-dikr" ]; then
    print_info "إزالة خدمة init.d..."
    sudo /etc/init.d/gt-salat-dikr stop >/dev/null 2>&1 || true
    sudo update-rc.d -f gt-salat-dikr remove >/dev/null 2>&1 || true
    sudo rm -f /etc/init.d/gt-salat-dikr >/dev/null 2>&1 || true
fi

# 3. خدمات upstart (إذا وجدت)
if [ -f "/etc/init/gt-salat-dikr.conf" ]; then
    print_info "إزالة خدمة upstart..."
    sudo stop gt-salat-dikr >/dev/null 2>&1 || true
    sudo rm -f /etc/init/gt-salat-dikr.conf >/dev/null 2>&1 || true
fi

# ---------- المرحلة 2: إزالة مهام cron ----------
print_info "المرحلة 3: إزالة جميع مهام cron..."

# إزالة جميع مهام cron المتعلقة بالبرنامج
if command -v crontab >/dev/null 2>&1; then
    if crontab -l 2>/dev/null | grep -q "gt-salat-dikr\|gtsalat"; then
        print_info "إزالة مهام cron..."
        crontab -l 2>/dev/null | grep -v "gt-salat-dikr\|gtsalat" | crontab - 2>/dev/null || true
    fi
fi

# إزالة ملفات cron في /etc/cron*
sudo rm -f /etc/cron.d/gt-salat-dikr 2>/dev/null || true
sudo rm -f /etc/cron.daily/gt-salat-dikr 2>/dev/null || true
sudo rm -f /etc/cron.hourly/gt-salat-dikr 2>/dev/null || true

# ---------- المرحلة 3: إزالة ملفات بدء التشغيل ----------
print_info "المرحلة 4: إزالة ملفات بدء التشغيل..."

# 1. إزالة autostart لـ GNOME/XFCE/MATE
AUTOSTART_FILES=(
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/autostart/gt-salat-dikr-autostart.desktop"
    "/etc/xdg/autostart/gt-salat-dikr.desktop"
)

for file in "${AUTOSTART_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_info "إزالة: $file"
        rm -f "$file" 2>/dev/null || sudo rm -f "$file" 2>/dev/null || true
    fi
done

# 2. إزالة autostart لـ KDE Plasma
KDE_FILES=(
    "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh"
    "$HOME/.config/plasma-workspace/shutdown/gt-salat-dikr.sh"
    "$HOME/.config/plasma-workspace/autostart/gt-salat-dikr.desktop"
)

for file in "${KDE_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_info "إزالة: $file"
        rm -f "$file" 2>/dev/null || true
    fi
done

# 3. إزالة autostart لـ LXDE/LXQt
LXDE_FILES=(
    "$HOME/.config/lxsession/LXDE/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/lxsession/Lubuntu/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/lxsession/LXDE-pi/autostart/gt-salat-dikr.desktop"
)

for file in "${LXDE_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_info "إزالة: $file"
        rm -f "$file" 2>/dev/null || true
    fi
done

# ---------- المرحلة 4: إزالة الأوامر والروابط ----------
print_info "المرحلة 5: إزالة الأوامر والروابط..."

# قائمة الأوامر لإزالتها
COMMANDS=(
    "/usr/local/bin/gtsalat"
    "/usr/bin/gtsalat"
    "/usr/local/bin/gt-tray"
    "/usr/bin/gt-tray"
    "/usr/local/bin/gt-launcher"
    "/usr/bin/gt-launcher"
)

for cmd in "${COMMANDS[@]}"; do
    if [ -f "$cmd" ] || [ -L "$cmd" ]; then
        print_info "إزالة: $cmd"
        sudo rm -f "$cmd" 2>/dev/null || true
    fi
done

# إزالة روابط المستخدم
USER_COMMANDS=(
    "$HOME/.local/bin/gtsalat"
    "$HOME/.local/bin/gt-tray"
    "$HOME/.local/bin/gt-launcher"
    "$HOME/.local/bin/gt-salat-launcher"
)

for cmd in "${USER_COMMANDS[@]}"; do
    if [ -f "$cmd" ] || [ -L "$cmd" ]; then
        print_info "إزالة: $cmd"
        rm -f "$cmd" 2>/dev/null || true
    fi
done

# ---------- المرحلة 5: إزالة الملفات الرئيسية ----------
print_info "المرحلة 6: إزالة الملفات الرئيسية..."

# قائمة المجلدات والملفات للحذف
PATHS_TO_REMOVE=(
    # المجلدات الرئيسية
    "/opt/gt-salat-dikr"
    "$HOME/.GT-salat-dikr"
    "$HOME/GT-salat-dikr"
    
    # مجلدات التكوين
    "$HOME/.config/gt-salat-dikr"
    "$HOME/.gt-salat-dikr"
    
    # مجلدات البيانات
    "$HOME/.local/share/gt-salat-dikr"
    "$HOME/.cache/gt-salat-dikr"
    "/var/lib/gt-salat-dikr"
    
    # مجلدات السجلات
    "/var/log/gt-salat-dikr"
    "$HOME/.gt-salat-dikr-logs"
    
    # الملفات المؤقتة
    "/tmp/gt-salat-*"
    "/tmp/gt-tray-*"
    "$TMPDIR/gt-salat-*"
)

# عرض ما سيتم حذفه
print_warning "الملفات والمجلدات التي سيتم حذفها:"
for path in "${PATHS_TO_REMOVE[@]}"; do
    if [ -e "$path" ] || ls "$path" 2>/dev/null | grep -q "."; then
        echo "  • $path"
    fi
done

echo ""
read -p "هل تريد حذف جميع إعدادات المستخدم أيضاً؟ [y/N]: " delete_user_config

# طلب التأكيد النهائي
echo ""
print_warning "⚠️  هذه العملية ستزيل GT-salat-dikr بشكل كامل ولا يمكن التراجع عنها!"
echo ""
read -p "هل تريد الاستمرار في الإزالة الكاملة؟ [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_info "تم إلغاء الإزالة."
    exit 0
fi

# حذف الملفات والمجلدات
for path in "${PATHS_TO_REMOVE[@]}"; do
    if [[ "$path" == *"*"* ]]; then
        # حذف باستخدام pattern
        rm -rf $path 2>/dev/null || sudo rm -rf $path 2>/dev/null || true
    else
        # حذف ملف/مجلد محدد
        if [ -e "$path" ]; then
            print_info "حذف: $path"
            rm -rf "$path" 2>/dev/null || sudo rm -rf "$path" 2>/dev/null || true
        fi
    fi
done

# حذف ملفات PID المؤقتة
rm -f /tmp/gt-*.pid 2>/dev/null || true
rm -f /tmp/gt-*.lock 2>/dev/null || true
rm -f /tmp/gt-salat-* 2>/dev/null || true

# ---------- المرحلة 6: إزالة أيقونات القوائم ----------
print_info "المرحلة 7: إزالة أيقونات القوائم..."

# قائمة ملفات .desktop
DESKTOP_FILES=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
    "/usr/share/applications/gt-salat-dikr.desktop"
    "/usr/local/share/applications/gt-salat-dikr.desktop"
)

for desktop_file in "${DESKTOP_FILES[@]}"; do
    if [ -f "$desktop_file" ]; then
        print_info "إزالة: $desktop_file"
        rm -f "$desktop_file" 2>/dev/null || sudo rm -f "$desktop_file" 2>/dev/null || true
    fi
done

# تحديث قاعدة بيانات التطبيقات
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    sudo update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# ---------- المرحلة 7: تنظيف متغيرات البيئة ----------
print_info "المرحلة 8: تنظيف متغيرات البيئة..."

# إزالة من .bashrc
if [ -f "$HOME/.bashrc" ]; then
    print_info "تنظيف .bashrc..."
    sed -i '/gt-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/gt-tray/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/gt-launcher/d' "$HOME/.bashrc" 2>/dev/null || true
fi

# إزالة من .profile
if [ -f "$HOME/.profile" ]; then
    print_info "تنظيف .profile..."
    sed -i '/gt-salat-dikr/d' "$HOME/.profile" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.profile" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.profile" 2>/dev/null || true
fi

# إزالة من .zshrc (إذا كان موجوداً)
if [ -f "$HOME/.zshrc" ]; then
    print_info "تنظيف .zshrc..."
    sed -i '/gt-salat-dikr/d' "$HOME/.zshrc" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.zshrc" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.zshrc" 2>/dev/null || true
fi

# ---------- المرحلة 8: إزالة التبعيات (اختياري) ----------
echo ""
read -p "هل تريد إزالة تبعيات البرنامج أيضاً؟ (Python libraries) [y/N]: " remove_deps

if [[ "$remove_deps" =~ ^[Yy]$ ]]; then
    print_info "المرحلة 9: إزالة تبعيات البرنامج..."
    
    # الكشف عن التوزيعة
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    fi
    
    case $DISTRO in
        arch|manjaro)
            print_info "إزالة حزم Arch/Manjaro..."
            sudo pacman -Rns --noconfirm python-pystray python-pillow 2>/dev/null || true
            ;;
        debian|ubuntu|linuxmint)
            print_info "إزالة حزم Debian/Ubuntu..."
            sudo apt remove -y python3-pystray python3-pil 2>/dev/null || true
            sudo apt autoremove -y 2>/dev/null || true
            ;;
        fedora|centos|rhel)
            print_info "إزالة حزم Fedora/CentOS..."
            sudo dnf remove -y python3-pystray python3-pillow 2>/dev/null || true
            ;;
    esac
    
    # إزالة باستخدام pip (للمستخدم)
    if command -v pip3 >/dev/null 2>&1; then
        pip3 uninstall -y pystray pillow 2>/dev/null || true
    fi
    
    print_info "تم إزالة التبعيات"
fi

# ---------- المرحلة 9: التحقق النهائي ----------
print_info "المرحلة 10: التحقق النهائي..."

# التحقق من أن البرنامج قد أزيل تماماً
FAILED_REMOVALS=()

# التحقق من الملفات الرئيسية
CHECK_PATHS=(
    "/opt/gt-salat-dikr"
    "$HOME/.GT-salat-dikr"
    "/usr/local/bin/gtsalat"
    "$HOME/.local/bin/gtsalat"
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
)

for path in "${CHECK_PATHS[@]}"; do
    if [ -e "$path" ]; then
        FAILED_REMOVALS+=("$path")
    fi
done

# التحقق من العمليات النشطة
if pgrep -f "gt-salat\|gt-tray" >/dev/null 2>&1; then
    FAILED_REMOVALS+=("عمليات نشطة للبرنامج")
fi

# عرض نتيجة الإزالة
echo ""
if [ ${#FAILED_REMOVALS[@]} -eq 0 ]; then
    echo -e "${GREEN}██████████████████████████████████████${NC}"
    echo -e "${GREEN}█                                    █${NC}"
    echo -e "${GREEN}█  ✅ تم الإزالة الكاملة بنجاح!     █${NC}"
    echo -e "${GREEN}█                                    █${NC}"
    echo -e "${GREEN}██████████████████████████████████████${NC}"
    echo ""
    
    print_info "تم إزالة GT-salat-dikr بشكل كامل!"
    print_info "تم حذف:"
    echo "  • جميع الملفات والمجلدات"
    echo "  • جميع الخدمات والعمليات"
    echo "  • جميع إعدادات بدء التشغيل"
    echo "  • جميع الأيقونات والأوامر"
    echo "  • جميع الإعدادات والسجلات"
    
    if [[ "$remove_deps" =~ ^[Yy]$ ]]; then
        echo "  • تبعيات البرنامج (مكتبات Python)"
    fi
    
else
    print_warning "⚠️  بعض الملفات لا تزال موجودة:"
    for item in "${FAILED_REMOVALS[@]}"; do
        echo "  • $item"
    done
    
    echo ""
    print_info "يمكنك حذفها يدوياً باستخدام:"
    for item in "${FAILED_REMOVALS[@]}"; do
        if [[ "$item" != "عمليات نشطة للبرنامج" ]]; then
            echo "  sudo rm -rf \"$item\""
        fi
    done
    
    if [[ " ${FAILED_REMOVALS[@]} " =~ "عمليات نشطة للبرنامج" ]]; then
        echo "  pkill -f \"gt-salat\|gt-tray\""
    fi
fi

# ---------- المرحلة 10: رسالة الوداع ----------
echo ""
print_info "شكراً لك على استخدام GT-salat-dikر!"
print_info "تمت الإزالة بتاريخ: $(date)"

echo ""
print_info "لإعادة التثبيت في أي وقت:"
echo ""
echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
print_info "وداعاً! 👋"

# إزالة هذا الملف نفسه إذا كان في مجلد التثبيت
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ "$SCRIPT_DIR" == *".GT-salat-dikr"* ]] || [[ "$SCRIPT_DIR" == *"gt-salat-dikr"* ]]; then
    rm -f "$0" 2>/dev/null || true
fi

exit 0
