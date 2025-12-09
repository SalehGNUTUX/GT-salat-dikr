#!/bin/bash
#
# GT-salat-dikr Complete Installation v3.2.4
# تثبيت كامل مع واجهة مستخدم محسنة
#

set -e

# دالة لعرض الرأس الفني
show_header() {
    clear
    cat << "EOF"

      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.4 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     مرحباً بك في تثبيت GT-salat-dikr!"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من عدم التشغيل كـ root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
MAIN_SCRIPT="gt-salat-dikr.sh"
CONFIG_FILE="$INSTALL_DIR/settings.conf"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
DESKTOP_FILE="$INSTALL_DIR/gt-salat-dikr.desktop"
LAUNCHER_FILE="$INSTALL_DIR/launcher.sh"
UNINSTALLER="$INSTALL_DIR/uninstall.sh"

# ---------- المرحلة 1: التثبيت الأساسي ----------
echo "📥 تحميل البرنامج..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# تحميل الملفات الأساسية
ESSENTIAL_FILES=(
    "$MAIN_SCRIPT"
    "azkar.txt"
    "adhan.ogg"
    "short_adhan.ogg"
    "prayer_approaching.ogg"
    "gt-tray.py"
)

for file in "${ESSENTIAL_FILES[@]}"; do
    echo "  ⬇️  تحميل: $file"
    curl -fsSL "$REPO_BASE/$file" -o "$file" 2>/dev/null || echo "  ⚠️  لم يتم تحميل $file"
done

# تحميل ملف إلغاء التثبيت
echo "  ⬇️  تحميل: uninstall.sh"
curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/uninstall.sh" -o "$UNINSTALLER" 2>/dev/null && {
    chmod +x "$UNINSTALLER"
    echo "  ✅ تم تحميل ملف إلغاء التثبيت"
} || echo "  ⚠️  لم يتم تحميل uninstall.sh"

chmod +x "$MAIN_SCRIPT" "gt-tray.py" 2>/dev/null || true

# ---------- المرحلة 2: تحميل الأيقونات ----------
echo ""
echo "🖼️  تحميل الأيقونات..."

ICON_DIR="$INSTALL_DIR/icons"
mkdir -p "$ICON_DIR"

echo "⬇️  جاري تحميل الأيقونات..."
for size in 16 32 48 64 128 256; do
    icon_url="$REPO_BASE/icons/prayer-icon-${size}.png"
    icon_file="$ICON_DIR/prayer-icon-${size}.png"
    
    if curl -fsSL "$icon_url" -o "$icon_file" 2>/dev/null; then
        echo "  ✅ تم تحميل أيقونة ${size}x${size}"
    fi
done

# ---------- المرحلة 3: إنشاء Launcher محسّن مع رسالة التقدم ----------
echo ""
echo "🔧 إنشاء مُشغّل ذكي مع واجهة مستخدم محسنة..."

cat > "$LAUNCHER_FILE" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Launcher v2.0
# واجهة مستخدم محسنة مع رسائل تقدم
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"
LOCK_FILE="/tmp/gt-salat-launcher.lock"

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# دالة لعرض إطار جميل
show_box() {
    local width=50
    local text="$1"
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════╗${NC}"
    printf "${PURPLE}║${NC}%*s${WHITE}%s${NC}%*s${PURPLE}║${NC}\n" $padding "" "$text" $padding ""
    echo -e "${PURPLE}╚════════════════════════════════════════════════════╝${NC}"
}

# دالة لعرض رسالة تقدم
show_progress() {
    local step="$1"
    local message="$2"
    
    echo -e "${CYAN}⏳ [الخطوة $step]${NC} ${WHITE}$message${NC}"
    sleep 1
}

