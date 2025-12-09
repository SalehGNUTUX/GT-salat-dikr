#!/bin/bash
#
# GT-salat-dikr Complete Installation v3.2.5
# تثبيت كامل متوافق مع جميع بيئات سطح المكتب
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
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.5 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     مرحباً بك في تثبيت GT-salat-dikr!"
echo "     متوافق مع GNOME, KDE, XFCE, LXDE, MATE وغيرها"
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
UNIVERSAL_LAUNCHER="$INSTALL_DIR/launcher-universal.sh"
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
# GT-salat-dikr Launcher v2.1
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

# ---------- المرحلة 4: إنشاء Launcher عالمي متوافق مع جميع بيئات سطح المكتب ----------
echo ""
echo "🌍 إنشاء Launcher عالمي متوافق مع جميع بيئات سطح المكتب..."

cat > "$UNIVERSAL_LAUNCHER" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Universal Launcher v1.0
# يعمل على GNOME, KDE, XFCE, LXDE, MATE, وغيرها
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# دالة للعثور على terminal مناسب
find_terminal() {
    echo -e "${BLUE}🔍 البحث عن terminal مناسب لبيئتك...${NC}"
    
    # قائمة بالـ terminals المدعومة مرتبة حسب الشعبية
    declare -A terminals=(
        # GNOME/Ubuntu
        ["gnome-terminal"]="gnome-terminal -- bash -c"
        # KDE
        ["konsole"]="konsole -e bash -c"
        # XFCE
        ["xfce4-terminal"]="xfce4-terminal -e bash -c"
        # MATE
        ["mate-terminal"]="mate-terminal -e bash -c"
        # LXDE
        ["lxterminal"]="lxterminal -e bash -c"
        # عام
        ["terminator"]="terminator -e bash -c"
        ["xterm"]="xterm -e bash -c"
        ["st"]="st -e bash -c"
        ["alacritty"]="alacritty -e bash -c"
        ["kitty"]="kitty bash -c"
    )
    
    # أولاً: اكتشاف بيئة سطح المكتب
    local desktop_env=""
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        desktop_env="$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        desktop_env="$DESKTOP_SESSION"
    fi
    
    echo -e "${PURPLE}📊 بيئة سطح المكتب: ${desktop_env:-غير معروفة}${NC}"
    
    # تحديد terminals مفضلة حسب البيئة
    case "$desktop_env" in
        *GNOME*|*Ubuntu*|*ubuntu*)
            local preferred=("gnome-terminal" "terminator" "xterm")
            ;;
        *KDE*|*Plasma*)
            local preferred=("konsole" "xterm" "gnome-terminal")
            ;;
        *XFCE*)
            local preferred=("xfce4-terminal" "xterm" "terminator")
            ;;
        *MATE*)
            local preferred=("mate-terminal" "xterm" "gnome-terminal")
            ;;
        *LXDE*|*LXQt*)
            local preferred=("lxterminal" "xterm" "terminator")
            ;;
        *)
            local preferred=("xterm" "gnome-terminal" "konsole" "xfce4-terminal")
            ;;
    esac
    
    # البحث في المفضلة أولاً
    for term in "${preferred[@]}"; do
        if command -v "$term" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ تم العثور على: $term${NC}"
            echo "${terminals[$term]}"
            return 0
        fi
    done
    
    # البحث في جميع terminals
    for term in "${!terminals[@]}"; do
        if command -v "$term" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ تم العثور على: $term${NC}"
            echo "${terminals[$term]}"
            return 0
        fi
    done
    
    # إذا لم يعثر على أي terminal
    echo -e "${YELLOW}⚠️  لم يتم العثور على terminal مناسب${NC}"
    echo ""
    return 1
}

