#!/bin/bash
# uninstall.sh - إزالة GT-salat-dikr بشكل كامل
# يعمل مباشرة من المستودع أو محلياً

set -e

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
  --       ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
--      / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
--     | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
--      \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
--                                                                 
  إزالة GT-salat-dikr بشكل كامل
EOF
echo -e "${NC}"

# التحقق من أن المستخدم ليس root
if [ "$EUID" -eq 0 ]; then 
    print_error "لا تشغل هذا السكريبت كـ root!"
    print_info "استخدم: bash uninstall.sh"
    exit 1
fi

# طلب التأكيد
echo ""
print_warning "⚠️  هذه العملية ستزيل GT-salat-dikr بشكل كامل"
echo ""
read -p "هل تريد الاستمرار في الإزالة؟ [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_info "تم إلغاء الإزالة."
    exit 0
fi

# ============================================
# الخطوة 1: إيقاف جميع الخدمات
# ============================================
print_info "الخطوة 1: إيقاف جميع الخدمات..."

# إيقاف الإشعارات إذا كان البرنامج مثبتاً
if command -v gtsalat >/dev/null 2>&1; then
    gtsalat --notify-stop >/dev/null 2>&1 || true
fi

# إيقاف System Tray
pkill -f "gt-tray" >/dev/null 2>&1 || true
pkill -f "python.*tray" >/dev/null 2>&1 || true

# إيقاف خدمات systemd
if systemctl list-unit-files | grep -q "gt-salat-dikr"; then
    sudo systemctl stop gt-salat-dikr.service >/dev/null 2>&1 || true
    sudo systemctl disable gt-salat-dikr.service >/dev/null 2>&1 || true
fi

# ============================================
# الخطوة 2: إزالة الملفات
# ============================================
print_info "الخطوة 2: إزالة الملفات..."

# قائمة الملفات والمجلدات للإزالة
PATHS_TO_REMOVE=(
    "/opt/gt-salat-dikr"
    "/usr/local/bin/gtsalat"
    "$HOME/.local/bin/gt-tray"
    "$HOME/.config/gt-salat-dikr"
    "$HOME/.GT-salat-dikr"
    "/etc/systemd/system/gt-salat-dikr.service"
    "/etc/init.d/gt-salat-dikr"
    "$HOME/.cache/gt-salat-dikr"
)

print_warning "الملفات التي سيتم حذفها:"
for path in "${PATHS_TO_REMOVE[@]}"; do
    if [ -e "$path" ]; then
        echo "  • $path"
    fi
done

echo ""
read -p "هل تريد حذف ملفات التكوين والإعدادات الشخصية أيضاً؟ [y/N]: " delete_config

# حذف الملفات
for path in "${PATHS_TO_REMOVE[@]}"; do
    if [ -e "$path" ]; then
        if [[ "$path" == *".config"* ]] && [[ ! "$delete_config" =~ ^[Yy]$ ]]; then
            print_info "حفظ إعدادات $path"
        else
            sudo rm -rf "$path" 2>/dev/null || true
        fi
    fi
done

# ============================================
# الخطوة 3: إزالة مهام cron
# ============================================
print_info "الخطوة 3: إزالة مهام cron..."

if crontab -l 2>/dev/null | grep -q "gt-salat-dikr\|gtsalat"; then
    crontab -l 2>/dev/null | grep -v "gt-salat-dikr\|gtsalat" | crontab -
    print_info "تم إزالة مهام cron"
fi

# ============================================
# الخطوة 4: تنظيف متغيرات البيئة
# ============================================
print_info "الخطوة 4: تنظيف متغيرات البيئة..."

# إزالة من .bashrc
if [ -f "$HOME/.bashrc" ]; then
    sed -i '/gt-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.bashrc" 2>/dev/null || true
fi

# إزالة من .profile
if [ -f "$HOME/.profile" ]; then
    sed -i '/gt-salat-dikr/d' "$HOME/.profile" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.profile" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.profile" 2>/dev/null || true
fi

# إزالة من .zshrc إذا كان مستخدماً
if [ -f "$HOME/.zshrc" ]; then
    sed -i '/gt-salat-dikr/d' "$HOME/.zshrc" 2>/dev/null || true
    sed -i '/GT-salat-dikr/d' "$HOME/.zshrc" 2>/dev/null || true
    sed -i '/gtsalat/d' "$HOME/.zshrc" 2>/dev/null || true
fi

# ============================================
# الخطوة 5: إزالة التبعيات (اختياري)
# ============================================
echo ""
read -p "هل تريد إزالة تبعيات البرنامج أيضاً؟ [y/N]: " remove_deps

if [[ "$remove_deps" =~ ^[Yy]$ ]]; then
    print_info "الخطوة 5: إزالة التبعيات..."
    
    # الكشف عن التوزيعة
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    fi
    
    case $DISTRO in
        arch|manjaro)
            sudo pacman -Rns --noconfirm python-pystray python-pillow jq libnotify mpv 2>/dev/null || true
            ;;
        debian|ubuntu)
            sudo apt remove -y python3-pystray python3-pil jq libnotify-bin mpv 2>/dev/null || true
            ;;
        fedora|centos)
            sudo dnf remove -y python3-pystray python3-pillow jq libnotify mpv 2>/dev/null || true
            ;;
    esac
    
    print_info "تم إزالة التبعيات"
fi

# ============================================
# الخطوة 6: التحقق النهائي
# ============================================
print_info "الخطوة 6: التحقق النهائي..."

# التحقق من أن البرنامج لم يعد موجوداً
if ! command -v gtsalat >/dev/null 2>&1 && [ ! -d "/opt/gt-salat-dikr" ]; then
    echo ""
    echo -e "${GREEN}██████████████████████████████████████${NC}"
    echo -e "${GREEN}█                                    █${NC}"
    echo -e "${GREEN}█  ✅ تم الإزالة بنجاح!              █${NC}"
    echo -e "${GREEN}█                                    █${NC}"
    echo -e "${GREEN}██████████████████████████████████████${NC}"
    echo ""
    
    print_info "تم إزالة GT-salat-dikr بشكل كامل"
    print_info "الملفات المحذوفة:"
    
    if [[ "$delete_config" =~ ^[Yy]$ ]]; then
        echo "  • جميع الملفات والإعدادات"
    else
        echo "  • ملفات النظام فقط (تم حفظ الإعدادات الشخصية)"
    fi
    
    if [[ "$remove_deps" =~ ^[Yy]$ ]]; then
        echo "  • تبعيات البرنامج"
    fi
    
else
    print_warning "⚠️  قد تكون بعض الملفات لا تزال موجودة"
    print_info "يمكنك حذفها يدوياً:"
    echo "  sudo rm -rf /opt/gt-salat-dikr"
    echo "  sudo rm -f /usr/local/bin/gtsalat"
    echo "  rm -rf ~/.config/gt-salat-dikr"
fi

# ============================================
# رسالة وداع
# ============================================
echo ""
print_info "شكراً لك على استخدام GT-salat-dikr!"
print_info "يمكنك إعادة التثبيت في أي وقت باستخدام:"
echo ""
echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
echo ""
print_info "وداعاً! 👋"

exit 0
