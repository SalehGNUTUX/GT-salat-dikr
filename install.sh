#!/bin/bash
#
# GT-salat-dikr Fixed Auto-start Installation Script - v3.2.2-fixed
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr مع إصلاح الإقلاع التلقائي"
echo "════════════════════════════════════════════════════════"
echo ""

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
    echo "  تحميل: $file"
    curl -fsSL "$REPO_BASE/$file" -o "$file" 2>/dev/null || echo "  ⚠️  لم يتم تحميل $file"
done

chmod +x "$MAIN_SCRIPT" "gt-tray.py" 2>/dev/null || true

# ---------- المرحلة 2: إنشاء ملف .desktop للتطبيقات ----------
echo ""
echo "🖥️  إنشاء ملف تطبيق لنظام القائمة..."

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=$INSTALL_DIR/launcher.sh
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Categories=Utility;
Terminal=false
StartupNotify=false
NoDisplay=false
EOF

# إنشاء ملف Launcher ذكي
cat > "$INSTALL_DIR/launcher.sh" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Launcher - يمنع التكرار ويدير System Tray
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOCK_FILE="/tmp/gt-salat-dikr.lock"
TRAY_PID_FILE="/tmp/gt-salat-tray.pid"
NOTIFY_PID_FILE="$INSTALL_DIR/.notify.pid"

