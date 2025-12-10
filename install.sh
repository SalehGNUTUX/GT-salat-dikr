#!/bin/bash
#
# GT-salat-dikr Installation v3.2.0
# تثبيت بسيط وفعال مع الحفاظ على الوظائف الأساسية
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
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.0 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     تثبيت GT-salat-dikr - الإصدار المحسّن"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من عدم التشغيل كـ root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    echo "💡 استخدم: bash install.sh"
    exit 1
fi

# ---------- الإعدادات الأساسية ----------
INSTALL_DIR="/opt/gt-salat-dikr"
HOME_INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
USER_BIN="$HOME/.local/bin"

# ---------- التحقق من المتطلبات ----------
echo "🔍 التحقق من المتطلبات الأساسية..."

REQUIRED_PACKAGES=("curl" "jq")
MISSING_PACKAGES=()

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "📦 تثبيت الحزم المطلوبة: ${MISSING_PACKAGES[*]}"
    
    # الكشف عن مدير الحزم
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y "${MISSING_PACKAGES[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm "${MISSING_PACKAGES[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${MISSING_PACKAGES[@]}"
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y "${MISSING_PACKAGES[@]}"
    else
        echo "⚠️  لم أتمكن من تثبيت الحزم المطلوبة تلقائياً"
        echo "📦 يرجى تثبيتها يدوياً: ${MISSING_PACKAGES[*]}"
    fi
fi

# ---------- إنشاء الدلائل ----------
echo ""
echo "📁 إنشاء هيكل الدلائل..."
sudo mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME_INSTALL_DIR"
mkdir -p "$USER_BIN"
mkdir -p "$INSTALL_DIR/icons"
mkdir -p "$HOME/.config/gt-salat-dikr"

# تعيين الأذونات
sudo chown -R $USER:$USER "$INSTALL_DIR"

# ---------- تحميل البرنامج الرئيسي ----------
echo ""
echo "📥 تحميل البرنامج الرئيسي..."

# دالة للتحميل الآمن
download_file() {
    local url="$1"
    local output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$url" -o "$output"; then
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$url" -O "$output"; then
            return 0
        fi
    fi
    return 1
}

# تحميل الملفات الأساسية
FILES_TO_DOWNLOAD=(
    "main.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/main.sh"
    "gt-tray.py:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-tray.py"
    "uninstall.sh:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/uninstall.sh"
)

for file_entry in "${FILES_TO_DOWNLOAD[@]}"; do
    IFS=':' read -r filename url <<< "$file_entry"
    echo "  ⬇️  تحميل: $filename"
    
    if download_file "$url" "$INSTALL_DIR/$filename"; then
        sudo chmod +x "$INSTALL_DIR/$filename"
        echo "  ✅ تم"
    else
        echo "  ❌ فشل تحميل $filename"
    fi
done

# تحميل ملفات البيانات
DATA_FILES=(
    "azkar.json:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/data/azkar.json"
    "prayer_methods.json:https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/data/prayer_methods.json"
)

mkdir -p "$INSTALL_DIR/data"
for data_entry in "${DATA_FILES[@]}"; do
    IFS=':' read -r filename url <<< "$data_entry"
    echo "  ⬇️  تحميل: $filename"
    download_file "$url" "$INSTALL_DIR/data/$filename" || true
done

# تحميل الأيقونات
echo "  ⬇️  تحميل الأيقونات..."
for size in 16 32 48 64 128; do
    download_file "$REPO_BASE/icons/prayer-icon-${size}.png" "$INSTALL_DIR/icons/prayer-icon-${size}.png" || true
done

# ---------- إنشاء الأوامر ----------
echo ""
echo "🔗 إنشاء أوامر سهلة الوصول..."

# إنشاء الأمر الرئيسي gtsalat
sudo tee /usr/local/bin/gtsalat > /dev/null << 'EOF'
#!/bin/bash
if [ -f "/opt/gt-salat-dikr/main.sh" ]; then
    bash "/opt/gt-salat-dikr/main.sh" "$@"
else
    echo "❌ لم يتم العثور على البرنامج الرئيسي"
    echo "💡 حاول إعادة التثبيت: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/gtsalat

# إنشاء رابط للبرنامج في home directory
ln -sf "$INSTALL_DIR/main.sh" "$USER_BIN/gt-salat" 2>/dev/null || true

# ---------- تثبيت مكتبات Python (اختياري) ----------
echo ""
echo "🐍 تثبيت مكتبات Python (لـ System Tray)..."

install_python_deps() {
    echo "  🔍 التحقق من Python3..."
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  📦 تثبيت Python3..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y python3 python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm python python-pip
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3 python3-pip
        fi
    fi
    
    echo "  📦 تثبيت مكتبات Python المطلوبة..."
    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "  ✅ المكتبات مثبتة بالفعل"
    else
        echo "  ⚙️  جاري التثبيت..."
        python3 -m pip install --user pystray pillow 2>/dev/null || {
            echo "  ⚠️  فشل التثبيت التلقائي"
            echo "  💡 يمكنك تثبيتها يدوياً لاحقاً:"
            echo "     pip install --user pystray pillow"
        }
    fi
}

read -p "هل تريد تثبيت System Tray (أيقونة في شريط المهام)؟ [y/N]: " install_tray
if [[ "$install_tray" =~ ^[Yy]$ ]]; then
    install_python_deps
    # إنشاء رابط لـ tray
    ln -sf "$INSTALL_DIR/gt-tray.py" "$USER_BIN/gt-tray" 2>/dev/null || true
fi

# ---------- إنشاء ملف .desktop بسيط ----------
echo ""
echo "🖥️  إنشاء أيقونة في قائمة البرامج..."

DESKTOP_ENTRY="[Desktop Entry]
Version=1.0
Type=Application
Name=GT-salat-dikr
GenericName=Prayer Times & Azkar
Comment=نظام إشعارات الصلاة والأذكار
Exec=gtsalat
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Terminal=true
Categories=Utility;Education;
Keywords=prayer;islam;azkar;reminder;"

# حفظ في مواقع مختلفة
DESKTOP_PATHS=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
)

for desktop_path in "${DESKTOP_PATHS[@]}"; do
    mkdir -p "$(dirname "$desktop_path")"
    echo "$DESKTOP_ENTRY" > "$desktop_path"
    echo "  ✅ تم إنشاء: $desktop_path"
done

# تحديث قاعدة بيانات التطبيقات
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
fi

# ---------- الإعدادات التلقائية ----------
echo ""
echo "⚙️  تطبيق الإعدادات التلقائية..."

# إنشاء ملف إعدادات افتراضي
CONFIG_DIR="$HOME/.config/gt-salat-dikr"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.json" << 'EOF'
{
    "settings": {
        "auto_start": true,
        "notifications_enabled": true,
        "auto_update_timetables": true,
        "offline_mode": true,
        "reminder_before_prayer": 15,
        "azkar_interval": 10,
        "adhan_type": "full",
        "enable_terminal_notify": true,
        "enable_gui_notify": true,
        "enable_sound": true,
        "enable_approaching_notify": true
    }
}
EOF

# إعداد التشغيل التلقائي
echo "🔧 إعداد التشغيل التلقائي عند بدء النظام..."

# لـ systemd
if command -v systemctl >/dev/null 2>&1; then
    cat > /tmp/gt-salat-dikr.service << EOF
[Unit]
Description=GT-salat-dikr Prayer Notifications
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/gtsalat --notify-start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/gt-salat-dikr.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable gt-salat-dikr.service 2>/dev/null || true
    echo "  ✅ تم إعداد خدمة systemd"
fi

# لـ crontab (بديل)
if command -v crontab >/dev/null 2>&1; then
    CRON_JOB="@reboot sleep 60 && /usr/local/bin/gtsalat --notify-start >/dev/null 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "gtsalat"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "  ✅ تم إضافة مهمة crontab للتشغيل التلقائي"
    fi
fi

# ---------- بدء البرنامج ----------
echo ""
echo "🚀 بدء تشغيل البرنامج..."

# بدء الإشعارات
echo "🔔 تشغيل إشعارات الصلاة..."
gtsalat --notify-start >/dev/null 2>&1 || true

# بدء System Tray إذا طلب المستخدم
if [[ "$install_tray" =~ ^[Yy]$ ]] && command -v python3 >/dev/null 2>&1; then
    echo "🖥️  تشغيل System Tray..."
    python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
fi

# ---------- رسالة النجاح ----------
sleep 2
clear
show_header

echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 تم تثبيت GT-salat-dikr بنجاح!"
echo ""
echo "✨ الميزات المفعّلة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ عرض ذكر عشوائي وموعد الصلاة عند فتح terminal جديد"
echo "✅ إشعارات تلقائية قبل كل صلاة بـ 15 دقيقة"
echo "✅ عرض أذكار كل 10 دقائق"
echo "✅ تحديث تلقائي لمواقيت الصلاة"
echo "✅ تشغيل تلقائي عند بدء النظام"
echo "✅ أوامر سهلة الاستخدام"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 كيفية الاستخدام:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. افتح terminal جديد واكتب: ${GREEN}gtsalat${NC}"
echo "   ↳ سيظهر لك ذكر عشوائي وموعد الصلاة القادمة"
echo ""
echo "2. افتح قائمة البرامج وابحث عن 'GT-salat-dikr'"
echo "   ↳ انقر على الأيقونة لفتح البرنامج"
echo ""
echo "3. للأوامر المتقدمة:"
echo "   ${GREEN}gtsalat --show-timetable${NC}   لعرض مواقيت اليوم"
echo "   ${GREEN}gtsalat --settings${NC}         لضبط الإعدادات"
echo "   ${GREEN}gtsalat --notify-stop${NC}      لإيقاف الإشعارات"
echo "   ${GREEN}gtsalat --notify-start${NC}     لبدء الإشعارات"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "💡 نصيحة: عند فتح terminal جديد، سيظهر تلقائياً:"
echo "   ┌────────────────────────────────────┐"
echo "   │  ﷽ بسم الله الرحمن الرحيم       │"
echo "   │                                    │"
echo "   │  ذكر: {ذكر عشوائي}                │"
echo "   │  الصلاة القادمة: {اسم الصلاة}     │"
echo "   │  الوقت المتبقي: {الوقت}           │"
echo "   └────────────────────────────────────┘"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔧 لتعديل الإعدادات:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• وقت التنبيه قبل الصلاة: 15 دقيقة (قابل للتغيير)"
echo "• فاصل عرض الأذكار: 10 دقائق (قابل للتغيير)"
echo "• تحديث المواقيت: تلقائي يومياً"
echo "• التشغيل التلقائي: مفعّل"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📁 معلومات التثبيت:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• الملفات الرئيسية: /opt/gt-salat-dikr/"
echo "• الإعدادات: ~/.config/gt-salat-dikr/"
echo "• الأوامر: gtsalat, gt-tray (إذا مثبت)"
echo "• الإزالة: gtsalat --uninstall"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔄 الاختبار السريع:"
echo "══════════════════════════════════════════════════════════════════════════════"

# اختبار سريع
echo "جاري اختبار البرنامج..."
if gtsalat --show-timetable >/dev/null 2>&1; then
    echo "✅ البرنامج يعمل بشكل صحيح"
    echo ""
    echo "عرض مثال للمخرجات:"
    echo "────────────────────────────────────"
    gtsalat | head -10
    echo "────────────────────────────────────"
else
    echo "⚠️  هناك مشكلة في التشغيل"
    echo "💡 جرب تشغيل: gtsalat --settings لضبط الإعدادات"
fi

echo ""
echo "🎯 ملاحظة مهمة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• تم الحفاظ على الوظائف الأساسية: الذكر + مواقيت الصلاة في terminal"
echo "• تم إضافة System Tray كخيار إضافي"
echo "• تم تحسين الأداء والاستقرار"
echo "• الإعدادات تعمل تلقائياً بدون حاجة لتعديل"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📞 الدعم: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
echo "مع السلامة! يمكنك البدء في استخدام البرنامج الآن. 🚀"

# إضافة تلقائية إلى .bashrc لعرض الذكر عند فتح terminal
if ! grep -q "gtsalat" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# عرض ذكر وموعد الصلاة عند فتح terminal" >> "$HOME/.bashrc"
    echo "if command -v gtsalat >/dev/null 2>&1; then" >> "$HOME/.bashrc"
    echo "    echo \"\"" >> "$HOME/.bashrc"
    echo "    gtsalat" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
    echo "✅ تم إضافة عرض الذكر تلقائياً عند فتح terminal"
fi

exit 0
