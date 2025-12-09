#!/bin/bash
#
# GT-salat-dikr Simplified Installation Script - v3.2.2
# تثبيت سلس ومبسط مع System Tray
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# منع التشغيل بصلاحيات root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root، استخدم حساب المستخدم العادي."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
MAIN_SCRIPT="gt-salat-dikr.sh"
CONFIG_FILE="$INSTALL_DIR/settings.conf"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"

# ---------- المرحلة 1: فحص وتثبيت المتطلبات ----------
echo "🔍 فحص المتطلبات الأساسية..."

# قائمة الأدوات المطلوبة
REQUIRED_TOOLS=("curl" "jq")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

# تثبيت الأدوات الناقصة تلقائياً
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "📦 تثبيت الأدوات الناقصة: ${MISSING_TOOLS[*]}"
    
    # الكشف عن مدير الحزم
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y "${MISSING_TOOLS[@]}" || {
            echo "❌ فشل تثبيت الأدوات"
            exit 1
        }
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm "${MISSING_TOOLS[@]}" || {
            echo "❌ فشل تثبيت الأدوات"
            exit 1
        }
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${MISSING_TOOLS[@]}" || {
            echo "❌ فشل تثبيت الأدوات"
            exit 1
        }
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y "${MISSING_TOOLS[@]}" || {
            echo "❌ فشل تثبيت الأدوات"
            exit 1
        }
    else
        echo "⚠️  لم يتم العثور على مدير حزم معروف"
        echo "   الرجاء تثبيت الأدوات يدوياً: ${MISSING_TOOLS[*]}"
        exit 1
    fi
fi

echo "✅ تم التحقق من المتطلبات"

# الكشف التلقائي عن نظام الخدمة
if command -v systemctl >/dev/null 2>&1 && systemctl --user 2>/dev/null; then
    NOTIFY_SYSTEM="systemd"
    echo "✅ تم اكتشاف نظام systemd"
else
    NOTIFY_SYSTEM="sysvinit"
    echo "✅ تم استخدام نظام sysvinit"
fi

# ---------- المرحلة 2: التحميل الأساسي ----------
echo ""
echo "📥 تحميل البرنامج..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# تحميل الملفات الأساسية فقط
echo "⬇️  جاري تحميل الملفات الأساسية..."

ESSENTIAL_FILES=(
    "$MAIN_SCRIPT"
    "azkar.txt"
    "adhan.ogg"
    "short_adhan.ogg"
    "prayer_approaching.ogg"
    "gt-tray.py"
)

for file in "${ESSENTIAL_FILES[@]}"; do
    echo "  تحميل: $file"
    if ! curl -fsSL "$REPO_BASE/$file" -o "$file" 2>/dev/null; then
        echo "  ⚠️  لم يتم تحميل $file (سيتم إنشاء بديل إذا لزم)"
    fi
done

# إنشاء ملفات صوتية بديلة إذا فشل التحميل
if [ ! -f "adhan.ogg" ]; then
    echo "  🔨 إنشاء ملف صوتي بديل للأذان..."
    echo "سيتم استخدام إشعارات النظام بدلاً من الأذان الصوتي" > adhan.ogg
fi

if [ ! -f "short_adhan.ogg" ]; then
    cp -f adhan.ogg short_adhan.ogg 2>/dev/null || true
fi

chmod +x "$MAIN_SCRIPT" gt-tray.py 2>/dev/null || true

# إنشاء رابط في PATH
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
echo "✅ تم إعداد المسار: gtsalat"

# ---------- المرحلة 3: تحميل الأيقونات ----------
echo ""
echo "🖼️  تحميل أيقونات النظام..."

ICON_DIR="$INSTALL_DIR/icons"
mkdir -p "$ICON_DIR"

echo "⬇️  جاري تحميل الأيقونات..."
for size in 32 64 128; do
    icon_url="$REPO_BASE/icons/prayer-icon-${size}.png"
    icon_file="$ICON_DIR/prayer-icon-${size}.png"
    
    if curl -fsSL "$icon_url" -o "$icon_file" 2>/dev/null; then
        echo "  ✅ تم تحميل أيقونة ${size}x${size}"
    else
        echo "  ⚠️  لم يتم تحميل أيقونة ${size}x${size}"
    fi
