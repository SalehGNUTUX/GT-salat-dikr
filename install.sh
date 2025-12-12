#!/bin/bash
#
# GT-salat-dikr - Complete Installation Script v3.2.5
# يدعم جميع التوزيعات ويتضمن System Tray وإعدادات الطرفية
# مع إصلاح مشكلة الإعدادات المتكررة
#

set -e

# ---------- تعريف المتغيرات ----------
INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
TEMP_LOG="/tmp/gt-salat-install-$$.log"

# ---------- عرض الشعار ----------
show_logo() {
    echo ""
    echo "      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ "
    echo "     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \\"
    echo "    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /"
    echo "     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\\"
    echo ""
    echo "     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2 🕋"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
}

show_logo

if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

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

# ---------- دالة التحقق من وجود المثبت ----------
ensure_installer() {
    if [ ! -f "$INSTALL_DIR/install.sh" ]; then
        echo "📥 جاري تنزيل المثبت إلى الموقع الدائم..."
        if curl -fsSL "$REPO_BASE/install.sh" -o "$INSTALL_DIR/install.sh" 2>/dev/null; then
            chmod +x "$INSTALL_DIR/install.sh"
            echo "✅ تم تنزيل المثبت إلى $INSTALL_DIR/install.sh"
        else
            echo "⚠️  فشل تنزيل المثبت، استخدام النسخة المؤقتة"
        fi
    fi
}

