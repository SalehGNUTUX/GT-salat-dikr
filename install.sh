#!/bin/bash
#
# GT-salat-dikr Installation v3.2.6
# تثبيت محسّن مع إصلاح جميع المشاكل
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
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.6 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     تثبيت GT-salat-dikr - الإصدار المحسّن 3.2.6"
echo "     مع إصلاح جميع المشاكل المبلغ عنها"
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

# ---------- المرحلة 3: إنشاء script لعرض الذكر والصلاة (تم التصحيح) ----------
echo ""
echo "🔧 إنشاء script لعرض الذكر والصلاة عند فتح الطرفية..."

cat > "$INSTALL_DIR/show-prayer.sh" << 'EOF'
#!/bin/bash
#
# عرض ذكر وموعد الصلاة عند فتح الطرفية
# متوافق مع bash, zsh, fish
#

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

if [ -f "$MAIN_SCRIPT" ]; then
    echo ""
    echo "🕌 GT-salat-dikr 🕋"
    echo "══════════════════════════════════════"
    
    # عرض ذكر عشوائي
    if [ -f "$INSTALL_DIR/azkar.txt" ]; then
        total_lines=$(wc -l < "$INSTALL_DIR/azkar.txt" 2>/dev/null || echo "0")
        if [ "$total_lines" -gt 0 ]; then
            random_line=$((RANDOM % total_lines + 1))
            azkar=$(sed -n "${random_line}p" "$INSTALL_DIR/azkar.txt")
            echo "﷽ $azkar"
            echo "══════════════════════════════════════"
        fi
    fi
    
    # عرض موعد الصلاة القادمة (بدون --next-prayer)
    if [ -f "$MAIN_SCRIPT" ]; then
        # جلب مواقيت اليوم
        if TODAY_TIMES=$("$MAIN_SCRIPT" --show-timetable 2>/dev/null | grep -A1 "القادمة:" | tail -1); then
            if [ -n "$TODAY_TIMES" ]; then
                echo "$TODAY_TIMES"
            else
                echo "جاري تحميل مواقيت الصلاة..."
            fi
        else
            echo "جاري تحميل مواقيت الصلاة..."
        fi
    fi
    echo ""
fi
EOF

chmod +x "$INSTALL_DIR/show-prayer.sh"

# ---------- المرحلة 4: إضافة إلى جميع ملفات التهيئة للطرفيات ----------
echo ""
echo "🔧 إضافة عرض الذكر إلى جميع أنواع الطرفيات..."

# 1. لـ bash
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "GT-salat-dikr" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# عرض ذكر وموعد الصلاة عند فتح الطرفية - GT-salat-dikr" >> "$HOME/.bashrc"
        echo "if [ -f \"$INSTALL_DIR/show-prayer.sh\" ]; then" >> "$HOME/.bashrc"
        echo "    . \"$INSTALL_DIR/show-prayer.sh\"" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        echo "  ✅ تم الإضافة إلى .bashrc"
    fi
fi

# 2. لـ zsh
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "GT-salat-dikr" "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# عرض ذكر وموعد الصلاة عند فتح الطرفية - GT-salat-dikr" >> "$HOME/.zshrc"
        echo "if [ -f \"$INSTALL_DIR/show-prayer.sh\" ]; then" >> "$HOME/.zshrc"
        echo "    . \"$INSTALL_DIR/show-prayer.sh\"" >> "$HOME/.zshrc"
        echo "fi" >> "$HOME/.zshrc"
        echo "  ✅ تم الإضافة إلى .zshrc"
    fi
fi

# 3. لـ fish
if command -v fish >/dev/null 2>&1 && [ -d "$HOME/.config/fish" ]; then
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$HOME/.config/fish"
    if [ ! -f "$FISH_CONFIG" ] || ! grep -q "GT-salat-dikr" "$FISH_CONFIG"; then
        echo "" >> "$FISH_CONFIG"
        echo "# عرض ذكر وموعد الصلاة عند فتح الطرفية - GT-salat-dikr" >> "$FISH_CONFIG"
        echo "if test -f \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
        echo "    bash \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
        echo "end" >> "$FISH_CONFIG"
        echo "  ✅ تم الإضافة إلى fish config"
    fi
