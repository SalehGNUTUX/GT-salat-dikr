#!/bin/bash
#
# GT-salat-dikr Complete Auto-start Installation Script - v3.2.2-full
# تثبيت كامل مع التشغيل التلقائي عند الإقلاع
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "     مع التشغيل التلقائي الكامل عند الإقلاع"
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
STARTUP_SCRIPT="$INSTALL_DIR/autostart-manager.sh"
LOG_FILE="$INSTALL_DIR/startup.log"

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
    if curl -s --connect-timeout 5 https://api.aladhan.com >/dev/null 2>/dev/null; then
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

# ---------- المرحلة 7: إنشاء مدير التشغيل التلقائي ----------
echo ""
echo "🚀 إنشاء مدير التشغيل التلقائي..."

cat > "$STARTUP_SCRIPT" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Auto-start Manager
# يدير التشغيل التلقائي للإشعارات و System Tray
#

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$INSTALL_DIR/startup.log"
PID_FILE="$INSTALL_DIR/.startup_pids"

# دالة التسجيل
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# دالة للتأكد من تحميل بيئة المستخدم
wait_for_user_env() {
    log "⏳ انتظار تحميل بيئة المستخدم..."
    
    # الانتظار حتى ظهور DISPLAY
    local max_wait=60
    local wait_count=0
    
    while [ -z "$DISPLAY" ] && [ $wait_count -lt $max_wait ]; do
        sleep 2
        export DISPLAY=":0"
        wait_count=$((wait_count + 2))
    done
    
    # التأكد من وجود DBUS
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    
    # انتظار إضافي للتأكد من تحميل الواجهة
    sleep 5
    
    log "✅ بيئة المستخدم جاهزة (DISPLAY=$DISPLAY)"
}

# دالة بدء الإشعارات
start_notifications() {
    log "🚀 بدء إشعارات الصلاة..."
    
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        # التحقق من وجود الإعدادات
        if [ -f "$INSTALL_DIR/settings.conf" ]; then
            cd "$INSTALL_DIR"
            "$INSTALL_DIR/gt-salat-dikr.sh" --notify-start >/dev/null 2>&1 &
            local notify_pid=$!
            sleep 3
            
            if ps -p $notify_pid >/dev/null 2>&1; then
                log "✅ إشعارات الصلاة تعمل (PID: $notify_pid)"
                echo "NOTIFY_PID=$notify_pid" > "$PID_FILE"
                return $notify_pid
            else
                log "⚠️  إشعارات الصلاة توقفت، محاولة بديلة..."
                # محاولة بدء يدوي
                nohup bash -c "cd '$INSTALL_DIR' && '$INSTALL_DIR/gt-salat-dikr.sh' --child-notify" >/dev/null 2>&1 &
                local alt_pid=$!
                sleep 2
                if ps -p $alt_pid >/dev/null 2>&1; then
                    log "✅ إشعارات الصلاة تعمل بالبديل (PID: $alt_pid)"
                    echo "NOTIFY_PID=$alt_pid" > "$PID_FILE"
                    return $alt_pid
                fi
            fi
        else
            log "❌ ملف الإعدادات غير موجود، تشغيل الإعدادات أولاً..."
            "$INSTALL_DIR/gt-salat-dikr.sh" --settings
            sleep 2
            start_notifications
        fi
    fi
    
    log "❌ فشل بدء إشعارات الصلاة"
    return 0
}

