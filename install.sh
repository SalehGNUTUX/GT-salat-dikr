#!/bin/bash
#
# GT-salat-dikr Enhanced Installation Script (2025) - v3.2
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

echo "🔍 فحص المتطلبات..."
MISSING_TOOLS=()
for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "❌ الأدوات الناقصة: ${MISSING_TOOLS[*]}"
    echo "📦 جاري التثبيت التلقائي..."
    
    # الكشف عن مدير الحزم والتثبيت
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y ${MISSING_TOOLS[@]}
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm ${MISSING_TOOLS[@]}
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y ${MISSING_TOOLS[@]}
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y ${MISSING_TOOLS[@]}
    else
        echo "⚠️  لم يتم العثور على مدير حزم معروف"
        echo "   الرجاء تثبيت الأدوات يدوياً: ${MISSING_TOOLS[*]}"
        exit 1
    fi
fi

echo "✅ تم التحقق من المتطلبات"

# الكشف التلقائي عن نظام الخدمة
if command -v systemctl >/dev/null 2>&1 && systemctl --user 2>/dev/null; then
    SYSTEMD_AVAILABLE=1
    NOTIFY_SYSTEM="systemd"
else
    SYSTEMD_AVAILABLE=0
    NOTIFY_SYSTEM="sysvinit"
fi

echo ""
echo "📁 إنشاء مجلد التثبيت..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📁 إنشاء هيكل المجلدات الإضافية..."
mkdir -p "$INSTALL_DIR/monthly_timetables"
mkdir -p "$INSTALL_DIR/icons"

echo "⬇️  تحميل الملفات الأساسية..."
for file in "$MAIN_SCRIPT" "install.sh" "uninstall.sh" "azkar.txt" "adhan.ogg" "short_adhan.ogg" "prayer_approaching.ogg"; do
    echo "  تحميل: $file"
    curl -fsSL "$REPO_BASE/$file" -o "$file" 2>/dev/null || echo "  ⚠️ لم يتم تحميل $file"
done

# تحميل أيقونات النظام
echo "🖼️  تحميل أيقونات System Tray..."
for size in 32 64 128; do
    curl -fsSL "$REPO_BASE/icons/prayer-icon-${size}.png" \
        -o "$INSTALL_DIR/icons/prayer-icon-${size}.png" 2>/dev/null || \
        echo "  ⚠️ لم يتم تحميل أيقونة ${size}x${size}"
done

# تحميل ملف System Tray
echo "📥 تحميل ملف System Tray..."
curl -fsSL "$REPO_BASE/gt-tray.py" -o "$INSTALL_DIR/gt-tray.py" 2>/dev/null || \
    echo "⚠️ لم يتم تحميل gt-tray.py"

chmod +x "$MAIN_SCRIPT" install.sh uninstall.sh gt-tray.py 2>/dev/null || true

echo "🔗 إعداد المسار..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true

echo ""
echo "📍 الكشف التلقائي عن الموقع..."

# قيم افتراضية
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

# الإعدادات الافتراضية (بدون أسئلة)
PRE_PRAYER_NOTIFY=15
ZIKR_NOTIFY_INTERVAL=600  # 10 دقائق
ADHAN_TYPE="short"        # أذان قصير افتراضي
AUTO_UPDATE_TIMETABLES=0  # التحديث التلقائي معطل
AUTO_SELF_UPDATE=0        # التحديث الذاتي معطل

# جميع الإشعارات مفعلة افتراضي
ENABLE_SALAT_NOTIFY=1
ENABLE_ZIKR_NOTIFY=1
TERMINAL_SALAT_NOTIFY=1
TERMINAL_ZIKR_NOTIFY=1
SYSTEM_SALAT_NOTIFY=1
SYSTEM_ZIKR_NOTIFY=1

echo ""
echo "📝 حفظ الإعدادات الأولية..."
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

echo ""
echo "🚀 إعداد التشغيل التلقائي..."

if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Times and Azkar Notifications
After=graphical-session.target default.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$MAIN_SCRIPT --child-notify
Restart=always
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="DISPLAY=:0"
Environment="XDG_RUNTIME_DIR=/run/user/%U"

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable gt-salat-dikr.service
    echo "✅ تم تفعيل خدمة systemd"