# دالة لبدء البرنامج
launch_gt_salat() {
    local terminal_cmd=$(find_terminal)
    
    if [ -z "$terminal_cmd" ]; then
        # لا يوجد terminal، تشغيل مباشرة
        echo -e "${YELLOW}📱 جاري التشغيل في النافذة الحالية...${NC}"
        echo ""
        cd "$INSTALL_DIR"
        ./launcher.sh
        echo ""
        echo "════════════════════════════════════════════════════════"
        read -p "اضغط Enter للإغلاق... "
    else
        # استخدم الـ terminal المناسب
        echo -e "${GREEN}🚀 جاري تشغيل GT-salat-dikr...${NC}"
        echo ""
        
        # بناء أمر التشغيل
        local launch_cmd="cd '$INSTALL_DIR' && ./launcher.sh"
        
        # تنفيذ مع terminal مناسب
        if [[ "$terminal_cmd" == "gnome-terminal -- bash -c" ]]; then
            gnome-terminal -- bash -c "$launch_cmd; echo; echo '════════════════════════════════════════════════════════'; echo 'النافذة ستُغلق تلقائياً خلال 10 ثواني...'; sleep 10"
        elif [[ "$terminal_cmd" == "konsole -e bash -c" ]]; then
            konsole -e bash -c "$launch_cmd; echo; echo '════════════════════════════════════════════════════════'; echo 'اضغط Enter للإغلاق...'; read"
        elif [[ "$terminal_cmd" == "xfce4-terminal -e bash -c" ]]; then
            xfce4-terminal -e bash -c "$launch_cmd; echo; echo '════════════════════════════════════════════════════════'; echo 'اضغط Enter للإغلاق...'; read"
        elif [[ "$terminal_cmd" == "xterm -e bash -c" ]]; then
            xterm -e bash -c "$launch_cmd; echo; echo '════════════════════════════════════════════════════════'; echo 'النافذة ستُغلق تلقائياً خلال 10 ثواني...'; sleep 10"
        else
            # للـ terminals الأخرى
            eval "$terminal_cmd \"$launch_cmd; echo; echo '════════════════════════════════════════════════════════'; echo 'اضغط Enter للإغلاق...'; read\""
        fi
    fi
}

# عرض رسالة ترحيبية
show_welcome() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"

      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
                                                                
EOF
    echo -e "${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   GT-salat-dikr - Launcher عالمي${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📌 هذا Launcher يعمل على:${NC}"
    echo -e "   • GNOME / Ubuntu"
    echo -e "   • KDE Plasma"
    echo -e "   • XFCE"
    echo -e "   • MATE"
    echo -e "   • LXDE / LXQt"
    echo -e "   • وأي بيئة أخرى"
    echo ""
}

# الدالة الرئيسية
main() {
    show_welcome
    launch_gt_salat
}

# بدء البرنامج
main

exit 0
EOF

chmod +x "$UNIVERSAL_LAUNCHER"

# ---------- المرحلة 5: إنشاء ملف .desktop عالمي ----------
echo ""
echo "🖥️  إنشاء ملف تطبيق عالمي في قائمة البرامج..."

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GT-salat-dikr
GenericName=Prayer Times & Azkar Notifications
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=bash -c "cd '$INSTALL_DIR' && ./launcher-universal.sh"
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
    "$HOME/Desktop/gt-salat-dikr.desktop"
)

for location in "${DESKTOP_LOCATIONS[@]}"; do
    mkdir -p "$(dirname "$location")"
    cp "$DESKTOP_FILE" "$location" 2>/dev/null && echo "  ✅ تم النسخ إلى: $(dirname "$location")"
done

# محاولة النسخ إلى مجلد النظام (إذا كان هناك صلاحيات)
if [ -w "/usr/share/applications/" ]; then
    sudo cp "$DESKTOP_FILE" "/usr/share/applications/gt-salat-dikr.desktop" 2>/dev/null && \
    echo "  ✅ تم النسخ إلى: /usr/share/applications/"
fi

# تحديث قاعدة بيانات التطبيقات
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
echo "  ✅ تم تحديث قائمة التطبيقات"

# ---------- المرحلة 6: إنشاء روابط للأوامر ----------
echo ""
echo "🔗 إنشاء روابط للأوامر..."

mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
ln -sf "$INSTALL_DIR/launcher.sh" "$HOME/.local/bin/gt-launcher" 2>/dev/null || true
ln -sf "$INSTALL_DIR/launcher-universal.sh" "$HOME/.local/bin/gt-salat-launcher" 2>/dev/null || true

echo "  ✅ الأوامر المتاحة الآن:"
echo "     • gtsalat           - البرنامج الرئيسي"
echo "     • gt-launcher       - واجهة التحكم"
echo "     • gt-salat-launcher - Launcher عالمي"

# ---------- المرحلة 7: إعداد التشغيل التلقائي ----------
echo ""
echo "🔧 إعداد التشغيل التلقائي عند الإقلاع..."

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr (Auto-start)
Comment=Start prayer notifications on login
Exec=bash -c 'sleep 25 && cd "$INSTALL_DIR" && ./gt-salat-dikr.sh --notify-start >/dev/null 2>&1 && sleep 15 && python3 ./gt-tray.py >/dev/null 2>&1 &'
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-Delay=25
EOF

