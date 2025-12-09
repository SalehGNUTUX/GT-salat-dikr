#!/bin/bash
# install.sh - تثبيت GT-salat-dikr مع الإعدادات التلقائية الكاملة
# الإصدار 3.2.0

set -e  # إيقاف عند أي خطأ

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# دالة لعرض الرسائل
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# التحقق من أن المستخدم ليس root
if [ "$EUID" -eq 0 ]; then 
    print_error "لا تشغل هذا السكريبت كـ root!"
    print_info "استخدم: bash install.sh"
    exit 1
fi

# شعار البرنامج
clear
echo -e "${BLUE}"
cat << "EOF"
--       ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
--      / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
--     | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
--      \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
--                                                                 
  
  GT-salat-dikr - نظام إشعارات الصلاة والأذكار
                الإصدار 3.2.0
EOF
echo -e "${NC}"

print_info "بدء عملية التثبيت التلقائي..."

# ============================================
# الخطوة 1: الكشف عن النظام
# ============================================
print_status "الخطوة 1: الكشف عن النظام..."

# تحديد التوزيعة
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_NAME=$NAME
elif type lsb_release >/dev/null 2>&1; then
    DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    DISTRO_NAME=$(lsb_release -sd)
else
    DISTRO=$(uname -s | tr '[:upper:]' '[:lower:]')
    DISTRO_NAME=$DISTRO
fi

print_info "التوزيعة: $DISTRO_NAME ($DISTRO)"

# ============================================
# الخطوة 2: تثبيت التبعيات الأساسية
# ============================================
print_status "الخطوة 2: تثبيت التبعيات الأساسية..."

install_dependencies() {
    print_info "تثبيت التبعيات لـ $DISTRO..."
    
    case $DISTRO in
        arch|manjaro|endeavouros)
            sudo pacman -Sy --noconfirm curl jq libnotify notify-send mpv
            ;;
        debian|ubuntu|linuxmint|pop|zorin|elementary)
            sudo apt update
            sudo apt install -y curl jq libnotify-bin notification-daemon mpv
            ;;
        fedora|rhel|centos|almalinux|rocky)
            sudo dnf install -y curl jq libnotify notify-send mpv
            ;;
        opensuse*|suse)
            sudo zypper install -y curl jq libnotify-tools notification-daemon mpv
            ;;
        *)
            print_warning "توزيعة غير معروفة، سيتم تثبيت التبعيات الأساسية فقط..."
            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y curl jq libnotify-bin mpv
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y curl jq libnotify mpv
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm curl jq libnotify mpv
            fi
            ;;
    esac
    
    # تثبيت بدائل الصوت إذا لم يتوفر mpv
    if ! command -v mpv >/dev/null 2>&1; then
        print_info "تثبيت بدائل مشغل الصوت..."
        case $DISTRO in
            debian|ubuntu|linuxmint)
                sudo apt install -y ffmpeg pulseaudio-utils vorbis-tools
                ;;
            fedora|centos|rhel)
                sudo dnf install -y ffmpeg pulseaudio-utils vorbis-tools
                ;;
            arch|manjaro)
                sudo pacman -Sy --noconfirm ffmpeg pulseaudio vorbis-tools
                ;;
        esac
    fi
}

install_dependencies

# ============================================
# الخطوة 3: إنشاء هيكل الدلائل
# ============================================
print_status "الخطوة 3: إنشاء هيكل الدلائل..."

INSTALL_DIR="/opt/gt-salat-dikr"
CONFIG_DIR="$HOME/.config/gt-salat-dikr"
LOCAL_BIN="$HOME/.local/bin"

# إنشاء الدلائل
sudo mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOCAL_BIN"
mkdir -p "$INSTALL_DIR/icons"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/scripts"

# تعيين أذونات
sudo chown -R $USER:$USER "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"

# ============================================
# الخطوة 4: تحميل الملفات الرئيسية
# ============================================
print_status "الخطوة 4: تحميل الملفات الرئيسية..."

download_file() {
    local url="$1"
    local output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        print_error "يجب تثبيت curl أو wget"
        exit 1
    fi
}

# قائمة الملفات للتحميل
FILES=(
    "main.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/main.sh"
    "gt-tray.py:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-tray.py"
    "uninstall.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/uninstall.sh"
    "install-python-deps.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install-python-deps.sh"
    "install-system-tray.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install-system-tray.sh"
    "update-all.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/update-all.sh"
)

print_info "تحميل الملفات الرئيسية..."
for file_entry in "${FILES[@]}"; do
    IFS=':' read -r filename url <<< "$file_entry"
    print_info "تحميل $filename..."
    download_file "$url" "$INSTALL_DIR/$filename"
    chmod +x "$INSTALL_DIR/$filename"