# دالة للتحقق من System Tray
check_tray_running() {
    if pgrep -f "gt-tray.py" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# دالة بدء System Tray مع عرض التقدم
start_tray_with_progress() {
    echo ""
    show_box "🕌 GT-salat-dikr"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}        جاري تشغيل System Tray...${NC}"
    echo -e "${YELLOW}        ⏳ الرجاء الانتظار 5-10 ثواني${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    show_progress "1" "التحقق من متطلبات النظام..."
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}❌ Python3 غير مثبت${NC}"
        return 1
    fi
    
    show_progress "2" "تحميل مكتبات Python..."
    if ! python3 -c "import pystray, PIL" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  المكتبات غير مثبتة، قد يستغرق وقتاً أطول${NC}"
    fi
    
    show_progress "3" "تهيئة بيئة المستخدم..."
    export DISPLAY="${DISPLAY:-:0}"
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
    
    show_progress "4" "تشغيل System Tray..."
    echo -e "${BLUE}   🔄 جاري التشغيل (قد يستغرق بضع ثواني)...${NC}"
    
    # تشغيل في الخلفية مع عرض رسالة تقدم
    cd "$INSTALL_DIR"
    python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    local tray_pid=$!
    
    # عرض مؤشر تقدم متحرك
    echo -n "${CYAN}   "
    for i in {1..10}; do
        echo -n "▉"
        sleep 0.5
    done
    echo "${NC}"
    
    sleep 2
    
    if ps -p $tray_pid >/dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ تم التشغيل بنجاح!${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}📌 ماذا يمكنك أن تفعل الآن:${NC}"
        echo -e "${CYAN}  1. 🔍 ابحث عن الأيقونة في شريط المهام${NC}"
        echo -e "${CYAN}  2. 🖱️  انقر بزر الماوس الأيمن للتحكم${NC}"
        echo -e "${CYAN}  3. ⚙️  استخدم 'gtsalat' في الطرفية للمزيد${NC}"
        echo ""
        echo -e "${YELLOW}💡 النافذة ستُغلق تلقائياً خلال 10 ثواني...${NC}"
        
        # حفظ PID
        echo $tray_pid > "/tmp/gt-salat-tray.pid"
        
        # إغلاق النافذة بعد 10 ثواني
        sleep 10
        return 0
    else
        echo ""
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}❌ تعذر تشغيل System Tray${NC}"
        echo -e "${RED}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}🔧 الحلول المقترحة:${NC}"
        echo -e "${WHITE}  1. تأكد من تثبيت Python3${NC}"
        echo -e "${WHITE}  2. ثبت المكتبات: pip install pystray pillow${NC}"
        echo -e "${WHITE}  3. حاول تشغيل: gtsalat --tray${NC}"
        echo ""
        read -p "اضغط Enter للإغلاق... "
        return 1
    fi
}

# دالة العرض الرئيسية
main_menu() {
    clear
    show_box "GT-salat-dikr - لوحة التحكم"
    echo ""
    
    if check_tray_running; then
        echo -e "${GREEN}✅ System Tray يعمل بالفعل${NC}"
        echo ""
        echo -e "${CYAN}📊 معلومات الصلاة الحالية:${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
        "$MAIN_SCRIPT" 2>/dev/null || echo -e "${YELLOW}جاري تحميل البيانات...${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}💡 الأيقونة نشطة في شريط المهام${NC}"
        echo -e "${WHITE}🖱️  انقر بزر الماوس الأيمن للتحكم${NC}"
        echo ""
        read -p "اضغط Enter للإغلاق... "
    else
        echo -e "${YELLOW}⚠️  System Tray غير نشط${NC}"
        echo ""
        echo -e "${WHITE}ماذا تريد أن تفعل؟${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
        echo -e "  ${GREEN}1. 🚀 تشغيل System Tray${NC}"
        echo -e "  ${BLUE}2. 📊 عرض مواقيت الصلاة${NC}"
        echo -e "  ${PURPLE}3. ⚙️  فتح الإعدادات${NC}"
        echo -e "  ${CYAN}4. ❓ المساعدة${NC}"
        echo -e "  ${RED}5. ❌ خروج${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "اختر رقم الإجراء [1-5]: " choice
        
        case $choice in
            1)
                start_tray_with_progress
                ;;
            2)
                clear
                show_box "مواقيت الصلاة اليوم"
                echo ""
                "$MAIN_SCRIPT" --show-timetable 2>/dev/null || echo "تعذر تحميل المواقيت"
                echo ""
                read -p "اضغط Enter للعودة... "
                main_menu
                ;;
            3)
                clear
                show_box "إعدادات البرنامج"
                echo ""
                "$MAIN_SCRIPT" --settings
                echo ""
                read -p "اضغط Enter للعودة... "
                main_menu
                ;;
            4)
                clear
                show_box "مساعدة GT-salat-dikr"
                echo ""
                "$MAIN_SCRIPT" --help | head -40
                echo ""
                read -p "اضغط Enter للعودة... "
                main_menu
                ;;
            5)
                echo ""
                echo -e "${GREEN}👋 مع السلامة!${NC}"
                echo ""
                sleep 2
                ;;
            *)
                echo -e "${RED}❌ اختيار غير صالح${NC}"
                sleep 2
                main_menu
                ;;
        esac
    fi
}

