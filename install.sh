#!/bin/bash
#
# GT-salat-dikr Installation v3.2.8
# إصلاح شامل: مواقيت الصلاة + تكرار الإعداد + تكرار الأيقونة
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
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.8 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     تثبيت GT-salat-dikr - الإصدار المحسّن 3.2.8"
echo "     إصلاح: الإعدادات + المواقيت + تكرار الأيقونة"
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
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
DESKTOP_FILE="$INSTALL_DIR/gt-salat-dikr.desktop"
LAUNCHER_FILE="$INSTALL_DIR/launcher.sh"
UNIVERSAL_LAUNCHER="$INSTALL_DIR/launcher-universal.sh"
UNINSTALLER="$INSTALL_DIR/uninstall.sh"
CONFIG_FILE="$INSTALL_DIR/.gtsalat_config"

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

# ---------- المرحلة 3: إنشاء script محسن لعرض الذكر والصلاة ----------
echo ""
echo "🔧 إنشاء script محسن لعرض الذكر والصلاة..."

cat > "$INSTALL_DIR/show-prayer.sh" << 'EOF'
#!/bin/bash
#
# show-prayer.sh - عرض منسق للذكر والصلاة
# تنسيق موحد يعمل في جميع الحالات
#

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"
CONFIG_FILE="$INSTALL_DIR/.gtsalat_config"

# دالة للتحقق من إتمام الإعداد
is_configured() {
    [ -f "$CONFIG_FILE" ] && \
    grep -q "LOCATION_CONFIGURED=true" "$CONFIG_FILE" 2>/dev/null && \
    grep -q "METHOD_CONFIGURED=true" "$CONFIG_FILE" 2>/dev/null
}

# دالة لجلب مواقيت الصلاة
get_prayer_times() {
    if [ -f "$MAIN_SCRIPT" ] && is_configured; then
        # محاولة الحصول على مواقيت اليوم من البرنامج الرئيسي
        TIMES_OUTPUT=$("$MAIN_SCRIPT" --show-timetable 2>/dev/null)
        
        if [ -n "$TIMES_OUTPUT" ]; then
            # البحث عن الصلاة القادمة
            NEXT_LINE=$(echo "$TIMES_OUTPUT" | grep -E "(🕌 الصلاة القادمة|القادمة:)" | head -1)
            
            if [ -n "$NEXT_LINE" ]; then
                echo "$NEXT_LINE"
                return 0
            fi
        fi
    fi
    
    # إذا لم يتم الإعداد
    if ! is_configured; then
        echo "⚙️  قم بإعداد البرنامج أولاً: gtsalat --setup"
    else
        echo "🔄 جاري تحميل مواقيت الصلاة..."
    fi
    return 1
}

# بدء العرض
echo ""
echo "🕌 GT-salat-dikr 🕋 ﷽"
echo "══════════════════════════════════════"

# عرض ذكر عشوائي
if [ -f "$INSTALL_DIR/azkar.txt" ]; then
    if [ -s "$INSTALL_DIR/azkar.txt" ]; then
        TOTAL_LINES=$(wc -l < "$INSTALL_DIR/azkar.txt" 2>/dev/null || echo "0")
        if [ "$TOTAL_LINES" -gt 0 ]; then
            RANDOM_LINE=$((RANDOM % TOTAL_LINES + 1))
            AZKAR=$(sed -n "${RANDOM_LINE}p" "$INSTALL_DIR/azkar.txt")
            
            # عرض الذكر - إزالة أي "═" في البداية والنهاية
            CLEAN_AZKAR=$(echo "$AZKAR" | sed 's/^═*//; s/═*$//')
            echo "$CLEAN_AZKAR"
            echo "══════════════════════════════════════"
        fi
    fi
fi

# عرض مواقيت الصلاة
get_prayer_times

echo ""
EOF

chmod +x "$INSTALL_DIR/show-prayer.sh"

# ---------- المرحلة 4: إنشاء script إضافي لعرض الذكر من System Tray ----------
echo ""
echo "🔧 إنشاء script لعرض الذكر من System Tray..."

cat > "$INSTALL_DIR/show-azkar-tray.sh" << 'EOF'
#!/bin/bash
#
# show-azkar-tray.sh - عرض الذكر من System Tray
# نفس التنسيق لكن مع عنوان مختلف
#

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"
CONFIG_FILE="$INSTALL_DIR/.gtsalat_config"

# دالة للتحقق من إتمام الإعداد
is_configured() {
    [ -f "$CONFIG_FILE" ] && \
    grep -q "LOCATION_CONFIGURED=true" "$CONFIG_FILE" 2>/dev/null && \
    grep -q "METHOD_CONFIGURED=true" "$CONFIG_FILE" 2>/dev/null
}

