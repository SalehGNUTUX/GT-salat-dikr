#!/bin/bash
#
# GT-salat-dikr - Complete Installation Script v3.2.3
# يدعم جميع التوزيعات ويتضمن System Tray تلقائياً
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

# ---------- تعريف المتغيرات ----------
INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
LOG_FILE="$INSTALL_DIR/install.log"
TEMP_DIR="/tmp/gt-salat-install-$$"

# قائمة الملفات المطلوبة
FILES_TO_DOWNLOAD=(
    "gt-salat-dikr.sh"
    "azkar.txt"
    "adhan.ogg"
    "short_adhan.ogg"
    "prayer_approaching.ogg"
    "gt-tray.py"
    "install-system-tray.sh"
    "install-python-deps.sh"
    "uninstall.sh"
    "LICENSE"
    "README.md"
)

# ---------- دالة التسجيل ----------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# ---------- دالة التنزيل ----------
download_file() {
    local file=$1
    local url="$REPO_BASE/$file"
    local dest="$INSTALL_DIR/$file"
    
    log "جاري تنزيل: $file"
    
    if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        echo "  ✅ تم تنزيل: $file"
        return 0
    else
        echo "  ⚠️  فشل تنزيل: $file"
        return 1
    fi
}

# ---------- دالة تثبيت اعتماديات Python ----------
install_python_deps() {
    echo ""
    echo "📦 تثبيت اعتماديات Python لـ System Tray..."
    
    if [ -f "$INSTALL_DIR/install-python-deps.sh" ]; then
        chmod +x "$INSTALL_DIR/install-python-deps.sh"
        
        # تثبيت الاعتماديات
        if "$INSTALL_DIR/install-python-deps.sh" 2>/dev/null; then
            echo "✅ تم تثبيت اعتماديات Python بنجاح"
            return 0
        else
            echo "⚠️  فشل في تثبيت الاعتماديات عبر السكربت"
            echo "🔄 المحاولة يدوياً..."
        fi
    fi
    
    # محاولة يدوية
    echo "🔍 المحاولة اليدوية لتثبيت اعتماديات Python..."
    
    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "✅ مكتبات Python مثبتة بالفعل"
    else
        echo "📦 تثبيت المكتبات عبر pip..."
        pip3 install --user pystray pillow requests 2>/dev/null || {
            echo "⚠️  فشل التثبيت عبر pip"
            echo "💡 يمكنك تثبيتها يدوياً لاحقاً:"
            echo "   pip3 install --user pystray pillow requests"
        }
    fi
    
    return 0
}

# ---------- دالة إنشاء الأيقونات ----------
download_icons() {
    local ICON_DIR="$INSTALL_DIR/icons"
    mkdir -p "$ICON_DIR"
    
    echo ""
    echo "⬇️  جاري تحميل الأيقونات..."
    
    local icon_sizes=("16" "32" "48" "64" "128" "256")
    local downloaded=0
    
    for size in "${icon_sizes[@]}"; do
        local icon_url="$REPO_BASE/icons/prayer-icon-${size}.png"
        local icon_file="$ICON_DIR/prayer-icon-${size}.png"
        
        if curl -fsSL "$icon_url" -o "$icon_file" 2>/dev/null; then
            echo "  ✅ أيقونة ${size}x${size}"
            downloaded=$((downloaded + 1))
        else
            # إنشاء أيقونة افتراضية إذا فشل التنزيل
            convert -size "${size}x${size}" xc:none \
                -fill "#2E7D32" -draw "rectangle $((size/4)),$((size*2/3)) $((size*3/4)),$((size*5/6))" \
                -fill "#388E3C" -draw "rectangle $((size*5/16)),$((size*7/16)) $((size*11/16)),$((size*2/3))" \
                -fill "#2196F3" -draw "ellipse $((size/2)),$((size*5/16)) $((size*3/16)),$((size/8)) 0,360" \
                -fill "#FFEB3B" -stroke "#FFEB3B" -draw "arc $((size*7/16)),$((size/4)) $((size*9/16)),$((size*3/8)) 30,150" \
                "$icon_file" 2>/dev/null || true
        fi
    done
    
    if [ $downloaded -gt 0 ]; then
        echo "✅ تم تحميل $downloaded أيقونة"
    fi
}