done

# تحميل الأيقونات
print_info "تحميل الأيقونات..."
for size in 16 32 48 64 128 256; do
    download_file \
        "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/icons/prayer-icon-${size}.png" \
        "$INSTALL_DIR/icons/prayer-icon-${size}.png" || true
done

# تحميل ملفات البيانات
print_info "تحميل ملفات البيانات..."
download_file \
    "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/data/azkar.json" \
    "$INSTALL_DIR/data/azkar.json"

download_file \
    "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/data/prayer_methods.json" \
    "$INSTALL_DIR/data/prayer_methods.json"

# ============================================
# الخطوة 5: إنشاء الأوامر الرئيسية
# ============================================
print_status "الخطوة 5: إنشاء الأوامر الرئيسية..."

# إنشاء الأمر الرئيسي gtsalat
sudo tee /usr/local/bin/gtsalat > /dev/null << EOF
#!/bin/bash
"$INSTALL_DIR/main.sh" "\$@"
EOF

sudo chmod +x /usr/local/bin/gtsalat

# إنشاء الأمر gt-tray
ln -sf "$INSTALL_DIR/gt-tray.py" "$LOCAL_BIN/gt-tray"
chmod +x "$LOCAL_BIN/gt-tray"

# إضافة إلى PATH إذا لم يكن موجوداً
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    export PATH="$HOME/.local/bin:$PATH"
fi

# ============================================
# الخطوة 6: تثبيت تبعيات Python
# ============================================
print_status "الخطوة 6: تثبيت تبعيات Python..."

# تشغيل سكريبت تبعيات Python
if [ -f "$INSTALL_DIR/install-python-deps.sh" ]; then
    bash "$INSTALL_DIR/install-python-deps.sh"
else
    print_warning "لم يتم العثور على سكريبت تبعيات Python"
fi

# ============================================
# الخطوة 7: تثبيت System Tray
# ============================================
print_status "الخطوة 7: تثبيت System Tray..."

# تشغيل سكريبت System Tray
if [ -f "$INSTALL_DIR/install-system-tray.sh" ]; then
    bash "$INSTALL_DIR/install-system-tray.sh"
else
    print_warning "لم يتم العثور على سكريبت System Tray"
fi

# ============================================
# الخطوة 8: تطبيق الإعدادات التلقائية
# ============================================
print_status "الخطوة 8: تطبيق الإعدادات التلقائية..."

# تحميل وتشغيل auto-config.sh إذا لم يكن موجوداً محلياً
if [ -f "auto-config.sh" ]; then
    print_info "استخدام ملف auto-config.sh المحلي..."
    bash auto-config.sh
else
    print_info "تحميل وتشغيل auto-config.sh عن بعد..."
    download_file \
        "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/auto-config.sh" \
        "/tmp/auto-config.sh"
    
    if [ -f "/tmp/auto-config.sh" ]; then
        chmod +x "/tmp/auto-config.sh"
        bash "/tmp/auto-config.sh"
        # نسخ إلى مجلد التثبيت للاستخدام المستقبلي
        cp "/tmp/auto-config.sh" "$INSTALL_DIR/auto-config.sh"
    else
        print_warning "تعذر تحميل auto-config.sh، سيتم استخدام الإعدادات الافتراضية..."
        # إنشاء إعدادات افتراضية مباشرة
        source "$INSTALL_DIR/scripts/create-default-config.sh"
    fi
fi

# ============================================
# الخطوة 9: إعداد التحديث التلقائي للبيانات
# ============================================
print_status "الخطوة 9: إعداد التحديث التلقائي للبيانات..."

# إنشاء مهمة cron للتحديث التلقائي لمواقيت الصلاة
CRON_JOB="0 2 * * * /usr/local/bin/gtsalat --update-timetables >/dev/null 2>&1"

# إضافة المهمة إذا لم تكن موجودة
if ! crontab -l 2>/dev/null | grep -q "update-timetables"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    print_info "تم إضافة مهمة cron للتحديث التلقائي لمواقيت الصلاة"
fi

# ============================================
# الخطوة 10: بدء الخدمات
# ============================================
print_status "الخطوة 10: بدء الخدمات..."

# بدء الإشعارات تلقائياً
print_info "بدء خدمة الإشعارات..."
gtsalat --notify-start >/dev/null 2>&1 || true

# بدء System Tray إذا كان النظام يدعمه
if [ -n "$DISPLAY" ] && command -v gt-tray >/dev/null 2>&1; then
    print_info "بدء System Tray..."
    gt-tray >/dev/null 2>&1 &