# دالة لجلب مواقيت الصلاة
get_prayer_times() {
    if [ -f "$MAIN_SCRIPT" ] && is_configured; then
        TIMES_OUTPUT=$("$MAIN_SCRIPT" --show-timetable 2>/dev/null)
        
        if [ -n "$TIMES_OUTPUT" ]; then
            NEXT_LINE=$(echo "$TIMES_OUTPUT" | grep -E "(🕌 الصلاة القادمة|القادمة:)" | head -1)
            
            if [ -n "$NEXT_LINE" ]; then
                echo "$NEXT_LINE"
                return 0
            fi
        fi
    fi
    
    if ! is_configured; then
        echo "⚙️  قم بإعداد البرنامج أولاً من أيقونة شريط المهام"
    fi
    return 1
}

# بدء العرض
clear
echo ""
echo "ذكر اليوم"
echo "══════════════════════════════════════════════════"

# عرض ذكر عشوائي
if [ -f "$INSTALL_DIR/azkar.txt" ]; then
    if [ -s "$INSTALL_DIR/azkar.txt" ]; then
        TOTAL_LINES=$(wc -l < "$INSTALL_DIR/azkar.txt" 2>/dev/null || echo "0")
        if [ "$TOTAL_LINES" -gt 0 ]; then
            RANDOM_LINE=$((RANDOM % TOTAL_LINES + 1))
            AZKAR=$(sed -n "${RANDOM_LINE}p" "$INSTALL_DIR/azkar.txt")
            
            # عرض الذكر - إزالة أي "═" في البداية والنهاية
            CLEAN_AZKAR=$(echo "$AZKAR" | sed 's/^═*//; s/═*$//')
            echo "$CLEAN_AZKAR"
            echo ""
        fi
    fi
fi

# عرض مواقيت الصلاة
if get_prayer_times; then
    echo ""
fi

echo "══════════════════════════════════════════════════"
echo ""
read -p "اضغط Enter للإغلاق... "
EOF

chmod +x "$INSTALL_DIR/show-azkar-tray.sh"

# ---------- المرحلة 5: إضافة إلى جميع ملفات التهيئة للطرفيات ----------
echo ""
echo "🔧 إضافة عرض الذكر إلى جميع أنواع الطرفيات..."

setup_terminal_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # تنظيف الإعدادات القديمة
        sed -i '/^# GT-salat-dikr/,/^fi$/d' "$shell_file" 2>/dev/null || true
        sed -i '/alias gtsalat=/d' "$shell_file" 2>/dev/null || true
        sed -i '/GT-salat-dikr/d' "$shell_file" 2>/dev/null || true
        
        # إضافة الإعدادات الجديدة
        echo "" >> "$shell_file"
        echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$shell_file"
        echo "if [ -f \"$INSTALL_DIR/show-prayer.sh\" ]; then" >> "$shell_file"
        echo "    . \"$INSTALL_DIR/show-prayer.sh\"" >> "$shell_file"
        echo "fi" >> "$shell_file"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى $shell_name"
    else
        echo "⚠️  ملف $shell_name غير موجود، تخطي الإعدادات"
    fi
}

# 1. لـ bash
setup_terminal_config "$HOME/.bashrc" ".bashrc"

# 2. لـ zsh
setup_terminal_config "$HOME/.zshrc" ".zshrc"

# 3. لـ fish
if command -v fish >/dev/null 2>&1 && [ -d "$HOME/.config/fish" ]; then
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$HOME/.config/fish"
    
    # تنظيف الإعدادات القديمة
    if [ -f "$FISH_CONFIG" ]; then
        sed -i '/# GT-salat-dikr/,/^end$/d' "$FISH_CONFIG" 2>/dev/null || true
    fi
    
    # إضافة الإعدادات الجديدة
    echo "" >> "$FISH_CONFIG"
    echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$FISH_CONFIG"
    echo "if test -f \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
    echo "    bash \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
    echo "end" >> "$FISH_CONFIG"
    echo "  ✅ تم الإضافة إلى fish config"
fi

# ---------- المرحلة 6: إنشاء Launcher محسّن مع منع التكرار ----------
echo ""
echo "🔧 إنشاء مُشغّل ذكي مع منع التكرار..."

cat > "$LAUNCHER_FILE" << 'EOF'
#!/bin/bash
#
# GT-salat-dikr Launcher - النسخة المحسنة مع منع التكرار
#