# دالة للتحقق من تشغيل System Tray
is_tray_running() {
    if [ -f "$TRAY_PID_FILE" ]; then
        local pid=$(cat "$TRAY_PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            return 0  # يعمل
        fi
    fi
    
    # التحقق عبر pgrep
    if pgrep -f "gt-tray.py" >/dev/null 2>&1; then
        # حفظ PID للاستخدام المستقبلي
        pgrep -f "gt-tray.py" | head -1 > "$TRAY_PID_FILE"
        return 0
    fi
    
    return 1  # غير يعمل
}

# دالة بدء System Tray
start_tray() {
    echo "🖥️  بدء تشغيل System Tray..."
    
    # الانتظار حتى تحميل بيئة المستخدم
    while [ -z "$DISPLAY" ]; do
        sleep 1
        export DISPLAY=":0"
    done
    
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    
    # تشغيل System Tray
    cd "$INSTALL_DIR"
    python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
    local tray_pid=$!
    
    # حفظ PID
    echo $tray_pid > "$TRAY_PID_FILE"
    sleep 3
    
    if ps -p $tray_pid >/dev/null 2>&1; then
        echo "✅ تم تشغيل System Tray (PID: $tray_pid)"
        return 0
    else
        echo "❌ فشل تشغيل System Tray"
        return 1
    fi
}

# دالة بدء الإشعارات
start_notifications() {
    echo "🔔 بدء إشعارات الصلاة..."
    
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        cd "$INSTALL_DIR"
        "$INSTALL_DIR/gt-salat-dikr.sh" --notify-start >/dev/null 2>&1 &
        local notify_pid=$!
        echo $notify_pid > "$NOTIFY_PID_FILE"
        sleep 2
        
        if ps -p $notify_pid >/dev/null 2>&1; then
            echo "✅ تم تشغيل الإشعارات (PID: $notify_pid)"
            return 0
        fi
    fi
    
    return 1
}

# دالة رئيسية
main() {
    # التحقق من القفل لمنع التكرار
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
        if [ $lock_age -lt 10 ]; then
            echo "⏳ البرنامج يعمل بالفعل، انتظر..."
            exit 0
        fi
    fi
    
    echo "🚀 بدء GT-salat-dikr..." > "$LOCK_FILE"
    
    # 1. بدء الإشعارات
    start_notifications
    
    # 2. التحقق وبدء System Tray إذا لم يكن يعمل
    if is_tray_running; then
        echo "✅ System Tray يعمل بالفعل"
    else
        start_tray
    fi
    
    # تنظيف القفل بعد التأخير
    sleep 5
    rm -f "$LOCK_FILE" 2>/dev/null || true
    
    echo "🎉 تم تشغيل GT-salat-dikr بنجاح!"
}

# التنفيذ
main
exit 0
EOF

chmod +x "$INSTALL_DIR/launcher.sh"

# نسخ ملف .desktop لمجلد التطبيقات
mkdir -p "$HOME/.local/share/applications"
cp "$DESKTOP_FILE" "$HOME/.local/share/applications/"
echo "✅ تم إنشاء رمز التطبيق في قائمة البرامج"

# ---------- المرحلة 3: إصلاح التشغيل التلقائي عند الإقلاع ----------
echo ""
echo "🔧 إصلاح التشغيل التلقائي عند الإقلاع..."

# إنشاء سكربت autostart محسن
cat > "$INSTALL_DIR/autostart-fixed.sh" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Auto-start Fixed - يعمل عند إقلاع النظام
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOG_FILE="$INSTALL_DIR/autostart.log"
MAX_WAIT=60  # أقصى وقت انتظار: 60 ثانية

# دالة التسجيل
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# دالة الانتظار لتحميل بيئة المستخدم
wait_for_desktop() {
    log "⏳ انتظار تحميل سطح المكتب..."
    
    local wait_time=0
    
    # الانتظار لظهور DISPLAY
    while [ -z "$DISPLAY" ] && [ $wait_time -lt $MAX_WAIT ]; do
        sleep 2
        export DISPLAY=":0"
        wait_time=$((wait_time + 2))
        
        # محاولة اكتشاف DISPLAY
        if [ -z "$DISPLAY" ] && [ -S "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=":0"
        fi
        
        log "الانتظار: $wait_time ثانية, DISPLAY=$DISPLAY"
    done
    
    # التأكد من DBUS
    if [ -S "/run/user/$(id -u)/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    else
        # البحث عن DBUS
        local dbus_path=$(find /tmp -name "dbus-*" -type s 2>/dev/null | head -1)
        if [ -n "$dbus_path" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$dbus_path"
        fi
    fi
    
    # انتظار إضافي للتأكد من تحميل البيئة
    sleep 8
    
    log "✅ بيئة المستخدم جاهزة - DISPLAY=$DISPLAY"
}

# دالة بدء الخدمات
start_services() {
    log "🚀 بدء خدمات GT-salat-dikر..."
    
    # 1. بدء الإشعارات
    log "بدء إشعارات الصلاة..."
    cd "$INSTALL_DIR"
    if [ -f "gt-salat-dikr.sh" ]; then
        # تحميل الإعدادات أولاً
        if [ -f "settings.conf" ]; then
            source "settings.conf" 2>/dev/null || true
        fi
        
        # بدء الإشعارات
        ./gt-salat-dikr.sh --notify-start >> "$LOG_FILE" 2>&1 &
        local notify_pid=$!
        sleep 5
        
        if ps -p $notify_pid >/dev/null 2>&1; then
            log "✅ إشعارات الصلاة تعمل (PID: $notify_pid)"
        else
            log "⚠️  فشل بدء الإشعارات، محاولة بديلة..."
            # محاولة مباشرة
            nohup bash -c 'cd "$INSTALL_DIR" && ./gt-salat-dikr.sh --child-notify' >> "$LOG_FILE" 2>&1 &
        fi
    fi
    
    # 2. بدء System Tray (بعد تأخير)
    sleep 10
    log "بدء System Tray..."
    
    if command -v python3 >/dev/null 2>&1 && [ -f "gt-tray.py" ]; then
        # التحقق من عدم تشغيله مسبقاً
        if ! pgrep -f "gt-tray.py" >/dev/null 2>&1; then
            python3 ./gt-tray.py >> "$LOG_FILE" 2>&1 &
            local tray_pid=$!
            sleep 5
            
            if ps -p $tray_pid >/dev/null 2>&1; then
                log "✅ System Tray يعمل (PID: $tray_pid)"
            else
                log "⚠️  فشل بدء System Tray"
            fi
        else
            log "✅ System Tray يعمل بالفعل"
        fi
    else
        log "❌ System Tray غير متوفر (Python أو الملف مفقود)"
    fi
}

# دالة رئيسية
main() {
    log "════════════════════════════════════════════════════════"
    log "بدء تشغيل GT-salat-dikر التلقائي"
    log "المستخدم: $(whoami)"
    log "التاريخ: $(date)"
    log "════════════════════════════════════════════════════════"
    
    # الانتظار لتحميل البيئة
    wait_for_desktop
    
    # بدء الخدمات
    start_services
    
    log "✅ اكتمل التشغيل التلقائي"
    log "════════════════════════════════════════════════════════"
}

# التنفيذ
main
EOF

chmod +x "$INSTALL_DIR/autostart-fixed.sh"

# إعداد autostart لكل بيئة سطح مكتب
setup_autostart_all() {
    echo "🔧 إعداد التشغيل التلقائي لجميع بيئات سطح المكتب..."
    
    # 1. نظام autostart القياسي
    mkdir -p "$HOME/.config/autostart"
    
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=Auto-start prayer notifications and system tray
Exec=bash -c 'sleep 20 && "$INSTALL_DIR/autostart-fixed.sh"'
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-Delay=20
EOF
    
    # 2. لـ KDE Plasma
    if [ -d "$HOME/.config/plasma-workspace/env" ]; then
        cat > "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" <<EOF
#!/bin/bash
sleep 25
"$INSTALL_DIR/autostart-fixed.sh" &
EOF
        chmod +x "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh"
    fi
    
    # 3. لـ XFCE
    if command -v xfce4-session >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/xfce4/autostart"
        cp "$HOME/.config/autostart/gt-salat-dikr.desktop" "$HOME/.config/xfce4/autostart/"
    fi
    
    # 4. لـ LXDE/LXQt
    if [ -d "$HOME/.config/lxsession" ]; then
        mkdir -p "$HOME/.config/lxsession/LXDE"
        echo "@bash \"$INSTALL_DIR/autostart-fixed.sh\"" >> "$HOME/.config/lxsession/LXDE/autostart" 2>/dev/null
    fi
    
    echo "✅ تم إعداد التشغيل التلقائي لجميع البيئات"
}

setup_autostart_all

# ---------- المرحلة 4: إعدادات إضافية ----------
echo ""
echo "⚙️  إعدادات إضافية..."

# 1. تحميل الأيقونات
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

# 2. إنشاء رابط في PATH
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true

# 3. إعدادات الطرفية
if [ -f "$HOME/.bashrc" ] && ! grep -q "gtsalat" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$HOME/.bashrc"
    echo "alias gtsalat='$HOME/.local/bin/gtsalat'" >> "$HOME/.bashrc"
    echo "echo ''" >> "$HOME/.bashrc"
    echo "$HOME/.local/bin/gtsalat" >> "$HOME/.bashrc"
fi

# ---------- المرحلة 5: بدء التشغيل الآن ----------
echo ""
echo "🚀 بدء تشغيل البرنامج الآن..."

# بدء autostart في الخلفية مع تأخير
bash -c "sleep 5 && '$INSTALL_DIR/autostart-fixed.sh' >/dev/null 2>&1 &" &

# عرض التعليمات
echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 تم التثبيت بنجاح!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 الميزات المثبتة:"
echo "════════════════════════════════════════════════════════"
echo "✅ ملف تطبيق في قائمة البرامج"
echo "✅ System Tray يمنع التكرار"
echo "✅ إصلاح التشغيل التلقائي عند الإقلاع"
echo "✅ أيقونات متعددة الأحجام"
echo "✅ دعم جميع بيئات سطح المكتب"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🔧 كيفية الاستخدام:"
echo "════════════════════════════════════════════════════════"
echo "1. افتح قائمة البرامج → ابحث عن 'GT-salat-dikr'"
echo "2. انقر عليه لبدء System Tray والإشعارات"
echo "3. System Tray لن يتكرر إذا كان يعمل"
echo "4. الإشعارات تبدأ تلقائياً عند الإقلاع"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📝 ملاحظات مهمة:"
echo "════════════════════════════════════════════════════════"
echo "• قد يستغرق التشغيل التلقائي 20-30 ثانية بعد الإقلاع"
echo "• System Tray يظهر فقط إذا كانت مكتبات Python مثبتة"
echo "• يمكنك التحكم عبر الأيقونة في شريط المهام"
echo "• للتحديث: gtsalat --self-update"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🔍 للتحقق من التشغيل:"
echo "════════════════════════════════════════════════════════"
echo "tail -f $INSTALL_DIR/autostart.log"
echo "ps aux | grep -E '(gt-salat|gt-tray)'"
echo "ls -la ~/.local/share/applications/ | grep gt-salat"
echo "════════════════════════════════════════════════════════"