# ---------- دالة إعداد System Tray ----------
setup_system_tray() {
    echo ""
    echo "🖥️  إعداد System Tray..."
    
    # إنشاء ملف تطبيق لنظام القائمة
    cat > "$HOME/.local/share/applications/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=python3 $INSTALL_DIR/gt-tray.py
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Categories=Utility;
Terminal=false
StartupNotify=false
NoDisplay=false
Keywords=prayer;islam;azan;reminder;ذكر;صلاة
EOF
    
    # إنشاء ملف لتشغيل System Tray
    cat > "$INSTALL_DIR/start-tray.sh" <<EOF
#!/bin/bash
# بدء System Tray مع التحكم في التكرار

LOCK_FILE="/tmp/gt-salat-tray.lock"

if [ -f "\$LOCK_FILE" ]; then
    lock_age=\$(date +%s)
    file_age=\$(stat -c %Y "\$LOCK_FILE" 2>/dev/null || echo 0)
    if [ \$((lock_age - file_age)) -lt 10 ]; then
        exit 0
    fi
fi

echo \$\$ > "\$LOCK_FILE"
trap 'rm -f "\$LOCK_FILE"' EXIT

export DISPLAY="\${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$(id -u)/bus"

cd "$INSTALL_DIR"
exec python3 "$INSTALL_DIR/gt-tray.py"
EOF
    
    chmod +x "$INSTALL_DIR/start-tray.sh"
    
    # إنشاء سكربت لإدارة التشغيل التلقائي
    cat > "$INSTALL_DIR/autostart-manager.sh" <<'EOF'
#!/bin/bash
# مدير التشغيل التلقائي لـ GT-salat-dikr

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOG_FILE="$INSTALL_DIR/autostart.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

start_services() {
    log "بدء خدمات GT-salat-dikr..."
    
    # الانتظار لتحميل بيئة المستخدم
    for i in {1..30}; do
        if [ -n "$DISPLAY" ] && [ -S "/run/user/$(id -u)/bus" ]; then
            break
        fi
        sleep 1
    done
    
    export DISPLAY="${DISPLAY:-:0}"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    
    # بدء الإشعارات
    cd "$INSTALL_DIR"
    if [ -f "gt-salat-dikr.sh" ]; then
        ./gt-salat-dikr.sh --notify-start >/dev/null 2>&1 &
        log "تم بدء الإشعارات"
    fi
    
    # بدء System Tray بعد تأخير
    sleep 10
    if [ -f "gt-tray.py" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
        log "تم بدء System Tray"
    fi
}

case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        pkill -f "gt-salat-dikr\|gt-tray.py" 2>/dev/null || true
        log "تم إيقاف الخدمات"
        ;;
    *)
        start_services
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/autostart-manager.sh"
    
    # إعداد التشغيل التلقائي لجميع بيئات سطح المكتب
    setup_autostart
}

# ---------- دالة إعداد التشغيل التلقائي ----------
setup_autostart() {
    echo ""
    echo "🔧 إعداد التشغيل التلقائي..."
    
    # 1. نظام autostart القياسي
    mkdir -p "$HOME/.config/autostart"
    
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=Auto-start prayer notifications and system tray
Exec=bash -c 'sleep 20 && "$INSTALL_DIR/autostart-manager.sh"'
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
"$INSTALL_DIR/autostart-manager.sh" &
EOF
        chmod +x "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh"
        echo "✅ تم إعداد التشغيل التلقائي لـ KDE Plasma"
    fi
    
    # 3. لـ XFCE
    if command -v xfce4-session >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/xfce4/autostart"
        cp "$HOME/.config/autostart/gt-salat-dikr.desktop" "$HOME/.config/xfce4/autostart/"
        echo "✅ تم إعداد التشغيل التلقائي لـ XFCE"
    fi
    
    # 4. لـ LXDE/LXQt
    if [ -d "$HOME/.config/lxsession" ]; then
        mkdir -p "$HOME/.config/lxsession/LXDE"
        echo "@bash \"$INSTALL_DIR/autostart-manager.sh\"" >> "$HOME/.config/lxsession/LXDE/autostart" 2>/dev/null
        echo "✅ تم إعداد التشغيل التلقائي لـ LXDE/LXQt"
    fi
    
    echo "✅ تم إعداد التشغيل التلقائي"
}

# ---------- دالة إعداد الطرفية ----------
setup_terminal() {
    echo ""
    echo "🔧 إعدادات الطرفية..."
    
    # إنشاء رابط في PATH
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    
    # إضافة إلى bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "gtsalat" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$HOME/.bashrc"
            echo "alias gtsalat='$HOME/.local/bin/gtsalat'" >> "$HOME/.bashrc"
            echo "echo ''" >> "$HOME/.bashrc"
            echo "$HOME/.local/bin/gtsalat" >> "$HOME/.bashrc"
            echo "✅ تم إضافة الألياس إلى .bashrc"
        fi
    fi
    
    # إضافة إلى zshrc
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "gtsalat" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# GT-salat-dikr - تذكير الصلاة والأذكار" >> "$HOME/.zshrc"
            echo "alias gtsalat='$HOME/.local/bin/gtsalat'" >> "$HOME/.zshrc"
            echo "✅ تم إضافة الألياس إلى .zshrc"
        fi
    fi
}