INSTALL_DIR="$(dirname "$(realpath "$0")")"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
PID_FILE="/tmp/gt-salat-tray.pid"

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# التحقق من وجود عملية قيد التشغيل
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  GT-salat-dikr System Tray يعمل بالفعل!${NC}"
        echo -e "${YELLOW}📌 يمكنك إيجاد الأيقونة 🕌 في شريط المهام${NC}"
        echo ""
        read -p "اضغط Enter للإغلاق... "
        exit 0
    else
        # حذف ملف PID القديم
        rm -f "$PID_FILE"
    fi
fi

clear
echo -e "${BLUE}"
cat << "LOGO"
┌─────────────────────────────────────────┐
│        🕌 GT-salat-dikr 🕋             │
│     نظام إشعارات الصلاة والأذكار       │
└─────────────────────────────────────────┘
LOGO
echo -e "${NC}"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           جاري تشغيل النظام...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# التحقق من Python ومكتباته
echo -e "${YELLOW}🔍 التحقق من متطلبات النظام...${NC}"

PYTHON_OK=true
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}❌ Python3 غير مثبت${NC}"
    PYTHON_OK=false
else
    echo -e "${GREEN}✅ Python3 مثبت${NC}"
    
    # التحقق من المكتبات
    if ! python3 -c "import pystray, PIL" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  مكتبات Python غير مثبتة${NC}"
        PYTHON_OK=false
    else
        echo -e "${GREEN}✅ مكتبات Python جاهزة${NC}"
    fi
fi

# تشغيل System Tray إذا كان كل شيء جاهزاً
if [ "$PYTHON_OK" = true ]; then
    echo ""
    echo -e "${YELLOW}🚀 جاري تشغيل System Tray...${NC}"
    echo -e "${BLUE}⏳ الرجاء الانتظار 3 ثواني...${NC}"
    
    # تشغيل System Tray في الخلفية
    cd "$INSTALL_DIR"
    nohup python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    TRAY_PID=$!
    
    # حفظ PID
    echo $TRAY_PID > "$PID_FILE"
    
    # عرض مؤشر تقدم
    echo -ne "${GREEN}"
    for i in {1..3}; do
        echo -n "█"
        sleep 1
    done
    echo -e "${NC}"
    
    # التحقق من العملية
    sleep 1
    if kill -0 $TRAY_PID 2>/dev/null; then
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ تم التشغيل بنجاح!${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}📌 ماذا يمكنك أن تفعل الآن:${NC}"
        echo -e "1. 🔍 ابحث عن أيقونة 🕌 في شريط المهام"
        echo -e "2. 🖱️  انقر بزر الماوس الأيمن على الأيقونة للتحكم"
        echo -e "3. ⚙️  اختر 'إعدادات' لإعداد الموقع ومواقيت الصلاة"
        echo ""
    else
        echo -e "${YELLOW}⚠️  System Tray توقف عن العمل${NC}"
        rm -f "$PID_FILE"
    fi
else
    echo ""
    echo -e "${YELLOW}⚠️  System Tray غير متاح${NC}"
    echo -e "${YELLOW}💡 يمكنك تثبيت Python3 والمكتبات لاحقاً${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💡 النافذة ستُغلق تلقائياً خلال 5 ثواني...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

sleep 5
exit 0
EOF

chmod +x "$LAUNCHER_FILE"

# ---------- المرحلة 7: إنشاء Universal Launcher ----------
echo ""
echo "🌍 إنشاء Launcher عالمي..."

cat > "$UNIVERSAL_LAUNCHER" << 'EOF'
#!/bin/bash
#
# GT-salat-dikr Universal Launcher
#

INSTALL_DIR="$(dirname "$(realpath "$0")")"

# تحديد terminal المناسب
TERMINAL_CMD=""
if command -v gnome-terminal >/dev/null 2>&1; then
    TERMINAL_CMD="gnome-terminal -- bash -c"
elif command -v konsole >/dev/null 2>&1; then
    TERMINAL_CMD="konsole -e bash -c"
elif command -v xterm >/dev/null 2>&1; then
    TERMINAL_CMD="xterm -e bash -c"
elif command -v xfce4-terminal >/dev/null 2>&1; then
    TERMINAL_CMD="xfce4-terminal -e bash -c"
elif command -v mate-terminal >/dev/null 2>&1; then
    TERMINAL_CMD="mate-terminal -e bash -c"
elif command -v lxterminal >/dev/null 2>&1; then
    TERMINAL_CMD="lxterminal -e bash -c"
elif command -v terminator >/dev/null 2>&1; then
    TERMINAL_CMD="terminator -e bash -c"