done

# ---------- المرحلة 4: الكشف التلقائي عن الموقع ----------
echo ""
echo "📍 الكشف التلقائي عن الموقع..."

# قيم افتراضية (الرياض)
LAT="24.7136"
LON="46.6753"
CITY="الرياض"
COUNTRY="السعودية"

# محاولة الكشف التلقائي
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    echo "🔍 جاري اكتشاف موقعك..."
    LOCATION_DATA=$(curl -fsSL "http://ip-api.com/json/" --connect-timeout 5 2>/dev/null || echo "")
    
    if [ -n "$LOCATION_DATA" ]; then
        DETECTED_LAT=$(echo "$LOCATION_DATA" | jq -r '.lat // empty' 2>/dev/null)
        DETECTED_LON=$(echo "$LOCATION_DATA" | jq -r '.lon // empty' 2>/dev/null)
        DETECTED_CITY=$(echo "$LOCATION_DATA" | jq -r '.city // empty' 2>/dev/null)
        DETECTED_COUNTRY=$(echo "$LOCATION_DATA" | jq -r '.country // empty' 2>/dev/null)
        
        if [ -n "$DETECTED_LAT" ] && [ -n "$DETECTED_LON" ]; then
            LAT="$DETECTED_LAT"
            LON="$DETECTED_LON"
            CITY="${DETECTED_CITY:-الرياض}"
            COUNTRY="${DETECTED_COUNTRY:-السعودية}"
            echo "✅ تم اكتشاف الموقع: $CITY, $COUNTRY"
        else
            echo "⚠️  تعذر الاكتشاف الدقيق، استخدام القيم الافتراضية"
        fi
    else
        echo "⚠️  تعذر الاتصال بخدمة الموقع، استخدام القيم الافتراضية"
    fi
else
    echo "⚠️  الأدوات غير متوفرة للاكتشاف، استخدام القيم الافتراضية"
fi

# اختيار طريقة الحساب بناءً على الدولة
case "$COUNTRY" in
    "السعودية"|"Saudi Arabia")
        METHOD_ID=4  # أم القرى
        METHOD_NAME="Umm Al-Qura University, Makkah"
        ;;
    "مصر"|"Egypt")
        METHOD_ID=5  # مصر
        METHOD_NAME="Egyptian General Authority of Survey"
        ;;
    "المغرب"|"Morocco")
        METHOD_ID=21  # المغرب
        METHOD_NAME="Morocco"
        ;;
    "الجزائر"|"Algeria")
        METHOD_ID=19  # الجزائر
        METHOD_NAME="Algeria"
        ;;
    *)
        METHOD_ID=4  # أم القرى كافتراضي
        METHOD_NAME="Umm Al-Qura University, Makkah"
        ;;
esac

echo "🧭 الإحداثيات: $LAT, $LON"
echo "📖 طريقة الحساب: $METHOD_NAME"

# ---------- المرحلة 5: تطبيق الإعدادات الافتراضية ----------
echo ""
echo "⚙️  تطبيق الإعدادات الافتراضية..."

# الإعدادات الافتراضية (بدون أسئلة)
PRE_PRAYER_NOTIFY=15
ZIKR_NOTIFY_INTERVAL=600  # 10 دقائق = 600 ثانية
ADHAN_TYPE="short"        # أذان قصير افتراضي
AUTO_UPDATE_TIMETABLES=0  # التحديث التلقائي معطل
AUTO_SELF_UPDATE=0        # التحديث الذاتي معطل

# جميع الإشعارات مفعلة افتراضياً
ENABLE_SALAT_NOTIFY=1
ENABLE_ZIKR_NOTIFY=1
TERMINAL_SALAT_NOTIFY=1
TERMINAL_ZIKR_NOTIFY=1
SYSTEM_SALAT_NOTIFY=1
SYSTEM_ZIKR_NOTIFY=1