# التحقق من القفل
if [ -f "$LOCK_FILE" ]; then
    echo -e "${YELLOW}⚠️  البرنامج يعمل بالفعل${NC}"
    exit 0
fi

touch "$LOCK_FILE"
trap "rm -f '$LOCK_FILE'" EXIT

# بدء الواجهة
main_menu

exit 0
EOF

chmod +x "$LAUNCHER_FILE"

# ---------- المرحلة 4: إنشاء ملف .desktop مزدوج التصنيف ----------
echo ""
echo "🖥️  إنشاء ملف تطبيق في قائمة البرامج..."

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GT-salat-dikr
GenericName=Prayer Times & Azkar Notifications
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=gnome-terminal --geometry=80x25 -- bash -c "cd '$INSTALL_DIR' && './launcher.sh'; echo ''; echo '══════════════════════════════════════'; echo 'النافذة ستُغلق تلقائياً...'; sleep 5"
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Terminal=false
StartupNotify=false
Categories=Education;Utility;
Keywords=prayer;islam;azkar;reminder;صلاة;أذكار;إسلام;تذكير;
MimeType=
X-GNOME-FullName=GT-salat-dikr Prayer Reminder
StartupWMClass=gt-salat-dikr
EOF

# نسخ ملف .desktop لمواقع متعددة
echo "📁 نسخ ملف التطبيق إلى قوائم النظام..."

DESKTOP_LOCATIONS=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "/usr/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
)

for location in "${DESKTOP_LOCATIONS[@]}"; do
    mkdir -p "$(dirname "$location")" 2>/dev/null || true
    cp "$DESKTOP_FILE" "$location" 2>/dev/null && echo "  ✅ تم النسخ إلى: $(dirname "$location")" || true
done

# تحديث قاعدة بيانات التطبيقات
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
echo "  ✅ تم تحديث قائمة التطبيقات"

# ---------- المرحلة 5: إنشاء روابط للأوامر ----------
echo ""
echo "🔗 إنشاء روابط للأوامر..."

mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
ln -sf "$INSTALL_DIR/launcher.sh" "$HOME/.local/bin/gt-launcher" 2>/dev/null || true

echo "  ✅ يمكنك الآن استخدام: gtsalat"
echo "  ✅ أو: gt-launcher"

# ---------- المرحلة 6: إعداد التشغيل التلقائي ----------
echo ""
echo "🔧 إعداد التشغيل التلقائي عند الإقلاع..."

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr (Auto-start)
Comment=Start prayer notifications on login
Exec=bash -c 'sleep 20 && cd "$INSTALL_DIR" && ./gt-salat-dikr.sh --notify-start >/dev/null 2>&1 && sleep 10 && python3 ./gt-tray.py >/dev/null 2>&1 &'
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-Delay=20
EOF

echo "✅ تم إعداد التشغيل التلقائي"

# ---------- المرحلة 7: تثبيت مكتبات Python ----------
echo ""
echo "📦 التحقق من مكتبات Python..."