# إعداد لـ KDE أيضًا
if [ -d "$HOME/.config/plasma-workspace/env" ]; then
    cat > "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" <<'EOF'
#!/bin/bash
sleep 30
cd "$HOME/.GT-salat-dikr"
./gt-salat-dikr.sh --notify-start >/dev/null 2>&1 &
sleep 20
python3 ./gt-tray.py >/dev/null 2>&1 &
EOF
    chmod +x "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh"
    echo "  ✅ تم إعداد التشغيل التلقائي لـ KDE Plasma"
fi

echo "✅ تم إعداد التشغيل التلقائي"

# ---------- المرحلة 8: تثبيت مكتبات Python ----------
echo ""
echo "📦 التحقق من مكتبات Python..."

install_python_deps() {
    echo "  🔍 جاري التحقق من مكتبات Python..."
    
    # التحقق من Python3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  ⚠️  Python3 غير مثبت"
        echo "  💡 جاري التثبيت..."
        
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3 python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm python python-pip
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3 python3-pip
        else
            echo "  ❌ تعذر تثبيت Python3 تلقائياً"
            return 1
        fi
    fi
    
    # التحقق من المكتبات
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
    echo "  أو"
    echo "     sudo apt install python3-pystray python3-pil"
    return 1
}

install_python_deps

# ---------- المرحلة 9: بدء الخدمات الآن ----------
echo ""
echo "🚀 بدء تشغيل البرنامج الآن..."

# بدء الإشعارات
echo "🔔 بدء إشعارات الصلاة..."
cd "$INSTALL_DIR"
"$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
sleep 5

# بدء System Tray (بعد تأخير)
echo "🖥️  جاري تشغيل System Tray (قد يستغرق 10-15 ثواني)..."
bash -c "sleep 12 && cd '$INSTALL_DIR' && python3 gt-tray.py >/dev/null 2>&1 &" &

# ---------- المرحلة 10: الرسالة النهائية الترحيبية ----------
sleep 3
clear
show_header
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 مبروك! تم تثبيت GT-salat-dikr بنجاح 🎉"
echo ""
echo "✨ الميزات المثبتة في الإصدار 3.2.5:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ 1. Launcher عالمي - يعمل على جميع بيئات سطح المكتب"
echo "✅ 2. واجهة مستخدم محسنة مع رسائل تقدم جميلة"
echo "✅ 3. أيقونة في قسمي: التعليم (Education) والأدوات (Utility)"
echo "✅ 4. System Tray يظهر مع رسالة:"
echo "    ╔══════════════════════════════════════╗"
echo "    ║      🕌 GT-salat-dikr                ║"
echo "    ║      ════════════════════════       ║"
echo "    ║      جاري تشغيل System Tray...      ║"
echo "    ║      ⏳ الرجاء الانتظار 5-10 ثواني  ║"
echo "    ║      ...                            ║"
echo "    ╚══════════════════════════════════════╝"
echo "✅ 5. تشغيل تلقائي عند إقلاع النظام"
echo "✅ 6. متوافق مع: GNOME, KDE, XFCE, LXDE, MATE وغيرها"
echo "✅ 7. ملف إلغاء تثبيت جاهز"
echo "✅ 8. إشعارات الصلاة والأذكار التلقائية"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 كيفية البدء:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. 🔍 ابحث عن 'GT-salat-dikr' في قائمة البرامج"
echo "   (ستجده في قسمي: Education و Utility)"
echo "2. 🖱️  انقر على الأيقونة - ستعمل على أي بيئة سطح مكتب"
echo "3. ⏳ انتظر 5-10 ثواني حتى تظهر رسالة التقدم"
echo "4. 📌 ابحث عن الأيقونة في شريط المهام"
echo "5. 🖱️  انقر بزر الماوس الأيمن على الأيقونة للتحكم"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔧 الأوامر المتاحة في الطرفية:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "gtsalat                    # عرض ذكر وموعد الصلاة"
echo "gtsalat --status          # حالة البرنامج"
echo "gtsalat --show-timetable  # مواقيت اليوم"
echo "gtsalat --settings        # تعديل الإعدادات"
echo "gt-launcher               # واجهة التحكم الرئيسية"
echo "gt-salat-launcher         # Launcher عالمي (لجميع البيئات)"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📁 الملفات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "📍 المثبت:           $INSTALL_DIR/"
echo "📍 Launcher:         $LAUNCHER_FILE"
echo "📍 Launcher عالمي:  $UNIVERSAL_LAUNCHER"
echo "📍 System Tray:      $TRAY_SCRIPT"
echo "📍 إلغاء تثبيت:      $UNINSTALLER"
echo "📍 الإعدادات:        $CONFIG_FILE"
echo "📍 أيقونة القائمة:   $HOME/.local/share/applications/gt-salat-dikr.desktop"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔄 لإلغاء التثبيت:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "bash $UNINSTALLER"
echo "أو"
echo "gtsalat --uninstall"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🌍 التوافق:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• ✅ GNOME / Ubuntu / Debian"
echo "• ✅ KDE Plasma / Kubuntu"
echo "• ✅ XFCE / Xubuntu"
echo "• ✅ MATE / Ubuntu MATE"
echo "• ✅ LXDE / LXQt / Lubuntu"
echo "• ✅ أي بيئة سطح مكتب أخرى"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📞 الدعم والمصادر:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• 📖 المستودع: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo "• 🐛 الإبلاغ عن مشاكل: نفس الرابط في Issues"
echo "• 💡 اقتراح ميزات: نرحب بمساهمتك!"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🕐 النظام سيعمل خلال ثواني..."
echo "⚠️  قد تحتاج إلى إعادة تسجيل الدخول أو إعادة التشغيل للتطبيق الكامل"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