# حفظ الإعدادات
cat > "$CONFIG_FILE" <<EOF
LAT="$LAT"
LON="$LON"
CITY="$CITY"
COUNTRY="$COUNTRY"
METHOD_ID="$METHOD_ID"
METHOD_NAME="$METHOD_NAME"
PRE_PRAYER_NOTIFY=$PRE_PRAYER_NOTIFY
ZIKR_NOTIFY_INTERVAL=$ZIKR_NOTIFY_INTERVAL
ADHAN_TYPE="$ADHAN_TYPE"
AUTO_SELF_UPDATE=$AUTO_SELF_UPDATE
AUTO_UPDATE_TIMETABLES=$AUTO_UPDATE_TIMETABLES
ENABLE_SALAT_NOTIFY=$ENABLE_SALAT_NOTIFY
ENABLE_ZIKR_NOTIFY=$ENABLE_ZIKR_NOTIFY
NOTIFY_SYSTEM="$NOTIFY_SYSTEM"
TERMINAL_SALAT_NOTIFY=$TERMINAL_SALAT_NOTIFY
TERMINAL_ZIKR_NOTIFY=$TERMINAL_ZIKR_NOTIFY
SYSTEM_SALAT_NOTIFY=$SYSTEM_SALAT_NOTIFY
SYSTEM_ZIKR_NOTIFY=$SYSTEM_ZIKR_NOTIFY
EOF

echo "✅ تم حفظ الإعدادات الافتراضية"

# ---------- المرحلة 6: تحميل مواقيت الصلاة تلقائياً ----------
echo ""
echo "📥 جلب مواقيت الصلاة للأشهر القادمة..."

# تشغيل التحميل في الخلفية دون إزعاج المستخدم
(
    echo "  ⏳ جاري تحميل بيانات الصلاة..."
    
    # التحقق من اتصال الإنترنت
    if curl -s --connect-timeout 5 https://api.aladhan.com >/dev/null 2>&1; then
        # إنشاء مجلد الجداول الشهرية
        mkdir -p "$INSTALL_DIR/monthly_timetables"
        
        # تحميل بيانات 3 أشهر
        CURRENT_YEAR=$(date +%Y)
        CURRENT_MONTH=$(date +%m)
        
        for i in {0..2}; do
            YEAR=$((CURRENT_YEAR + (CURRENT_MONTH + i - 1) / 12))
            MONTH=$(((CURRENT_MONTH + i - 1) % 12 + 1))
            MONTH_FORMATTED=$(printf "%02d" "$MONTH")
            
            echo "  📅 تحميل شهر $MONTH_FORMATTED-$YEAR..."
            curl -fsSL "https://api.aladhan.com/v1/calendar/${YEAR}/${MONTH_FORMATTED}?latitude=${LAT}&longitude=${LON}&method=${METHOD_ID}" \
                -o "$INSTALL_DIR/monthly_timetables/timetable_${YEAR}_${MONTH_FORMATTED}.json" 2>/dev/null || true
            sleep 1
        done
        
        echo "  ✅ تم تحميل مواقيت الصلاة لـ 3 أشهر"
    else
        echo "  ⚠️  لا يوجد اتصال بالإنترنت، سيتم استخدام البيانات المحلية عند الحاجة"
    fi
) &

# ---------- المرحلة 7: إعداد التشغيل التلقائي ----------
echo ""
echo "🚀 إعداد التشغيل التلقائي..."

if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    
    # إنشاء خدمة systemd
    cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Times and Azkar Notifications
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$MAIN_SCRIPT --child-notify
Restart=always
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="DISPLAY=:0"

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload >/dev/null 2>&1
    systemctl --user enable gt-salat-dikr.service >/dev/null 2>&1
    echo "✅ تم تفعيل التشغيل التلقائي (systemd)"
    
    # محاولة البدء الآن
    if systemctl --user start gt-salat-dikr.service >/dev/null 2>&1; then
        echo "✅ تم بدء الخدمة"
    fi