# دالة بدء System Tray
start_system_tray() {
    log "🖥️  بدء System Tray..."
    
    # التحقق من مكتبات Python
    if ! command -v python3 >/dev/null 2>&1; then
        log "❌ Python3 غير مثبت، System Tray غير متاح"
        return 0
    fi
    
    # التحقق من مكتبات pystray و PIL
    if ! python3 -c "import pystray, PIL" 2>/dev/null; then
        log "⚠️  مكتبات Python غير مثبتة، System Tray غير متاح"
        return 0
    fi
    
    if [ -f "$INSTALL_DIR/gt-tray.py" ]; then
        cd "$INSTALL_DIR"
        python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
        local tray_pid=$!
        sleep 5
        
        if ps -p $tray_pid >/dev/null 2>&1; then
            log "✅ System Tray يعمل (PID: $tray_pid)"
            echo "TRAY_PID=$tray_pid" >> "$PID_FILE" 2>/dev/null || true
            return $tray_pid
        else
            # محاولة بديلة
            log "⚠️  System Tray توقف، محاولة بديلة..."
            nohup python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
            local alt_pid=$!
            sleep 3
            if ps -p $alt_pid >/dev/null 2>&1; then
                log "✅ System Tray يعمل بالبديل (PID: $alt_pid)"
                echo "TRAY_PID=$alt_pid" >> "$PID_FILE" 2>/dev/null || true
                return $alt_pid
            fi
        fi
    fi
    
    log "❌ فشل بدء System Tray"
    return 0
}

# دالة مراقبة وإعادة تشغيل
monitor_and_restart() {
    local notify_pid=$1
    local tray_pid=$2
    
    log "👀 بدء المراقبة والإعادة التلقائية..."
    
    while true; do
        sleep 30
        
        # التحقق من إشعارات الصلاة
        if [ $notify_pid -gt 0 ] && ! ps -p $notify_pid >/dev/null 2>&1; then
            log "⚠️  إشعارات الصلاة توقفت، إعادة التشغيل..."
            notify_pid=$(start_notifications)
        fi
        
        # التحقق من System Tray
        if [ $tray_pid -gt 0 ] && ! ps -p $tray_pid >/dev/null 2>&1; then
            log "⚠️  System Tray توقف، إعادة التشغيل..."
            tray_pid=$(start_system_tray)
        fi
    done
}

# التنظيف عند الخروج
cleanup() {
    log "🛑 إيقاف مدير التشغيل التلقائي..."
    
    if [ -f "$PID_FILE" ]; then
        source "$PID_FILE" 2>/dev/null || true
        
        if [ -n "$NOTIFY_PID" ] && [ "$NOTIFY_PID" -gt 0 ]; then
            kill "$NOTIFY_PID" 2>/dev/null || true
        fi
        
        if [ -n "$TRAY_PID" ] && [ "$TRAY_PID" -gt 0 ]; then
            kill "$TRAY_PID" 2>/dev/null || true
        fi
        
        rm -f "$PID_FILE" 2>/dev/null || true
    fi
    
    log "✅ تم التنظيف"
    exit 0
}

# إعداد معالج الإشارات
trap cleanup EXIT INT TERM

# بدء البرنامج
log "════════════════════════════════════════════════════════"
log "🚀 بدء تشغيل GT-salat-dikr التلقائي"
log "════════════════════════════════════════════════════════"

# الانتظار لتحميل بيئة المستخدم
wait_for_user_env

# بدء الإشعارات
NOTIFY_PID=$(start_notifications)

# انتظار ثم بدء System Tray
sleep 8
TRAY_PID=$(start_system_tray)

log "✅ اكتمل التشغيل التلقائي"
log "📊 الحالة - الإشعارات: $NOTIFY_PID, System Tray: $TRAY_PID"
log "════════════════════════════════════════════════════════"

# بدء المراقبة
monitor_and_restart $NOTIFY_PID $TRAY_PID
EOF

chmod +x "$STARTUP_SCRIPT"
echo "✅ تم إنشاء مدير التشغيل التلقائي"

# ---------- المرحلة 8: إعداد التشغيل التلقائي الكامل ----------
echo ""
echo "🔧 إعداد التشغيل التلقائي الكامل..."

setup_autostart_systemd() {
    echo "🔄 إعداد خدمات systemd..."
    
    mkdir -p "$HOME/.config/systemd/user"
    
    # خدمة مدير التشغيل التلقائي (الرئيسية)
    cat > "$HOME/.config/systemd/user/gt-salat-dikr-autostart.service" <<EOF
[Unit]
Description=GT-salat-dikr Complete Auto-start (Notifications + System Tray)
After=graphical-session.target
Wants=graphical-session.target
Requires=dbus.socket

[Service]
Type=simple
ExecStart=$STARTUP_SCRIPT
Restart=always
RestartSec=10
Environment="DISPLAY=:0"
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="XDG_RUNTIME_DIR=/run/user/%U"
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

# تأخير البدء لضمان تحميل الواجهة
ExecStartPre=/bin/sleep 10

# إعادة التشغيل على الفشل
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload >/dev/null 2>&1
    systemctl --user enable gt-salat-dikr-autostart.service >/dev/null 2>&1
    
    echo "✅ تم تفعيل خدمة systemd للتشغيل التلقائي"
    
    # بدء الخدمة الآن
    if systemctl --user start gt-salat-dikr-autostart.service >/dev/null 2>&1; then
        echo "✅ تم بدء الخدمة الآن"
        sleep 3
    fi
}