fi

# ============================================
# الخطوة 11: التحقق النهائي
# ============================================
print_status "الخطوة 11: التحقق النهائي..."

# التحقق من تثبيت الأوامر
echo ""
print_info "التحقق من التثبيت:"
if command -v gtsalat >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} gtsalat - مثبت"
else
    echo -e "  ${RED}✗${NC} gtsalat - غير مثبت"
fi

if command -v gt-tray >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} gt-tray - مثبت"
else
    echo -e "  ${YELLOW}⚠${NC} gt-tray - غير مثبت (قد يحتاج إعادة تشغيل الطرفية)"
fi

# اختبار سريع
echo ""
print_info "اختبار سريع للنظام..."
if gtsalat --show-timetable >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} البرنامج الرئيسي يعمل"
else
    echo -e "  ${YELLOW}⚠${NC} هناك مشكلة في البرنامج الرئيسي"
fi

# ============================================
# عرض رسالة النجاح
# ============================================
echo ""
echo -e "${GREEN}██████████████████████████████████████${NC}"
echo -e "${GREEN}█                                    █${NC}"
echo -e "${GREEN}█  ✅ تم التثبيت بنجاح!              █${NC}"
echo -e "${GREEN}█                                    █${NC}"
echo -e "${GREEN}██████████████████████████████████████${NC}"
echo ""

# عرض التعليمات
print_info "🎉 تم تثبيت GT-salat-dikr الإصدار 3.2.0 بنجاح!"
echo ""
print_info "📋 الإعدادات المفعّلة تلقائياً:"
echo "  • نظام الإشعارات: تم الكشف تلقائياً"
echo "  • التشغيل التلقائي: مفعّل"
echo "  • فاصل الأذكار: 10 دقائق"
echo "  • تنبيه قبل الصلاة: 15 دقيقة"
echo "  • تحديث مواقيت الصلاة: تلقائي (مع وضع عدم الاتصال)"
echo "  • تحديث البرنامج: معطل (يمكن تفعيله يدوياً)"
echo ""
print_info "📍 الخطوات التالية المطلوبة منك:"
echo "  1. ${YELLOW}تأكيد الموقع${NC}:"
echo "     اكتب: gtsalat --settings"
echo "     ثم اضغط Enter لتأكيد الموقع المكتشف"
echo ""
echo "  2. ${YELLOW}اختيار طريقة الحساب${NC}:"
echo "     اختر طريقة الحساب المناسبة لمنطقتك"
echo ""
print_info "🔧 الأوامر المتاحة:"
echo "  • gtsalat                 - عرض ذكر وموعد الصلاة"
echo "  • gtsalat --settings      - إعدادات الموقع والطريقة"
echo "  • gtsalat --notify-stop   - إيقاف الإشعارات"
echo "  • gtsalat --notify-start  - بدء الإشعارات"
echo "  • gt-tray                 - فتح System Tray"
echo "  • gtsalat --self-update   - تحديث البرنامج"
echo ""
print_info "📞 للمساعدة والدعم:"
echo "  • https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
print_warning "🔄 قد تحتاج إلى إعادة تشغيل الطرفية لتطبيق جميع التغييرات."

# تسجيل وقت التثبيت
echo "$(date): تم التثبيت بنجاح - الإصدار 3.2.0" >> "$CONFIG_DIR/install.log"

# عرض رسالة ترحيبية عند أول تشغيل
cat > "$CONFIG_DIR/welcome.sh" << EOF
#!/bin/bash
echo ""
echo "🕌 مرحباً بك في GT-salat-dikr!"
echo "📌 الرجاء تشغيل: gtsalat --settings"
echo "   لتأكيد الموقع واختيار طريقة الحساب"
echo ""
EOF

chmod +x "$CONFIG_DIR/welcome.sh"

# إضافة إلى .bashrc لعرض الترحيب مرة واحدة فقط
if ! grep -q "gt-salat-dikr" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# عرض رسالة ترحيب GT-salat-dikr" >> "$HOME/.bashrc"
    echo "if [ -f \"$CONFIG_DIR/welcome.sh\" ]; then" >> "$HOME/.bashrc"
    echo "    bash \"$CONFIG_DIR/welcome.sh\"" >> "$HOME/.bashrc"
    echo "    rm -f \"$CONFIG_DIR/welcome.sh\"" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
fi

# عرض وقت التثبيت
END_TIME=$(date +%s)
INSTALL_TIME=$((END_TIME - $(date +%s -r "$0" 2>/dev/null || echo $END_TIME)))
print_info "⏱️  وقت التثبيت: ${INSTALL_TIME} ثانية"

exit 0