else
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=Prayer times and azkar notifications
Exec=$INSTALL_DIR/$MAIN_SCRIPT --notify-start
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
EOF
    echo "✅ تم تفعيل التشغيل التلقائي (autostart)"
    
    # بدء الإشعارات الآن
    if [ -f "$MAIN_SCRIPT" ]; then
        "$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
        echo "✅ تم بدء الإشعارات"
    fi
fi

# ---------- المرحلة 8: إعدادات الطرفية ----------
echo ""
echo "🔧 إعدادات الطرفية..."

setup_shell_config() {
    local shell_file="$1"
    local shell_name="$2"

    if [ -f "$shell_file" ]; then
        echo "  إعداد $shell_name..."

        # إزالة أي إعدادات قديمة
        sed -i '/# GT-salat-dikr/,/fi/d' "$shell_file" 2>/dev/null || true
        sed -i '/gtsalat/d' "$shell_file" 2>/dev/null || true
        sed -i '/GT-salat-dikr/d' "$shell_file" 2>/dev/null || true

        # إضافة الإعدادات البسيطة - الإصلاح هنا
        cat >> "$shell_file" <<EOF

# GT-salat-dikr - تذكير الصلاة والأذكار
if [ -f "$INSTALL_DIR/$MAIN_SCRIPT" ]; then
    alias gtsalat="$INSTALL_DIR/$MAIN_SCRIPT"
fi

# تشغيل البرنامج عند فتح الطرفية
if [ -f "$INSTALL_DIR/$MAIN_SCRIPT" ]; then
    echo ""
    "$INSTALL_DIR/$MAIN_SCRIPT"
fi
EOF

        echo "  ✅ تم إعداد $shell_name"
    else
        echo "  ⚠️  ملف $shell_name غير موجود"
    fi
}

# إعدادات لأنواع الطرفيات المختلفة
setup_shell_config "$HOME/.bashrc" "Bash"
setup_shell_config "$HOME/.bash_profile" "Bash Profile"

if [ -f "$HOME/.zshrc" ]; then
    setup_shell_config "$HOME/.zshrc" "Zsh"
fi

echo "✅ تم إعداد الطرفية لعرض الذكر وموعد الصلاة عند الافتتاح"

# ---------- المرحلة 9: تثبيت مكتبات Python ----------
echo ""
echo "📦 التحقق من مكتبات Python للنظام..."

check_and_install_python_deps() {
    # التحقق من Python3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  ⚠️  Python3 غير مثبت"
        echo "  💡 سيتم استخدام الإشعارات العادية بدون System Tray"
        return 1
    fi
    
    # التحقق من المكتبات
    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "  ✅ مكتبات Python مثبتة"
        return 0
    else
        echo "  📦 جاري تثبيت المكتبات..."
        
        # تثبيت باستخدام مدير الحزم المناسب
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3-pystray python3-pil 2>/dev/null && {
                echo "  ✅ تم التثبيت (apt)"
                return 0
            }
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm python-pystray python-pillow 2>/dev/null && {
                echo "  ✅ تم التثبيت (pacman)"
                return 0
            }
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3-pystray python3-pillow 2>/dev/null && {
                echo "  ✅ تم التثبيت (dnf)"
                return 0
            }
        fi
        
        # محاولة باستخدام pip
        echo "  🔨 محاولة التثبيت باستخدام pip..."
        if python3 -m pip install --user pystray pillow 2>/dev/null; then
            echo "  ✅ تم التثبيت (pip)"
            return 0
        fi
        
        echo "  ❌ فشل تثبيت المكتبات"
        echo "  💡 يمكنك تثبيتها يدوياً لاحقاً"
        return 1
    fi
}

# التحقق من التبعيات
PYTHON_DEPS_OK=0
if check_and_install_python_deps; then
    PYTHON_DEPS_OK=1
    echo "✅ مكتبات System Tray جاهزة"
else
    echo "⚠️  System Tray قد لا يعمل بشكل كامل"
fi