# إظهار مؤشر تقدم نهائي
echo -n "🏁 جاري الإنهاء "
for i in {1..10}; do
    echo -n "."
    sleep 0.3
done
echo " ✅"

# تنظيف مؤقت
rm -f /tmp/gt-*.tmp 2>/dev/null || true

# اختبار سريع نهائي
echo ""
echo "🔍 اختبار سريع للنظام:"
echo "══════════════════════════════════════════════════════════════════════════════"

# اختبار الأوامر
TEST_COMMANDS=("gtsalat" "gt-launcher")
for cmd in "${TEST_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "✅ $cmd - جاهز للاستخدام"
    else
        echo -e "⚠️  $cmd - جرب إعادة فتح الطرفية أو: source ~/.bashrc"
    fi
done

# اختبار ملفات
echo ""
echo "📁 التحقق من الملفات الرئيسية:"
if [ -f "$INSTALL_DIR/$MAIN_SCRIPT" ]; then
    echo -e "✅ الملف الرئيسي - موجود"
else
    echo -e "❌ الملف الرئيسي - مفقود"
fi

if [ -f "$TRAY_SCRIPT" ]; then
    echo -e "✅ System Tray - موجود"
else
    echo -e "❌ System Tray - مفقود"
fi

if [ -f "$UNIVERSAL_LAUNCHER" ]; then
    echo -e "✅ Launcher عالمي - موجود"
else
    echo -e "❌ Launcher عالمي - مفقود"
fi

# التحقق من أيقونة القائمة
if [ -f "$HOME/.local/share/applications/gt-salat-dikr.desktop" ]; then
    echo -e "✅ أيقونة القائمة - موجودة"
    echo -e "   📍 الموقع: $HOME/.local/share/applications/gt-salat-dikr.desktop"
else
    echo -e "⚠️  أيقونة القائمة - مفقودة، يمكنك إنشاؤها يدوياً"
fi

echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

# إنشاء ملف اختصار للمستخدم
cat > "$HOME/دليل-استخدام-GT-salat-dikr.txt" <<EOF
══════════════════════════════════════════════════════════════
            🕌 دليل استخدام GT-salat-dikr 🕋
══════════════════════════════════════════════════════════════

🔰 المقدمة
تم تثبيت GT-salat-dikr بنجاح! هذا البرنامج سيساعدك على:
• تذكر مواقيت الصلاة تلقائياً
• عرض الأذكار المأثورة كل 10 دقائق
• التنبيه قبل الصلاة بـ 15 دقيقة
• العمل بدون اتصال بالإنترنت

📁 الملفات المثبتة
📍 المثبت: $INSTALL_DIR/
📍 Launcher عالمي: $UNIVERSAL_LAUNCHER
📍 System Tray: $TRAY_SCRIPT
📍 إلغاء تثبيت: $UNINSTALLER

🚀 كيفية البدء
1. افتح قائمة التطبيقات
2. ابحث عن "GT-salat-dikr"
3. انقر على الأيقونة
4. انتظر 5-10 ثواني