# ---------- بدء التثبيت ----------
main() {
    log "════════════════════════════════════════════════════════"
    log "بدء تثبيت GT-salat-dikr"
    log "التاريخ: $(date)"
    log "المستخدم: $(whoami)"
    log "════════════════════════════════════════════════════════"
    
    echo "📁 مجلد التثبيت: $INSTALL_DIR"
    
    # إنشاء مجلد التثبيت
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # ---------- المرحلة 1: تنزيل الملفات ----------
    echo ""
    echo "📥 جاري تنزيل الملفات..."
    
    for file in "${FILES_TO_DOWNLOAD[@]}"; do
        download_file "$file"
    done
    
    # جعل الملفات قابلة للتنفيذ
    chmod +x "$INSTALL_DIR/gt-salat-dikr.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/gt-tray.py" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/uninstall.sh" 2>/dev/null || true
    
    # ---------- المرحلة 2: تنزيل الأيقونات ----------
    download_icons
    
    # ---------- المرحلة 3: تثبيت اعتماديات Python ----------
    install_python_deps
    
    # ---------- المرحلة 4: إعداد System Tray ----------
    setup_system_tray
    
    # ---------- المرحلة 5: إعداد الطرفية ----------
    setup_terminal
    
    # ---------- المرحلة 6: الإعدادات الأولية ----------
    echo ""
    echo "⚙️  الإعدادات الأولية..."
    
    # تشغيل سكربت الإعدادات
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        echo "🔄 تشغيل معالج الإعدادات..."
        "$INSTALL_DIR/gt-salat-dikr.sh" --settings 2>/dev/null || {
            echo "⚠️  يمكنك تشغيل الإعدادات لاحقاً باستخدام: gtsalat --settings"
        }
    fi
    
    # ---------- المرحلة 7: بدء الخدمات ----------
    echo ""
    echo "🚀 بدء الخدمات..."
    
    # بدء الإشعارات
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        "$INSTALL_DIR/gt-salat-dikr.sh" --notify-start >/dev/null 2>&1 &
        echo "✅ تم بدء إشعارات الصلاة"
    fi
    
    # بدء System Tray بعد تأخير قصير
    sleep 3
    if [ -f "$INSTALL_DIR/gt-tray.py" ] && command -v python3 >/dev/null 2>&1; then
        if python3 -c "import pystray, PIL" 2>/dev/null; then
            python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
            echo "✅ تم بدء System Tray"
            echo "📌 ستظهر الأيقونة في شريط المهام خلال لحظات"
        else
            echo "⚠️  مكتبات Python غير مثبتة، لا يمكن تشغيل System Tray"
            echo "💡 يمكنك تثبيتها باستخدام: $INSTALL_DIR/install-python-deps.sh"
        fi
    fi
    
    # ---------- المرحلة 8: التقرير النهائي ----------
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "🎉 تم التثبيت بنجاح!"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "📋 الملفات المثبتة:"
    echo "════════════════════════════════════════════════════════"
    echo "📁 $INSTALL_DIR/"
    echo "  📄 gt-salat-dikr.sh (البرنامج الرئيسي)"
    echo "  📄 gt-tray.py (أيقونة System Tray)"
    echo "  📄 azkar.txt (قائمة الأذكار)"
    echo "  📄 uninstall.sh (إلغاء التثبيت)"
    echo "  📄 install-system-tray.sh (تثبيت System Tray)"
    echo "  📄 install-python-deps.sh (تثبيت اعتماديات Python)"
    echo "  📁 icons/ (مجلد الأيقونات)"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "🔧 طرق التشغيل:"
    echo "════════════════════════════════════════════════════════"
    echo "1. من الطرفية: gtsalat"
    echo "2. من قائمة البرامج: ابحث عن 'GT-salat-dikr'"
    echo "3. من System Tray: انقر بزر الماوس الأيمن على الأيقونة"
    echo "4. تلقائياً: عند إقلاع النظام"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "⚙️  أوامر مفيدة:"
    echo "════════════════════════════════════════════════════════"
    echo "gtsalat --help              عرض المساعدة"
    echo "gtsalat --settings          تغيير الإعدادات"
    echo "gtsalat --tray              تشغيل System Tray"
    echo "gtsalat --status            عرض حالة البرنامج"
    echo "gtsalat --show-timetable    عرض مواقيت الصلاة"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "🗑️  إلغاء التثبيت:"
    echo "════════════════════════════════════════════════════════"
    echo "bash $INSTALL_DIR/uninstall.sh"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "📝 ملاحظات:"
    echo "════════════════════════════════════════════════════════"
    echo "• قد تحتاج إلى إعادة تشغيل الطرفية لتفعيل الألياس"
    echo "• System Tray يحتاج إلى مكتبات Python (pystray, pillow)"
    echo "• البرنامج سيبدأ تلقائياً عند إقلاع النظام"
    echo "• للتحديث: gtsalat --self-update"
    echo "════════════════════════════════════════════════════════"
    
    log "اكتمل التثبيت بنجاح"
}

# تنفيذ التثبيت
main

exit 0