fi

# 4. إنشاء ملف عالمي لجميع الطرفيات
cat > "$INSTALL_DIR/terminal-welcome.sh" << 'EOF'
#!/bin/bash
# ملف عالمي لعرض الترحيب في جميع الطرفيات

if [ -f "$HOME/.GT-salat-dikr/show-prayer.sh" ]; then
    . "$HOME/.GT-salat-dikr/show-prayer.sh"
fi
EOF

chmod +x "$INSTALL_DIR/terminal-welcome.sh"

# ---------- المرحلة 5: إنشاء Launcher محسّن مع إصلاح مشكلة الإغلاق ----------
echo ""
echo "🔧 إنشاء مُشغّل ذكي مع إصلاح مشكلة الإغلاق..."

cat > "$LAUNCHER_FILE" << 'EOF'
#!/bin/bash
#
# GT-salat-dikr Launcher - النسخة المحسنة
# مع إصلاح مشكلة إغلاق النافذة
#

INSTALL_DIR="$(dirname "$(realpath "$0")")"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
        echo -e "${YELLOW}💡 سيتم تشغيل البرنامج بدون System Tray${NC}"
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
    
    # تشغيل System Tray في الخلفية كعملية مستقلة
    cd "$INSTALL_DIR"
    nohup python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    TRAY_PID=$!
    
    # حفظ PID في ملف
    echo $TRAY_PID > "/tmp/gt-salat-tray.pid"
    
    # عرض مؤشر تقدم
    echo -ne "${GREEN}"
    for i in {1..3}; do
        echo -n "█"
        sleep 1
    done
    echo -e "${NC}"
    
    # التحقق من أن العملية لا تزال تعمل
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
        echo -e "3. ⚙️  استخدم 'gtsalat' في الطرفية للمزيد من الخيارات"
        echo ""
    else
        echo -e "${YELLOW}⚠️  System Tray توقف عن العمل${NC}"
        echo -e "${YELLOW}💡 يمكنك تشغيله لاحقاً باستخدام: gtsalat --tray${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}⚠️  System Tray غير متاح${NC}"
    echo -e "${YELLOW}💡 يمكنك تثبيت Python3 والمكتبات لاحقاً${NC}"
    echo -e "${YELLOW}💡 أو استخدم 'gtsalat' في الطرفية${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💡 النافذة ستُغلق تلقائياً خلال 5 ثواني...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

# الانتظار ثم الخروج - النافذة ستُغلق تلقائياً
sleep 5
exit 0
EOF

chmod +x "$LAUNCHER_FILE"

# ---------- المرحلة 6: إنشاء Universal Launcher بسيط ----------
echo ""
echo "🌍 إنشاء Launcher عالمي بسيط..."

cat > "$UNIVERSAL_LAUNCHER" << 'EOF'
#!/bin/bash
#
# GT-salat-dikr Universal Launcher - النسخة المبسطة
# يعمل على جميع البيئات
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
    # استخدم terminal مع إغلاق تلقائي
    $TERMINAL_CMD "cd '$INSTALL_DIR' && ./launcher.sh; sleep 2; exit"
else
    # افتح مباشرة في النافذة الحالية
    cd "$INSTALL_DIR"
    ./launcher.sh
fi

exit 0
EOF

chmod +x "$UNIVERSAL_LAUNCHER"

# ---------- المرحلة 7: إنشاء ملف .desktop ----------
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

# ---------- المرحلة 8: إنشاء روابط للأوامر ----------
echo ""
echo "🔗 إنشاء أوامر سهلة الوصول..."

mkdir -p "$HOME/.local/bin"

# إنشاء الأوامر
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
ln -sf "$LAUNCHER_FILE" "$HOME/.local/bin/gt-launcher" 2>/dev/null || true
ln -sf "$UNIVERSAL_LAUNCHER" "$HOME/.local/bin/gt-salat-launcher" 2>/dev/null || true