setup_autostart_desktop() {
    echo "🔄 إعداد ملفات desktop للتشغيل التلقائي..."
    
    mkdir -p "$HOME/.config/autostart"
    
    # ملف desktop للتشغيل التلقائي
    cat > "$HOME/.config/autostart/gt-salat-dikr-autostart.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr (Complete Auto-start)
Comment=Auto-start prayer notifications and system tray icon
Exec=bash -c "sleep 15 && '$STARTUP_SCRIPT'"
Icon=$ICON_DIR/prayer-icon-32.png
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-Delay=15
EOF
    
    echo "✅ تم إنشاء ملف autostart desktop"
    
    # بدء التشغيل الآن (بعد تأخير)
    echo "⏳ سيبدأ التشغيل خلال 15 ثانية..."
    bash -c "sleep 15 && '$STARTUP_SCRIPT' >/dev/null 2>&1 &" &
}

# التحديد حسب نظام التشغيل
case "$NOTIFY_SYSTEM" in
    "systemd")
        setup_autostart_systemd
        ;;
    *)
        setup_autostart_desktop
        ;;
esac

# ---------- المرحلة 9: إعدادات الطرفية ----------
echo ""
echo "🔧 إعدادات الطرفية..."

setup_terminal_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # التحقق إذا كانت الإعدادات موجودة مسبقاً
        if ! grep -q "gtsalat" "$shell_file" 2>/dev/null; then
            echo "" >> "$shell_file"
            echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$shell_file"
            echo "alias gtsalat='$HOME/.local/bin/gtsalat'" >> "$shell_file"
            echo "echo ''" >> "$shell_file"
            echo "$HOME/.local/bin/gtsalat" >> "$shell_file"
            echo "✅ تم إضافة إعدادات GT-salat-dikr إلى $shell_name"
        else
            echo "ℹ️  إعدادات GT-salat-dikr موجودة مسبقاً في $shell_name"
        fi
    else
        echo "⚠️  ملف $shell_name غير موجود، تخطي الإعدادات"
    fi
}

# إعدادات لأنواع الطرفيات المختلفة
setup_terminal_config "$HOME/.bashrc" "Bash"

if [ -f "$HOME/.zshrc" ]; then
    setup_terminal_config "$HOME/.zshrc" "Zsh"
fi

if [ -f "$HOME/.bash_profile" ]; then
    setup_terminal_config "$HOME/.bash_profile" "Bash Profile"
fi

echo "✅ تم إعداد الطرفية لعرض الذكر وموعد الصلاة عند الافتتاح"

# ---------- المرحلة 10: تثبيت مكتبات Python ----------
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

# ---------- المرحلة 11: التشغيل الاختباري المباشر ----------
echo ""
echo "🚀 بدء تشغيل اختباري..."

# بدء الإشعارات الآن
echo "🔔 بدء إشعارات الصلاة..."
"$INSTALL_DIR/$MAIN_SCRIPT" --notify-start >/dev/null 2>&1 &
sleep 5

# بدء System Tray إذا كانت المكتبات متوفرة
if [ "$PYTHON_DEPS_OK" -eq 1 ] && [ -f "$TRAY_SCRIPT" ]; then
    echo "🖥️  بدء تشغيل System Tray..."
    python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    sleep 3
    echo "✅ تم تشغيل System Tray"
    echo "📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
else
    echo "ℹ️  يمكنك تشغيل System Tray لاحقاً: gtsalat --tray"
fi