أو استخدم الأوامر التالية في الطرفية:
gtsalat                    # عرض ذكر وموعد الصلاة
gt-launcher               # واجهة التحكم
gt-salat-launcher         # Launcher عالمي

🔧 الأوامر الرئيسية
gtsalat --status          # حالة البرنامج
gtsalat --show-timetable  # مواقيت اليوم
gtsalat --settings        # تعديل الإعدادات
gtsalat --notify-stop     # إيقاف الإشعارات
gtsalat --notify-start    # بدء الإشعارات

🖥️ System Tray
• ستظهر أيقونة في شريط المهام
• انقر بزر الماوس الأيمن للتحكم
• يمكنك إخفاء/إظهار الإشعارات
• التحكم في مستوى الصوت

⚙️ الإعدادات الافتراضية
• فاصل الأذكار: 10 دقائق
• تنبيه قبل الصلاة: 15 دقيقة
• تحديث تلقائي: 2 صباحاً كل يوم
• الأذان: الصوت الكامل

🗑️ لإلغاء التثبيت
bash $UNINSTALLER
أو
gtsalat --uninstall

📞 الدعم
https://github.com/SalehGNUTUX/GT-salat-dikr

تم التثبيت بتاريخ: $(date)
══════════════════════════════════════════════════════════════
EOF

echo "📄 تم إنشاء دليل الاستخدام في: $HOME/دليل-استخدام-GT-salat-dikr.txt"
echo ""

# اقتراح الخطوة التالية
echo "💡 الخطوة التالية المقترحة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. أعد فتح الطرفية أو تشغيل: source ~/.bashrc"
echo "2. افتح قائمة التطبيقات وابحث عن 'GT-salat-dikr'"
echo "3. انقر على الأيقونة لبدء الاستخدام"
echo "4. إذا لم تظهر الأيقونة، جرب: gt-salat-launcher"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

# نصائح نهائية
echo "✨ نصائح مهمة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• إذا كنت تستخدم KDE Plasma، ابحث في 'التعليم' أو 'الأدوات'"
echo "• إذا كنت تستخدم GNOME، اكتب 'GT-salat' في شريط البحث"
echo "• System Tray سيظهر بعد 15-20 ثانية من التشغيل"
echo "• يمكنك إعادة تثبيت مكتبات Python لاحقاً إذا احتاج الأمر"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

# سجل التثبيت
LOG_FILE="$INSTALL_DIR/install.log"
echo "==================================================" >> "$LOG_FILE"
echo "تثبيت جديد - $(date)" >> "$LOG_FILE"
echo "الإصدار: 3.2.5" >> "$LOG_FILE"
echo "المسار: $INSTALL_DIR" >> "$LOG_FILE"
echo "المستخدم: $USER" >> "$LOG_FILE"
echo "التوزيعة: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)" >> "$LOG_FILE"
echo "==================================================" >> "$LOG_FILE"

# رسالة وداع فنية
cat << "EOF"

      ╔══════════════════════════════════════╗
      ║                                      ║
      ║   🎊 تم التثبيت بنجاح! 🎊           ║
      ║                                      ║
      ║   استمتع بتجربة GT-salat-dikr       ║
      ║   ولا تنسنا من دعائك!               ║
      ║                                      ║
      ║   مع تحيات:                         ║
      ║   فريق GT-salat-dikr                ║
      ║                                      ║
      ╚══════════════════════════════════════╝

📞 تابعنا للمزيد من التطويرات: https://github.com/SalehGNUTUX

EOF

# اقتراح الاختبار الفوري
read -p "هل تريد اختبار البرنامج الآن؟ (y/n): " test_now
if [[ "$test_now" =~ ^[Yy]$ ]]; then
    echo "🔄 جاري تشغيل اختبار سريع..."
    sleep 2
    
    # اختبار Launcher
    if [ -f "$UNIVERSAL_LAUNCHER" ]; then
        echo "🚀 تشغيل Launcher عالمي..."
        timeout 5 bash "$UNIVERSAL_LAUNCHER" || echo "⚠️  تم إيقاف الاختبار بعد 5 ثواني"
    else
        echo "⚠️  لا يمكن العثور على Launcher"
    fi
fi

echo ""
echo "👋 مع السلامة! يمكنك الخروج الآن."
echo "💡 تذكر: إعادة تشغيل الطرفية قد تكون ضرورية للأوامر الجديدة."

exit 0