else
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=$INSTALL_DIR/$MAIN_SCRIPT --notify-start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    echo "✅ تم تفعيل autostart بطريقة sysvinit"
fi

echo ""
echo "🔧 إعدادات الطرفية التلقائية..."
setup_terminal_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # إزالة أي إعدادات قديمة معطوبة
        sed -i '/# GT-salat-dikr/,/fi/d' "$shell_file" 2>/dev/null || true
        sed -i '/gtsalat/d' "$shell_file" 2>/dev/null || true
        
        # إضافة الإعدادات الجديدة
        {
            echo ""
            echo "# GT-salat-dikr - تذكير الصلاة والأذكار"
            echo "if [ -f \"$INSTALL_DIR/$MAIN_SCRIPT\" ]; then"
            echo "    alias gtsalat='\"$INSTALL_DIR/$MAIN_SCRIPT\"'"
            echo "    echo ''"
            echo "    \"$INSTALL_DIR/$MAIN_SCRIPT\""
            echo "fi"
        } >> "$shell_file"
        
        echo "  ✅ تم إعداد $shell_name"
    else
        echo "  ⚠️  ملف $shell_name غير موجود"
    fi
}

# إعدادات لأنواع الطرفيات المختلفة
setup_terminal_config "$HOME/.bashrc" "Bash"
setup_terminal_config "$HOME/.bash_profile" "Bash Profile"

if [ -f "$HOME/.zshrc" ]; then
    setup_terminal_config "$HOME/.zshrc" "Zsh"
fi

echo "✅ تم إعداد الطرفية لعرض الذكر وموعد الصلاة عند الافتتاح"

# تحميل مواقيت الصلاة للأشهر القادمة
echo ""
echo "📥 جلب مواقيت الصلاة للأشهر القادمة (في الخلفية)..."

# تشغيل التحميل في الخلفية
(
    echo "  ⏳ جاري تحميل بيانات الصلاة..."
    if curl -s --connect-timeout 5 https://api.aladhan.com >/dev/null 2>&1; then
        "$INSTALL_DIR/$MAIN_SCRIPT" --update-timetables >/dev/null 2>&1
        echo "  ✅ تم تحميل مواقيت الصلاة"
    else
        echo "  ⚠️  لا يوجد اتصال بالإنترنت، سيتم استخدام البيانات المحلية"
    fi
) &

echo ""
echo "📦 التحقق من مكتبات Python للنظام..."

check_python_deps() {
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import pystray, PIL" 2>/dev/null; then
            echo "✅ مكتبات Python مثبتة"
            return 0
        else
            echo "📦 تثبيت مكتبات Python..."
            
            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y python3-pystray python3-pil
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy --noconfirm python-pystray python-pillow
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y python3-pystray python3-pillow
            else
                python3 -m pip install --user pystray pillow
            fi
            
            return $?
        fi
    else
        echo "⚠️  Python3 غير مثبت"
        return 1
    fi
}

PYTHON_DEPS_OK=0
if check_python_deps; then
    PYTHON_DEPS_OK=1
    echo "✅ مكتبات System Tray جاهزة"
else
    echo "⚠️  System Tray قد لا يعمل بشكل كامل"
fi

# بدء الخدمات
echo ""
echo "🚀 بدء تشغيل الخدمات..."

# بدء خدمة الإشعارات
if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    systemctl --user start gt-salat-dikr.service 2>/dev/null || true
    echo "✅ تم بدء خدمة الإشعارات"
else
    "$INSTALL_DIR/$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
    echo "✅ تم بدء الإشعارات"
fi

# بدء System Tray إذا كانت المكتبات مثبتة
if [ "$PYTHON_DEPS_OK" -eq 1 ] && [ -f "$INSTALL_DIR/gt-tray.py" ]; then
    echo "🖥️  بدء تشغيل System Tray..."
    python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
    sleep 2
    echo "✅ تم تشغيل System Tray"
    echo "📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
else
    echo "ℹ️  يمكنك تشغيل System Tray لاحقاً: gtsalat --tray"
fi

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
echo "✅ تم اكتمال التثبيت! جرب الأمر: gtsalat"
echo ""