fi

if [ -n "$TERMINAL_CMD" ]; then
    $TERMINAL_CMD "cd '$INSTALL_DIR' && ./launcher.sh; sleep 2; exit"
else
    cd "$INSTALL_DIR"
    ./launcher.sh
fi

exit 0
EOF

chmod +x "$UNIVERSAL_LAUNCHER"

# ---------- المرحلة 8: إنشاء ملف .desktop ----------
echo ""
echo "🖥️  إنشاء أيقونة في قائمة البرامج..."

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GT-salat-dikr
GenericName=Prayer Times & Azkar
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=bash -c "cd '$INSTALL_DIR' && ./launcher-universal.sh"
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Terminal=false
Categories=Utility;Education;
Keywords=prayer;islam;azkar;reminder;صلاة;أذكار;إسلام;تذكير;
StartupNotify=false
EOF

# نسخ إلى مواقع .desktop
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/Desktop"

DESKTOP_LOCATIONS=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
)

for location in "${DESKTOP_LOCATIONS[@]}"; do
    cp "$DESKTOP_FILE" "$location" 2>/dev/null && echo "  ✅ تم النسخ إلى: $location"
done

# تحديث قاعدة بيانات التطبيقات
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications/ 2>/dev/null && \
    echo "  ✅ تم تحديث قائمة التطبيقات"
fi

# ---------- المرحلة 9: إنشاء روابط للأوامر مع التحديث اليدوي ----------
echo ""
echo "🔗 إنشاء أوامر سهلة الوصول..."

mkdir -p "$HOME/.local/bin"

# إنشاء wrapper script للبرنامج الرئيسي مع خيار التحديث اليدوي
cat > "$HOME/.local/bin/gtsalat" << 'WRAPPER_EOF'
#!/bin/bash
INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

# خيار التحديث اليدوي
if [ "$1" = "--update" ] || [ "$1" = "update" ]; then
    echo "🔄 جاري تحديث GT-salat-dikr..."
    echo ""
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)"
    exit $?
fi

# تشغيل البرنامج الرئيسي
if [ -f "$MAIN_SCRIPT" ]; then
    bash "$MAIN_SCRIPT" "$@"
else
    echo "❌ GT-salat-dikr غير مثبت!"
    echo "💡 قم بتثبيته باستخدام:"
    echo "   bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
    exit 1
fi
WRAPPER_EOF

chmod +x "$HOME/.local/bin/gtsalat"

# إنشاء الأوامر الأخرى
ln -sf "$LAUNCHER_FILE" "$HOME/.local/bin/gt-launcher" 2>/dev/null || true
ln -sf "$INSTALL_DIR/show-azkar-tray.sh" "$HOME/.local/bin/gt-azkar" 2>/dev/null || true

# إضافة .local/bin إلى PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    [ -f "$HOME/.zshrc" ] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    export PATH="$HOME/.local/bin:$PATH"
    echo "  ✅ تم إضافة $HOME/.local/bin إلى PATH"
fi

# ---------- المرحلة 10: تثبيت مكتبات Python ----------
echo ""
echo "📦 تثبيت مكتبات Python لـ System Tray..."

install_python_deps() {
    echo "  🔍 جاري التحقق من متطلبات Python..."
    
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  📦 تثبيت Python3..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3 python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm python python-pip
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3 python3-pip
        fi
    fi
    
    echo "  📦 تثبيت مكتبات Python..."
    python3 -m pip install --user pystray pillow 2>/dev/null || {
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y python3-pystray python3-pil 2>/dev/null || \
            echo "  ⚠️  يمكنك تثبيتها يدوياً لاحقاً"
        fi
    }
}

echo ""
read -p "هل تريد تثبيت System Tray (أيقونة في شريط المهام)؟ [Y/n]: " install_tray
if [[ "$install_tray" != "n" && "$install_tray" != "N" ]]; then
    install_python_deps
    echo "  ✅ تم تثبيت مكتبات Python"
else
    echo "  ⏭️  تم تخطي تثبيت System Tray"
fi

# ---------- المرحلة 11: إعداد التشغيل التلقائي ----------
echo ""
echo "🔧 إعداد التشغيل التلقائي..."

mkdir -p "$HOME/.config/autostart"

cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" << EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=Start prayer notifications on login
Exec=bash -c 'sleep 15 && gtsalat --notify-start >/dev/null 2>&1'
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
X-GNOME-Autostart-enabled=true
Terminal=false
EOF

echo "  ✅ تم إعداد التشغيل التلقائي"