install_python_deps() {
    echo "  🔍 جاري التحقق من مكتبات Python..."
    
    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "  ✅ المكتبات مثبتة بالفعل"
        return 0
    fi
    
    echo "  📥 جاري تثبيت المكتبات (قد يستغرق دقيقة)..."
    
    # محاولة التثبيت بـ pip
    if python3 -m pip install --user pystray pillow 2>/dev/null; then
        echo "  ✅ تم التثبيت باستخدام pip"
        return 0
    fi
    
    # محاولة مع مدير الحزم
    if command -v apt >/dev/null 2>&1; then
        echo "  🔧 محاولة التثبيت باستخدام apt..."
        sudo apt update && sudo apt install -y python3-pystray python3-pil 2>/dev/null && {
            echo "  ✅ تم التثبيت باستخدام apt"
            return 0
        }
    fi
    
    echo "  ⚠️  تعذر تثبيت المكتبات تلقائياً"
    echo "  💡 يمكنك تثبيتها يدوياً لاحقاً:"
    echo "     pip install --user pystray pillow"
    return 1
}

install_python_deps

# ---------- المرحلة 8: بدء الخدمات الآن ----------
echo ""
echo "🚀 بدء تشغيل البرنامج الآن..."

# بدء الإشعارات
echo "🔔 بدء إشعارات الصلاة..."
cd "$INSTALL_DIR"
"$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
sleep 5

# بدء System Tray (بعد تأخير)
echo "🖥️  جاري تشغيل System Tray (قد يستغرق 10 ثواني)..."
bash -c "sleep 10 && cd '$INSTALL_DIR' && python3 gt-tray.py >/dev/null 2>&1 &" &

# ---------- المرحلة 9: الرسالة النهائية الترحيبية ----------
echo ""
echo "══════════════════════════════════════════════════════════════════════════════"
show_header
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 مبروك! تم تثبيت GT-salat-dikr بنجاح 🎉"
echo ""
echo "✨ الميزات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ 1. واجهة مستخدم محسنة مع رسائل تقدم"
echo "✅ 2. أيقونة في قسمي: التعليم والأدوات"
echo "✅ 3. System Tray يظهر خلال 5-10 ثواني"
echo "✅ 4. تشغيل تلقائي عند إقلاع النظام"
echo "✅ 5. Launcher ذكي يمنع التكرار"
echo "✅ 6. ملف إلغاء تثبيت جاهز: $UNINSTALLER"
echo "✅ 7. إشعارات الصلاة والأذكار التلقائية"
echo "✅ 8. أوامر سريعة: gtsalat و gt-launcher"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 كيفية البدء:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. 🔍 ابحث عن 'GT-salat-dikr' في قائمة البرامج"
echo "2. 🖱️  انقر عليه (سيظهر نافذة مع رسالة تقدم)"
echo "3. ⏳ انتظر 5-10 ثواني حتى تظهر الأيقونة"
echo "4. 📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔧 عند النقر على الأيقونة ستظهر:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "╔══════════════════════════════════════╗"
echo "║      🕌 GT-salat-dikr                ║"
echo "║      ════════════════════════       ║"
echo "║      جاري تشغيل System Tray...      ║"
echo "║      ⏳ الرجاء الانتظار 5-10 ثواني  ║"
echo "║      ...                            ║"
echo "╚══════════════════════════════════════╝"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📁 الملفات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "📍 المثبت:      $INSTALL_DIR/"
echo "📍 Launcher:    $LAUNCHER_FILE"
echo "📍 System Tray: $TRAY_SCRIPT"
echo "📍 إلغاء تثبيت: $UNINSTALLER"
echo "📍 الإعدادات:   $CONFIG_FILE"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔄 لإلغاء التثبيت:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "bash $UNINSTALLER"
echo "أو"
echo "gtsalat --uninstall"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📞 الدعم والمساعدة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• اكتب 'gtsalat --help' لرؤية جميع الأوامر"
echo "• استخدم 'gt-launcher' لفتح واجهة التحكم"
echo "• للأسئلة: راجع صفحة المشروع على GitHub"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🕌 جعل الله هذا العمل في ميزان حسناتنا جميعاً"
echo "📅 $(date)"
echo ""