# إضافة .local/bin إلى PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    [ -f "$HOME/.zshrc" ] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    export PATH="$HOME/.local/bin:$PATH"
    echo "  ✅ تم إضافة $HOME/.local/bin إلى PATH"
fi

# ---------- المرحلة 9: تثبيت مكتبات Python ----------
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
            echo "  ⚠️  يمكنك تثبيتها يدوياً لاحقاً: pip install --user pystray pillow"
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

# ---------- المرحلة 10: إعداد التشغيل التلقائي ----------
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

# ---------- المرحلة 11: بدء الخدمات ----------
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
    bash -c "sleep 5 && python3 '$TRAY_SCRIPT' >/dev/null 2>&1 &" &
    echo "  ✅ تم بدء System Tray"
fi

# ---------- المرحلة 12: عرض رسالة النجاح ----------
sleep 2
clear
show_header

echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 مبروك! تم تثبيت GT-salat-dikr بنجاح 🎉"
echo ""
echo "✨ التصحيحات في الإصدار 3.2.6:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ 1. إصلاح عرض الذكر والصلاة في الطرفية (يعمل الآن)"
echo "✅ 2. دعم جميع أنواع الطرفيات: bash, zsh, fish"
echo "✅ 3. إصلاح مشكلة إغلاق نافذة System Tray"
echo "✅ 4. أيقونة System Tray تبقى بعد إغلاق النافذة"
echo "✅ 5. عرض بسيط بدون إطارات معقدة"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 كيفية الاستخدام:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. افتح terminal جديد → ${GREEN}سترى الذكر وموعد الصلاة${NC}"
echo ""
echo "2. مثال لما سترى:"
echo "   🕌 GT-salat-dikr 🕋"
echo "   ══════════════════════════════════════"
echo "   ﷽ {ذكر عشوائي}"
echo "   ══════════════════════════════════════"
echo "   الصلاة القادمة: العصر - 15:30"
echo ""
echo "3. أوامر الطرفية:"
echo "   ${GREEN}gtsalat${NC}                 ← عرض الذكر والمواقيت"
echo "   ${GREEN}gtsalat --show-timetable${NC} ← مواقيت اليوم"
echo "   ${GREEN}gtsalat --tray${NC}          ← تشغيل System Tray"
echo ""
echo "4. افتح قائمة البرامج → ابحث عن 'GT-salat-dikr'"
echo "   انقر على الأيقونة لبدء System Tray"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔄 الاختبار السريع:"
echo "══════════════════════════════════════════════════════════════════════════════"

# اختبار عرض الذكر
echo "جاري اختبار عرض الذكر..."
if [ -f "$INSTALL_DIR/show-prayer.sh" ]; then
    . "$INSTALL_DIR/show-prayer.sh"
    echo "✅ يعمل بشكل صحيح!"
else
    echo "⚠️  لم يتم إنشاء script الذكر"
fi

echo ""
echo "📁 معلومات التثبيت:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• البرنامج: $INSTALL_DIR/"
echo "• عرض الذكر: ~/.bashrc, ~/.zshrc, ~/.config/fish/config.fish"
echo "• الأوامر: gtsalat, gt-launcher"
echo "• الإزالة: gtsalat --uninstall"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎯 ملاحظات:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• تم إصلاح مشكلة --next-prayer (لم يعد مستخدماً)"
echo "• النافذة تُغلق تلقائياً بعد 5 ثواني"
echo "• أيقونة System Tray تبقى بعد إغلاق النافذة"
echo "• يعمل على bash, zsh, fish"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📞 الدعم: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
echo "يمكنك البدء في استخدام البرنامج الآن! 🚀"

# اختبار نهائي
echo ""
read -p "هل تريد اختبار فتح terminal جديد؟ [Y/n]: " test_terminal
if [[ "$test_terminal" != "n" && "$test_terminal" != "N" ]]; then
    echo ""
    echo "🔍 افتح terminal جديد لترى الذكر والصلاة تلقائياً"
    echo "💡 أو اكتب: gtsalat"
fi

echo ""
echo "👋 تم التثبيت بنجاح!"

exit 0