# ---------- المرحلة 12: بدء الخدمات ----------
echo ""
echo "🚀 بدء تشغيل النظام..."

# بدء إشعارات الصلاة
echo "🔔 بدء إشعارات الصلاة..."
if [ -f "$INSTALL_DIR/$MAIN_SCRIPT" ]; then
    bash "$INSTALL_DIR/$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
    echo "  ✅ تم بدء إشعارات الصلاة"
fi

# بدء System Tray إذا طلب المستخدم
if [[ "$install_tray" != "n" && "$install_tray" != "N" ]] && [ -f "$TRAY_SCRIPT" ]; then
    echo "🖥️  بدء System Tray..."
    
    # التحقق من عدم وجود عملية قيد التشغيل
    PID_FILE="/tmp/gt-salat-tray.pid"
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "  ℹ️  System Tray يعمل بالفعل"
        else
            rm -f "$PID_FILE"
            bash -c "sleep 5 && python3 '$TRAY_SCRIPT' >/dev/null 2>&1 &" &
            echo "  ✅ تم بدء System Tray"
        fi
    else
        bash -c "sleep 5 && python3 '$TRAY_SCRIPT' >/dev/null 2>&1 &" &
        echo "  ✅ تم بدء System Tray"
    fi
fi

# ---------- المرحلة 13: عرض رسالة النجاح ----------
sleep 2
clear
show_header

echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 مبروك! تم تثبيت GT-salat-dikr الإصدار 3.2.8 بنجاح 🎉"
echo ""
echo "✨ الإصلاحات الجديدة في 3.2.8:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ 1. إصلاح عرض مواقيت الصلاة في الطرفية"
echo "✅ 2. منع تكرار أيقونة System Tray في شريط المهام"
echo "✅ 3. إصلاح مشكلة تكرار مراحل الإعداد"
echo "✅ 4. إزالة التحديث التلقائي (استخدم: gtsalat --update)"
echo "✅ 5. تنظيف عرض الذكر من علامات ═ الزائدة"
echo "✅ 6. التحقق من إتمام الإعداد قبل عرض المواقيت"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "⚙️  خطوات مهمة للبدء:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. 🔍 افتح أيقونة 🕌 من شريط المهام (System Tray)"
echo "2. 🖱️  انقر بزر الماوس الأيمن واختر 'إعدادات'"
echo "3. 📍 قم بإعداد الموقع وطريقة حساب الصلاة"
echo "4. ✅ بعد إتمام الإعداد، افتح terminal جديد لرؤية المواقيت"
echo ""
echo "✨ الأوامر المتاحة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "gtsalat                 - البرنامج الرئيسي"
echo "gtsalat --update        - تحديث البرنامج يدوياً"
echo "gtsalat --setup         - إعداد الموقع والمواقيت"
echo "gt-launcher             - تشغيل System Tray"
echo "gt-azkar                - عرض الذكر من الطرفية"
echo ""
echo "🔄 كيفية التحديث:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "لتحديث البرنامج إلى أحدث إصدار، استخدم:"
echo "  gtsalat --update"
echo ""
echo "هذا سيقوم بتحميل وتثبيت جميع المكونات الجديدة من المستودع"
echo ""
echo "📁 الملفات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• $INSTALL_DIR/show-prayer.sh"
echo "• $INSTALL_DIR/show-azkar-tray.sh"
echo "• $INSTALL_DIR/launcher.sh"
echo "• $HOME/.local/bin/gtsalat (مع خيار --update)"
echo ""
echo "💡 ملاحظات مهمة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• لن ترى مواقيت الصلاة حتى تُتم عملية الإعداد الأولى"
echo "• افتح terminal جديد بعد الإعداد لرؤية التحديثات"
echo "• يمكنك تشغيل أيقونة System Tray مرة واحدة فقط"
echo "• استخدم gtsalat --update للتحديث اليدوي"
echo ""
echo "📞 الدعم: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
echo "══════════════════════════════════════════════════════════════════════════════"

# اختبار نهائي
echo ""
read -p "هل تريد اختبار عرض الذكر الآن؟ [Y/n]: " test_azkar
if [[ "$test_azkar" != "n" && "$test_azkar" != "N" ]]; then
    echo ""
    echo "🔍 اختبار عرض الذكر..."
    if [ -f "$INSTALL_DIR/show-prayer.sh" ]; then
        . "$INSTALL_DIR/show-prayer.sh"
    fi
fi

echo ""
echo "👋 تم التثبيت بنجاح!"
echo "⚠️  لا تنسى إعداد الموقع ومواقيت الصلاة من أيقونة شريط المهام!"

exit 0