# ---------- دالة التسجيل ----------
log() {
    local message="$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$TEMP_LOG"
    # إذا كان مجلد التثبيت موجوداً، نسخ أيضاً إلى السجل الدائم
    if [ -d "$INSTALL_DIR" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$INSTALL_DIR/install.log" 2>/dev/null || true
    fi
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
            echo "  ⚠️  إنشاء أيقونة افتراضية ${size}x${size}"
            # استخدام ImageMagick أو إنشاء صورة بسيطة
            if command -v convert >/dev/null 2>&1; then
                convert -size "${size}x${size}" xc:none \
                    -fill "#2E7D32" -draw "rectangle $((size/4)),$((size*2/3)) $((size*3/4)),$((size*5/6))" \
                    -fill "#388E3C" -draw "rectangle $((size*5/16)),$((size*7/16)) $((size*11/16)),$((size*2/3))" \
                    -fill "#2196F3" -draw "ellipse $((size/2)),$((size*5/16)) $((size*3/16)),$((size/8)) 0,360" \
                    -fill "#FFEB3B" -stroke "#FFEB3B" -draw "arc $((size*7/16)),$((size/4)) $((size*9/16)),$((size*3/8)) 30,150" \
                    "$icon_file" 2>/dev/null || true
            else
                # إنشاء صورة بسيطة باستخدام Python
                python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGBA', ($size, $size), (255, 255, 255, 0))
draw = ImageDraw.Draw(img)
draw.rectangle([$((size/4)), $((size*2/3)), $((size*3/4)), $((size*5/6))], fill=(46, 125, 50))
draw.rectangle([$((size*5/16)), $((size*7/16)), $((size*11/16)), $((size*2/3))], fill=(56, 142, 60))
draw.ellipse([$((size*5/16)), $((size/4)), $((size*11/16)), $((size*3/8))], fill=(33, 150, 243))
draw.arc([$((size*7/16)), $((size/4)), $((size*9/16)), $((size*3/8))], 30, 150, fill=(255, 235, 59), width=2)
img.save('$icon_file')
" 2>/dev/null || true
            fi
        fi
    done
    
    if [ $downloaded -gt 0 ]; then
        echo "✅ تم تحميل $downloaded أيقونة"
    else
        echo "⚠️  تم إنشاء أيقونات افتراضية"
    fi
}

# ---------- دالة إعداد System Tray ----------
setup_system_tray() {
    echo ""
    echo "🖥️  إعداد System Tray..."
    
    # إنشاء مجلد التطبيقات إذا لم يكن موجوداً
    mkdir -p "$HOME/.local/share/applications"
    
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
    
    # إنشاء سكربت لبدء System Tray
    cat > "$INSTALL_DIR/start-tray.sh" <<'EOF'
#!/bin/bash
# بدء System Tray مع التحكم في التكرار

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOCK_FILE="/tmp/gt-salat-tray.lock"

# التحقق من القفل
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(date +%s)
    file_age=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
    if [ $((lock_age - file_age)) -lt 10 ]; then
        exit 0  # يعمل بالفعل
    fi
fi

# إنشاء قفل جديد
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ضبط البيئة
export DISPLAY="${DISPLAY:-:0}"
if [ -S "/run/user/$(id -u)/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi

# بدء System Tray
cd "$INSTALL_DIR"
python3 "$INSTALL_DIR/gt-tray.py"
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
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
        echo "✅ تم إنشاء رابط في: ~/.local/bin/gtsalat"
    fi
    
    # ---------- إعداد Bash ----------
    if [ -f "$HOME/.bashrc" ]; then
        echo "🔧 إعداد Bash (.bashrc)..."
        
        # إنشاء كتلة إعداد GT-salat-dikr
        GT_BLOCK="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'

# عرض الذكر وموعد الصلاة عند فتح الطرفية
if [ -f \"\$HOME/.local/bin/gtsalat\" ]; then
    gtsalat 2>/dev/null
fi
# نهاية كتلة GT-salat-dikر"
        
        # إزالة أي إعدادات قديمة
        if grep -q "# GT-salat-dikr" "$HOME/.bashrc"; then
            echo "  📝 تحديث الإعدادات الموجودة في .bashrc"
            # إزالة الكتلة القديمة
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$HOME/.bashrc" 2>/dev/null
        fi
        
        # إضافة الكتلة الجديدة في نهاية الملف
        echo "" >> "$HOME/.bashrc"
        echo "$GT_BLOCK" >> "$HOME/.bashrc"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى .bashrc"
    fi
    
    # ---------- إعداد Zsh ----------
    if [ -f "$HOME/.zshrc" ]; then
        echo "🔧 إعداد Zsh (.zshrc)..."
        
        # إنشاء كتلة إعداد GT-salat-dikr
        GT_BLOCK_ZSH="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'

# عرض الذكر وموعد الصلاة عند فتح الطرفية
if [ -f \"\$HOME/.local/bin/gtsalat\" ]; then
    gtsalat 2>/dev/null
fi
# نهاية كتلة GT-salat-dikر"
        
        # إزالة أي إعدادات قديمة
        if grep -q "# GT-salat-dikr" "$HOME/.zshrc"; then
            echo "  📝 تحديث الإعدادات الموجودة في .zshrc"
            # إزالة الكتلة القديمة
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$HOME/.zshrc" 2>/dev/null
        fi
        
        # إضافة الكتلة الجديدة في نهاية الملف
        echo "" >> "$HOME/.zshrc"
        echo "$GT_BLOCK_ZSH" >> "$HOME/.zshrc"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى .zshrc"
    fi
    
    # ---------- إعداد Fish ----------
    if [ -d "$HOME/.config/fish" ]; then
        echo "🔧 إعداد Fish shell..."
        
        # إنشاء ملف إعداد fish
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"
        
        GT_BLOCK_FISH="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'

# عرض الذكر وموعد الصلاة عند فتح الطرفية
if test -f \$HOME/.local/bin/gtsalat
    gtsalat 2>/dev/null
end
# نهاية كتلة GT-salat-dikر"
        
        # إزالة أي إعدادات قديمة
        if [ -f "$FISH_CONFIG" ] && grep -q "# GT-salat-dikr" "$FISH_CONFIG"; then
            echo "  📝 تحديث الإعدادات الموجودة في config.fish"
            # إزالة الكتلة القديمة
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$FISH_CONFIG" 2>/dev/null
        fi
        
        # إضافة الكتلة الجديدة
        echo "" >> "$FISH_CONFIG"
        echo "$GT_BLOCK_FISH" >> "$FISH_CONFIG"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى Fish shell"
    fi
}

# ---------- دالة تنفيذ الإعدادات الأولية ----------
run_initial_setup() {
    echo ""
    echo "⚙️  الإعدادات الأولية..."
    
    # التحقق إذا كانت الإعدادات موجودة مسبقاً
    if [ -f "$INSTALL_DIR/settings.conf" ]; then
        echo "📂 إعدادات موجودة مسبقاً، استخدامها..."
        
        # عرض محتوى الإعدادات الموجودة
        echo "📊 الإعدادات الحالية:"
        echo "════════════════════════════════════════════════════════"
        grep -E "(LAT|LON|CITY|COUNTRY|METHOD_NAME)" "$INSTALL_DIR/settings.conf" 2>/dev/null | head -10 || true
        echo "════════════════════════════════════════════════════════"
        
        echo ""
        echo "💡 للإبقاء على هذه الإعدادات، اضغط Enter"
        echo "   لتغيير الإعدادات، اكتب 'change' ثم Enter"
        read -p "اختيارك [Enter للاستمرار]: " user_choice
        
        if [[ "$user_choice" == "change" ]]; then
            echo "🔄 تشغيل معالج الإعدادات..."
            "$INSTALL_DIR/gt-salat-dikr.sh" --settings 2>/dev/null || {
                echo "⚠️  يمكنك تشغيل الإعدادات لاحقاً باستخدام: gtsalat --settings"
            }
        else
            echo "✅ تم استخدام الإعدادات الموجودة"
        fi
        
        return 0
    fi
    
    # التحقق إذا كان البرنامج يعمل لأول مرة
    echo "🔍 هذا يبدو أنه التثبيت الأول..."
    echo "🔄 تشغيل معالج الإعدادات..."
    
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        # تشغيل معالج الإعدادات مع تجاهل الإخراج
        "$INSTALL_DIR/gt-salat-dikr.sh" --settings > /dev/null 2>&1 || {
            echo "⚠️  يمكنك تشغيل الإعدادات لاحقاً باستخدام: gtsalat --settings"
        }
    else
        echo "⚠️  ملف البرنامج الرئيسي غير موجود، لا يمكن تشغيل الإعدادات"
        echo "💡 قم بتشغيل الإعدادات يدوياً بعد التثبيت: gtsalat --settings"
    fi
}

# ---------- دالة بدء الخدمات ----------
start_services() {
    echo ""
    echo "🚀 بدء الخدمات..."
    
    # التحقق من وجود الإعدادات أولاً
    if [ ! -f "$INSTALL_DIR/settings.conf" ]; then
        echo "⚠️  لم يتم إعداد البرنامج بعد"
        echo "💡 قم بتشغيل الإعدادات أولاً باستخدام: gtsalat --settings"
        return 1
    fi
    
    # بدء الإشعارات
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        echo "🔔 بدء إشعارات الصلاة..."
        "$INSTALL_DIR/gt-salat-dikr.sh" --notify-start >/dev/null 2>&1 &
        sleep 2
        if pgrep -f "gt-salat-dikr" >/dev/null 2>&1; then
            echo "✅ تم بدء إشعارات الصلاة"
        else
            echo "⚠️  قد تكون الإشعارات بحاجة لإعدادات أولية"
        fi
    fi
    
    # بدء System Tray
    sleep 3
    if [ -f "$INSTALL_DIR/gt-tray.py" ] && command -v python3 >/dev/null 2>&1; then
        if python3 -c "import pystray, PIL" 2>/dev/null; then
            echo "🖥️  بدء System Tray..."
            python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
            sleep 3
            if pgrep -f "gt-tray.py" >/dev/null 2>&1; then
                echo "✅ تم بدء System Tray"
                echo "📌 ستظهر الأيقونة في شريط المهام خلال لحظات"
            else
                echo "⚠️  فشل بدء System Tray"
            fi
        else
            echo "⚠️  مكتبات Python غير مثبتة، لا يمكن تشغيل System Tray"
            echo "💡 يمكنك تثبيتها باستخدام: $INSTALL_DIR/install-python-deps.sh"
        fi
    fi
}

# ---------- دالة نسخ السجل إلى الموقع الدائم ----------
copy_log_to_permanent_location() {
    if [ -f "$TEMP_LOG" ] && [ -d "$INSTALL_DIR" ]; then
        cp "$TEMP_LOG" "$INSTALL_DIR/install.log" 2>/dev/null || true
        rm -f "$TEMP_LOG" 2>/dev/null || true
    fi
}

# ---------- دالة إعداد اختياري لإظهار الذكر ----------
setup_terminal_display() {
    echo ""
    echo "🔄 إعداد عرض الذكر في الطرفية..."
    
    # إنشاء ملف تكوين خاص لعرض الذكر
    cat > "$INSTALL_DIR/terminal-display.sh" <<'EOF'
#!/bin/bash
# عرض الذكر وموعد الصلاة في الطرفية

# دالة للتحقق من عرض الذكر
show_gt_salat_info() {
    if [ -f "$HOME/.local/bin/gtsalat" ]; then
        # تشغيل gtsalat بدون معلمات لعرض الذكر والصلاة القادمة
        "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    fi
}

# عرض المعلومات إذا لم تكن في وضع غير تفاعلي
if [[ $- == *i* ]] && [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
    show_gt_salat_info
fi
EOF
    
    chmod +x "$INSTALL_DIR/terminal-display.sh"
    
    # إضافة استدعاء هذا السكربت إلى ملفات shell
    add_to_shell_config() {
        local shell_file="$1"
        local shell_name="$2"
        
        if [ -f "$shell_file" ]; then
            # إضافة سطر استدعاء السكربت
            if ! grep -q "terminal-display.sh" "$shell_file"; then
                echo "" >> "$shell_file"
                echo "# تشغيل GT-salat-dikr عند فتح الطرفية" >> "$shell_file"
                echo "if [ -f \"$INSTALL_DIR/terminal-display.sh\" ]; then" >> "$shell_file"
                echo "    . \"$INSTALL_DIR/terminal-display.sh\"" >> "$shell_file"
                echo "fi" >> "$shell_file"
                echo "✅ تم إضافة استدعاء GT-salat-dikr إلى $shell_name"
            fi
        fi
    }
    
    # إضافة إلى bashrc و zshrc
    add_to_shell_config "$HOME/.bashrc" ".bashrc"
    add_to_shell_config "$HOME/.zshrc" ".zshrc"
    
    # إضافة إلى fish config
    if [ -d "$HOME/.config/fish" ]; then
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        if [ -f "$FISH_CONFIG" ] && ! grep -q "terminal-display.sh" "$FISH_CONFIG"; then
            echo "" >> "$FISH_CONFIG"
            echo "# تشغيل GT-salat-dikr عند فتح الطرفية" >> "$FISH_CONFIG"
            echo "if test -f \"$INSTALL_DIR/terminal-display.sh\"" >> "$FISH_CONFIG"
            echo "    source \"$INSTALL_DIR/terminal-display.sh\"" >> "$FISH_CONFIG"
            echo "end" >> "$FISH_CONFIG"
            echo "✅ تم إضافة استدعاء GT-salat-dikr إلى Fish config"
        fi
    fi
}

# ---------- بدء التثبيت ----------
main() {
    # التحقق من وجود المثبت
    ensure_installer
    
    # بدء السجل المؤقت
    echo "📝 بدء سجل التثبيت..."
    echo "════════════════════════════════════════════════════════" > "$TEMP_LOG"
    echo "بدء تثبيت GT-salat-dikr" >> "$TEMP_LOG"
    echo "التاريخ: $(date)" >> "$TEMP_LOG"
    echo "المستخدم: $(whoami)" >> "$TEMP_LOG"
    echo "════════════════════════════════════════════════════════" >> "$TEMP_LOG"
    
    echo "📁 مجلد التثبيت: $INSTALL_DIR"
    log "مجلد التثبيت: $INSTALL_DIR"
    
    # ---------- المرحلة 0: تنظيف مجلد قديم إن وجد ----------
    if [ -d "$INSTALL_DIR" ]; then
        echo "📂 مجلد موجود مسبقاً، تنظيف..."
        log "مجلد موجود مسبقاً، تنظيف المحتويات"
        
        # حذف الملفات القديمة مع الاحتفاظ بالإعدادات إن وجدت
        if [ -f "$INSTALL_DIR/settings.conf" ]; then
            echo "💾 الاحتفاظ بالإعدادات الموجودة"
            cp "$INSTALL_DIR/settings.conf" "/tmp/gt-salat-settings-backup-$$.conf" 2>/dev/null || true
        fi
        
        # حذف جميع الملفات عدا الإعدادات المهمة
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.log" -delete 2>/dev/null || true
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.pid" -delete 2>/dev/null || true
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.tmp" -delete 2>/dev/null || true
    else
        # إنشاء مجلد التثبيت
        mkdir -p "$INSTALL_DIR"
    fi
    
    # الانتقال إلى مجلد التثبيت
    cd "$INSTALL_DIR"
    
    # استعادة الإعدادات إذا كانت موجودة
    if [ -f "/tmp/gt-salat-settings-backup-$$.conf" ]; then
        cp "/tmp/gt-salat-settings-backup-$$.conf" "$INSTALL_DIR/settings.conf" 2>/dev/null || true
        rm -f "/tmp/gt-salat-settings-backup-$$.conf" 2>/dev/null || true
        echo "✅ تم استعادة الإعدادات السابقة"
    fi
    
    # ---------- المرحلة 1: تنزيل الملفات ----------
    echo ""
    echo "📥 جاري تنزيل الملفات..."
    log "بدأ تنزيل الملفات"
    
    local download_count=0
    local failed_count=0
    
    for file in "${FILES_TO_DOWNLOAD[@]}"; do
        if download_file "$file"; then
            download_count=$((download_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done
    
    echo "📊 تنزيل الملفات: $download_count ✅, $failed_count ❌"
    log "اكتمل تنزيل الملفات: $download_count نجاح, $failed_count فشل"
    
    # جعل الملفات قابلة للتنفيذ
    chmod +x "$INSTALL_DIR/gt-salat-dikr.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/gt-tray.py" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/uninstall.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/install-system-tray.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/install-python-deps.sh" 2>/dev/null || true
    
    # ---------- المرحلة 2: تنزيل الأيقونات ----------
    download_icons
    log "تم تنزيل/إنشاء الأيقونات"
    
    # ---------- المرحلة 3: تثبيت اعتماديات Python ----------
    install_python_deps
    log "تم تثبيت اعتماديات Python"
    
    # ---------- المرحلة 4: إعداد System Tray ----------
    setup_system_tray
    log "تم إعداد System Tray"
    
    # ---------- المرحلة 5: إعداد الطرفية ----------
    setup_terminal
    log "تم إعداد الطرفية"
    
    # ---------- المرحلة 6: إعداد عرض الذكر في الطرفية ----------
    setup_terminal_display
    log "تم إعداد عرض الذكر في الطرفية"
    
    # ---------- المرحلة 7: الإعدادات الأولية ----------
    run_initial_setup
    log "تم تنفيذ الإعدادات الأولية"
    
    # ---------- المرحلة 8: بدء الخدمات ----------
    start_services
    log "تم بدء الخدمات"
    
    # ---------- المرحلة 9: نسخ السجل إلى الموقع الدائم ----------
    copy_log_to_permanent_location
    
    # ---------- المرحلة 10: التقرير النهائي ----------
    show_logo
    echo "🎉 تم التثبيت بنجاح!"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 الملفات المثبتة:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "📁 $INSTALL_DIR/"
    echo "  📄 gt-salat-dikr.sh (البرنامج الرئيسي)"
    echo "  📄 gt-tray.py (أيقونة System Tray)"
    echo "  📄 terminal-display.sh (عرض الذكر في الطرفية)"
    echo "  📄 uninstall.sh (إلغاء التثبيت)"
    echo "  📄 install-system-tray.sh (تثبيت System Tray)"
    echo "  📄 install-python-deps.sh (تثبيت اعتماديات Python)"
    echo "  📄 azkar.txt (قائمة الأذكار)"
    echo "  📁 icons/ (مجلد الأيقونات)"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🔧 طرق التشغيل:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "1. من الطرفية: gtsalat"
    echo "2. من قائمة البرامج: ابحث عن 'GT-salat-dikr'"
    echo "3. من System Tray: انقر بزر الماوس الأيمن على الأيقونة"
    echo "4. تلقائياً: عند إقلاع النظام"
    echo "5. عند فتح الطرفية: سيظهر الذكر والصلاة القادمة تلقائياً"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "⚙️  أوامر مفيدة:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "gtsalat --help              عرض المساعدة"
    echo "gtsalat --settings          تغيير الإعدادات"
    echo "gtsalat --tray              تشغيل System Tray"
    echo "gtsalat --status            عرض حالة البرنامج"
    echo "gtsalat --show-timetable    عرض مواقيت الصلاة"
    echo "gtsalat --update-timetables تحديث مواقيت الصلاة"
    echo "gtsalat --install           إعادة التثبيت (تحميل المثبت المحدث)"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📝 ملاحظات:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "• ستظهر الذكر والصلاة القادمة عند فتح أي طرفية جديدة"
    echo "• System Tray يحتاج إلى مكتبات Python (pystray, pillow)"
    echo "• البرنامج سيبدأ تلقائياً عند إقلاع النظام"
    echo "• للتحديث: gtsalat --full-update"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🔄 لتطبيق التغييرات في الطرفية الحالية:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "source ~/.bashrc   # لـ Bash"
    echo "source ~/.zshrc    # لـ Zsh"
    echo "source ~/.config/fish/config.fish  # لـ Fish"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🗑️  إلغاء التثبيت:"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "bash $INSTALL_DIR/uninstall.sh"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    
    log "اكتمل التثبيت بنجاح"
    
    # تنظيف السجل المؤقت
    rm -f "$TEMP_LOG" 2>/dev/null || true
}

# تنفيذ التثبيت
main

exit 0