# ---------- المرحلة 12: العرض النهائي ----------
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
echo "⚙️  ملخص ميزات التشغيل التلقائي المثبتة:"
echo "════════════════════════════════════════════════════════"
echo "✅ التشغيل التلقائي عند الإقلاع"
echo "✅ System Tray يظهر تلقائياً"
echo "✅ إشعارات الصلاة والأذكار تعمل تلقائياً"
echo "✅ مدير مراقبة وإعادة تشغيل تلقائي"
echo "✅ تأخير ذكي لتحميل واجهة المستخدم"
echo "✅ حفظ السجلات في: $LOG_FILE"
echo "✅ PID Management في: $INSTALL_DIR/.startup_pids"
echo "════════════════════════════════════════════════════════"

echo ""
echo "📋 الإعدادات المطبقة:"
echo "════════════════════════════════════════════════════════"
echo "📍 الموقع: $CITY, $COUNTRY"
echo "🧭 الإحداثيات: $LAT, $LON"
echo "📖 طريقة الحساب: $METHOD_NAME"
echo "⏰ التنبيه قبل الصلاة: $PRE_PRAYER_NOTIFY دقيقة"
echo "🕊️ فاصل الأذكار: $((ZIKR_NOTIFY_INTERVAL/60)) دقيقة"
echo "📢 نوع الأذان: $ADHAN_TYPE (قصير افتراضي)"
echo "🔔 جميع الإشعارات: مفعلة ✓"
echo "🛠 نظام التشغيل التلقائي: $NOTIFY_SYSTEM"
echo "💾 التخزين المحلي: جاري التحميل تلقائياً ✓"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔧 أوامر التحكم السريعة:"
echo "════════════════════════════════════════════════════════"
echo "gtsalat                    # عرض ذكر وموعد الصلاة (عند فتح terminal)"
echo "gtsalat --show-timetable   # عرض مواقيت اليوم"
echo "gtsalat --status          # عرض حالة البرنامج"
echo "gtsalat --settings        # تعديل الإعدادات"
echo "gtsalat --notify-stop     # إيقاف الإشعارات مؤقتاً"
echo "gtsalat --notify-start    # استئناف الإشعارات"
echo "gtsalat --tray            # تشغيل System Tray يدوياً"
echo "gtsalat --tray-restart    # إعادة تشغيل System Tray"
echo "gtsalat --tray-stop       # إيقاف System Tray"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔄 إدارة التشغيل التلقائي:"
echo "════════════════════════════════════════════════════════"
if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    echo "systemctl --user status gt-salat-dikr-autostart.service"
    echo "systemctl --user restart gt-salat-dikr-autostart.service"
    echo "systemctl --user stop gt-salat-dikr-autostart.service"
else
    echo "📁 ملف autostart: ~/.config/autostart/gt-salat-dikr-autostart.desktop"
    echo "⚙️  السكربت الرئيسي: $STARTUP_SCRIPT"
fi
echo "📋 السجلات: tail -f $LOG_FILE"
echo "🔍 حالة العمليات: cat $INSTALL_DIR/.startup_pids 2>/dev/null || echo 'لم تبدأ بعد'"
echo "════════════════════════════════════════════════════════"

echo ""
echo "📝 ملاحظات مهمة:"
echo "════════════════════════════════════════════════════════"
echo "• البرنامج يعمل تلقائياً عند تشغيل الجهاز وإقلاع النظام"
echo "• System Tray يظهر بعد تحميل واجهة المستخدم"
echo "• الإشعارات تبدأ بعد 10-15 ثانية من الإقلاع"
echo "• المدير يراقب ويُعيد التشغيل تلقائياً عند الحاجة"
echo "• يمكنك تعديل أي إعداد لاحقاً: gtsalat --settings"
echo "• عند فتح terminal جديد، سيظهر تلقائياً ذكر وموعد الصلاة"
echo "════════════════════════════════════════════════════════"

echo ""
echo "✅ تم اكتمال التثبيت! البرنامج يعمل الآن."
echo ""
echo "🔄 أعِد تشغيل النظام للتحقق من عمل التشغيل التلقائي"
echo "   أو افتح terminal جديد لرؤية النتيجة"
echo ""