# ---------- المرحلة 10: بدء System Tray ----------
echo ""
echo "🚀 بدء تشغيل الخدمات..."

# بدء System Tray إذا كانت المكتبات متوفرة
if [ "$PYTHON_DEPS_OK" -eq 1 ] && [ -f "$TRAY_SCRIPT" ]; then
    echo "🖥️  بدء تشغيل System Tray..."
    python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    sleep 2
    echo "✅ تم تشغيل System Tray"
    echo "📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
else
    echo "ℹ️  يمكنك تشغيل System Tray لاحقاً: gtsalat --tray"
fi

# ---------- المرحلة 11: العرض النهائي ----------
echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 تم التثبيت بنجاح!"
echo "════════════════════════════════════════════════════════"
echo ""

# عرض معلومات البرنامج
echo "📊 معلومات البرنامج الحالية:"
echo "════════════════════════════════════════════════════════"
"$INSTALL_DIR/$MAIN_SCRIPT" 2>/dev/null || echo "  جاري تحميل البيانات..."
echo "════════════════════════════════════════════════════════"

echo ""
echo "📋 الإعدادات الافتراضية المطبقة:"
echo "════════════════════════════════════════════════════════"
echo "📍 الموقع: $CITY, $COUNTRY"
echo "🧭 الإحداثيات: $LAT, $LON"
echo "📖 طريقة الحساب: $METHOD_NAME"
echo "⏰ التنبيه قبل الصلاة: $PRE_PRAYER_NOTIFY دقيقة"
echo "🕊️ فاصل الأذكار: $((ZIKR_NOTIFY_INTERVAL/60)) دقيقة"
echo "📢 نوع الأذان: $ADHAN_TYPE (قصير افتراضي)"
echo "🔔 جميع الإشعارات: مفعلة ✓"
echo "🛠 نظام الخدمة: $NOTIFY_SYSTEM"
echo "🔄 التحديث التلقائي: معطل (لتجنب استهلاك البيانات)"
echo "💾 التخزين المحلي: جاري التحميل تلقائياً ✓"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔧 أوامر التحكم السريعة:"
echo "════════════════════════════════════════════════════════"
echo "gtsalat                    # عرض ذكر وموعد الصلاة"
echo "gtsalat --show-timetable   # عرض مواقيت اليوم"
echo "gtsalat --status          # عرض حالة البرنامج"
echo "gtsalat --settings        # تعديل الإعدادات (لاحقاً)"
echo "gtsalat --notify-stop     # إيقاف الإشعارات مؤقتاً"
echo "gtsalat --notify-start    # استئناف الإشعارات"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🖥️  System Tray (شريط المهام):"
echo "════════════════════════════════════════════════════════"
echo "📌 إذا كانت الأيقونة تظهر، انقر بزر الماوس الأيمن للتحكم"
echo "📊 تعرض الأيقونة: مواقيت اليوم + الصلاة القادمة"
echo "🔧 أوامر System Tray:"
echo "   gtsalat --tray         # تشغيل الأيقونة"
echo "   gtsalat --tray-restart # إعادة تشغيلها"
echo "   gtsalat --tray-stop    # إيقافها"
echo "════════════════════════════════════════════════════════"

echo ""
echo "📝 ملاحظات مهمة:"
echo "════════════════════════════════════════════════════════"
echo "• البرنامج يعمل تلقائياً عند تشغيل الجهاز"
echo "• تم تفعيل التخزين المحلي (يعمل بدون إنترنت)"
echo "• الأذان القصير مفعل افتراضياً (يمكن تغييره)"
echo "• يمكنك تعديل أي إعداد لاحقاً: gtsalat --settings"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔄 إذا أغلقت System Tray، أعد تشغيلها بـ:"
echo "════════════════════════════════════════════════════════"
echo "gtsalat --tray"
echo "أو"
echo "python3 ~/.GT-salat-dikr/gt-tray.py"
echo "════════════════════════════════════════════════════════"

echo ""
echo "✅ تم اكتمال التثبيت! افتح terminal جديد لرؤية النتيجة"
echo ""
