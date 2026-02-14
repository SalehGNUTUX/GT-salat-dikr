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

# ---------- دالة التسجيل ----------
log() {
    local message="$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$TEMP_LOG"
    if [ -d "$INSTALL_DIR" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$INSTALL_DIR/install.log" 2>/dev/null || true
    fi
}

# ---------- دالة كشف التوزيعة ومدير الحزم ----------
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    else
        DISTRO_ID="unknown"
    fi

    # كشف نظام التشغيل الأساسي (Linux/FreeBSD)
    case "$(uname -s)" in
        Linux) OS_TYPE="linux" ;;
        FreeBSD) OS_TYPE="freebsd" ;;
        *) OS_TYPE="unknown" ;;
    esac

    # تحديد مدير الحزم وأسماء الحزم
    # قيم افتراضية
    PKG_MANAGER="unknown"
    PKG_UPDATE=""
    PKG_INSTALL=""
    PYTHON3_PKG="python3"
    PYTHON_PKG_PYSTRAY=""
    PYTHON_PKG_PILLOW=""
    JQ_PKG=""
    IMAGEMAGICK_PKG=""

    case "$OS_TYPE-$DISTRO_ID" in
        linux-ubuntu|linux-debian|linux-linuxmint|linux-pop|linux-raspbian|linux-kali|linux-elementary|linux-zorin)
            PKG_MANAGER="apt"
            PKG_UPDATE="sudo apt update"
            PKG_INSTALL="sudo apt install -y"
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="python3-pystray"
            PYTHON_PKG_PILLOW="python3-pil"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="imagemagick"
            ;;
        linux-fedora|linux-*fedora*)
            PKG_MANAGER="dnf"
            PKG_UPDATE="sudo dnf check-update"
            PKG_INSTALL="sudo dnf install -y"
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="python3-pystray"
            PYTHON_PKG_PILLOW="python3-pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="ImageMagick"
            ;;
        linux-centos|linux-rhel|linux-rocky|linux-almalinux)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="sudo dnf check-update"
                PKG_INSTALL="sudo dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="sudo yum check-update"
                PKG_INSTALL="sudo yum install -y"
            fi
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="python3-pystray"
            PYTHON_PKG_PILLOW="python3-pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="ImageMagick"
            ;;
        linux-arch|linux-manjaro|linux-endeavouros|linux-arcolinux|linux-artix)
            PKG_MANAGER="pacman"
            PKG_UPDATE="sudo pacman -Sy"
            PKG_INSTALL="sudo pacman -S --noconfirm"
            PYTHON3_PKG="python"
            PYTHON_PKG_PYSTRAY="python-pystray"
            PYTHON_PKG_PILLOW="python-pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="imagemagick"
            ;;
        linux-opensuse*|linux-suse|linux-sles)
            PKG_MANAGER="zypper"
            PKG_UPDATE="sudo zypper refresh"
            PKG_INSTALL="sudo zypper install -y"
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="python3-pystray"
            PYTHON_PKG_PILLOW="python3-Pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="ImageMagick"
            ;;
        linux-alpine)
            PKG_MANAGER="apk"
            PKG_UPDATE="sudo apk update"
            PKG_INSTALL="sudo apk add"
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="py3-pystray"
            PYTHON_PKG_PILLOW="py3-pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="imagemagick"
            ;;
        linux-void)
            PKG_MANAGER="xbps"
            PKG_UPDATE="sudo xbps-install -S"
            PKG_INSTALL="sudo xbps-install -y"
            PYTHON3_PKG="python3"
            PYTHON_PKG_PYSTRAY="python3-pystray"
            PYTHON_PKG_PILLOW="python3-Pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="ImageMagick"
            ;;
        linux-gentoo)
            # لا نقوم بالتثبيت التلقائي على gentoo بسبب طبيعة emerge
            PKG_MANAGER="emerge"
            PKG_UPDATE="sudo emerge --sync"
            PKG_INSTALL="sudo emerge -av"
            PYTHON3_PKG="dev-lang/python"
            PYTHON_PKG_PYSTRAY="dev-python/pystray"
            PYTHON_PKG_PILLOW="dev-python/pillow"
            JQ_PKG="app-misc/jq"
            IMAGEMAGICK_PKG="media-gfx/imagemagick"
            # سنعتمد على pip في هذه الحالة
            PKG_MANAGER_AUTO=0
            ;;
        freebsd-*)
            PKG_MANAGER="pkg"
            PKG_UPDATE="sudo pkg update"
            PKG_INSTALL="sudo pkg install -y"
            PYTHON3_PKG="python3"
            # في FreeBSD نعتمد على pip لأن أسماء الحزم قد تختلف
            PYTHON_PKG_PYSTRAY="py39-pystray"   # غير مضمون، سنستخدم pip
            PYTHON_PKG_PILLOW="py39-pillow"
            JQ_PKG="jq"
            IMAGEMAGICK_PKG="ImageMagick7"
            PKG_MANAGER_AUTO=0  # نعتمد على pip
            ;;
        *)
            # unknown
            ;;
    esac

    log "تم الكشف: OS=$OS_TYPE, التوزيعة=${DISTRO_NAME:-$DISTRO_ID}, مدير الحزم=$PKG_MANAGER"
}

# ---------- دالة تثبيت حزمة باستخدام المدير المناسب ----------
install_system_package() {
    local pkg_var="$1"
    local pkg_name="${!pkg_var}"
    if [ -z "$pkg_name" ] || [ "$PKG_MANAGER" = "unknown" ] || [ "$PKG_MANAGER" = "emerge" ]; then
        log "⚠️ لا يمكن تثبيت $pkg_var (اسم الحزمة غير معروف أو مدير غير مدعوم)"
        return 1
    fi
    # تحقق مما إذا كانت الحزمة مثبتة بالفعل (محاولة بسيطة)
    if command -v "$pkg_name" >/dev/null 2>&1; then
        log "✅ $pkg_name موجود بالفعل"
        return 0
    fi
    log "📦 جاري تثبيت $pkg_name ..."
    $PKG_INSTALL "$pkg_name" 2>/dev/null || {
        log "❌ فشل تثبيت $pkg_name عبر $PKG_MANAGER"
        return 1
    }
    log "✅ تم تثبيت $pkg_name"
    return 0
}

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

# ---------- دالة تثبيت اعتماديات Python (محسنة) ----------
install_python_deps() {
    echo ""
    echo "📦 تثبيت اعتماديات Python لـ System Tray..."
    
    detect_distro

    # تأكد من وجود python3 و pip3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ Python3 غير مثبت، جاري محاولة التثبيت..."
        if [ "$PKG_MANAGER" != "unknown" ] && [ "${PKG_MANAGER_AUTO:-1}" = "1" ]; then
            $PKG_UPDATE 2>/dev/null || true
            install_system_package PYTHON3_PKG || {
                echo "⚠️ فشل تثبيت Python3، لا يمكن المتابعة."
                return 1
            }
        else
            echo "⚠️ لا يمكن تثبيت Python3 تلقائياً، يرجى تثبيته يدوياً."
            return 1
        fi
    fi

    # محاولة التثبيت عبر مدير الحزم أولاً
    if [ "$PKG_MANAGER" != "unknown" ] && [ "${PKG_MANAGER_AUTO:-1}" = "1" ]; then
        echo "🔍 استخدام مدير الحزم: $PKG_MANAGER"
        # تحديث قائمة الحزم
        $PKG_UPDATE 2>/dev/null || true

        # تثبيت jq إن لم يكن موجوداً (ضروري للبرنامج)
        if ! command -v jq >/dev/null 2>&1; then
            install_system_package JQ_PKG
        fi

        # تثبيت pystray و pillow عبر مدير الحزم
        install_system_package PYTHON_PKG_PYSTRAY
        install_system_package PYTHON_PKG_PILLOW

        # التحقق من نجاح التثبيت
        if python3 -c "import pystray, PIL" 2>/dev/null; then
            echo "✅ تم تثبيت المكتبات بنجاح عبر مدير الحزم"
            return 0
        else
            echo "⚠️ فشل التثبيت عبر مدير الحزم، التجربة عبر pip..."
        fi
    fi

    # محاولة عبر pip
    echo "🔍 المحاولة اليدوية عبر pip..."
    
    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "✅ مكتبات Python مثبتة بالفعل"
        return 0
    fi

    # تأكد من وجود pip3
    if ! command -v pip3 >/dev/null 2>&1; then
        echo "⚠️ pip3 غير موجود، جاري تثبيته..."
        if [ "$PKG_MANAGER" != "unknown" ]; then
            # حاول تثبيت pip3 عبر مدير الحزم
            case "$PKG_MANAGER" in
                apt) sudo apt install -y python3-pip ;;
                dnf|yum) sudo dnf install -y python3-pip ;;
                pacman) sudo pacman -S --noconfirm python-pip ;;
                zypper) sudo zypper install -y python3-pip ;;
                apk) sudo apk add py3-pip ;;
                xbps) sudo xbps-install -y python3-pip ;;
                pkg) sudo pkg install -y py39-pip ;;
                *) echo "⚠️ لا يمكن تثبيت pip تلقائياً";;
            esac 2>/dev/null || true
        fi
        if ! command -v pip3 >/dev/null 2>&1; then
            echo "❌ pip3 غير متوفر، يرجى تثبيته يدوياً."
            return 1
        fi
    fi

    echo "📦 تثبيت المكتبات عبر pip..."
    pip3 install --user pystray pillow requests 2>/dev/null || {
        echo "⚠️ فشل التثبيت عبر pip"
        echo "💡 يمكنك تثبيتها يدوياً لاحقاً:"
        echo "   pip3 install --user pystray pillow requests"
        return 1
    }

    if python3 -c "import pystray, PIL" 2>/dev/null; then
        echo "✅ تم تثبيت المكتبات عبر pip بنجاح"
        return 0
    else
        echo "❌ فشل التثبيت حتى بعد محاولة pip."
        return 1
    fi
}

# ---------- باقي الدوال (download_icons, setup_system_tray, setup_autostart, setup_terminal, run_initial_setup, start_services, copy_log, setup_terminal_display) تبقى كما هي ----------
# لقد أدرجتها بالكامل في الرد السابق، لذا سأختصر هنا وأكتب فقط التغييرات الهامة.

# لكن سأدرج الدوال التي تعتمد على Python أو تحتاج للتأكد من توفر المكتبات.

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
            # استخدام ImageMagick إذا وجد، وإلا استخدم Python
            if command -v convert >/dev/null 2>&1; then
                convert -size "${size}x${size}" xc:none \
                    -fill "#2E7D32" -draw "rectangle $((size/4)),$((size*2/3)) $((size*3/4)),$((size*5/6))" \
                    -fill "#388E3C" -draw "rectangle $((size*5/16)),$((size*7/16)) $((size*11/16)),$((size*2/3))" \
                    -fill "#2196F3" -draw "ellipse $((size/2)),$((size*5/16)) $((size*3/16)),$((size/8)) 0,360" \
                    -fill "#FFEB3B" -stroke "#FFEB3B" -draw "arc $((size*7/16)),$((size/4)) $((size*9/16)),$((size*3/8)) 30,150" \
                    "$icon_file" 2>/dev/null || true
            elif python3 -c "from PIL import Image, ImageDraw" 2>/dev/null; then
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
            else
                # إنشاء ملف فارغ كـ placeholder
                touch "$icon_file"
            fi
        fi
    done
    
    if [ $downloaded -gt 0 ]; then
        echo "✅ تم تحميل $downloaded أيقونة"
    else
        echo "⚠️ تم إنشاء أيقونات افتراضية"
    fi
}

# باقي الدوال كما هي (setup_system_tray, setup_autostart, setup_terminal, run_initial_setup, start_services, copy_log, setup_terminal_display) تم إدراجها كاملة في الرد السابق.
# سأعيد كتابتها هنا بإيجاز (يمكنك نسخها من الرد السابق).

setup_system_tray() {
    echo ""
    echo "🖥️  إعداد System Tray..."
    
    mkdir -p "$HOME/.local/share/applications"
    
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
    
    cat > "$INSTALL_DIR/start-tray.sh" <<'EOF'
#!/bin/bash
INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOCK_FILE="/tmp/gt-salat-tray.lock"
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(date +%s)
    file_age=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
    if [ $((lock_age - file_age)) -lt 10 ]; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT
export DISPLAY="${DISPLAY:-:0}"
if [ -S "/run/user/$(id -u)/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi
cd "$INSTALL_DIR"
python3 "$INSTALL_DIR/gt-tray.py"
EOF
    chmod +x "$INSTALL_DIR/start-tray.sh"
    
    cat > "$INSTALL_DIR/autostart-manager.sh" <<'EOF'
#!/bin/bash
INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOG_FILE="$INSTALL_DIR/autostart.log"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}
start_services() {
    log "بدء خدمات GT-salat-dikr..."
    for i in {1..30}; do
        if [ -n "$DISPLAY" ] && [ -S "/run/user/$(id -u)/bus" ]; then
            break
        fi
        sleep 1
    done
    export DISPLAY="${DISPLAY:-:0}"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    cd "$INSTALL_DIR"
    if [ -f "gt-salat-dikr.sh" ]; then
        ./gt-salat-dikr.sh --notify-start >/dev/null 2>&1 &
        log "تم بدء الإشعارات"
    fi
    sleep 10
    if [ -f "gt-tray.py" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$INSTALL_DIR/gt-tray.py" >/dev/null 2>&1 &
        log "تم بدء System Tray"
    fi
}
case "${1:-}" in
    start) start_services ;;
    stop) pkill -f "gt-salat-dikr\|gt-tray.py" 2>/dev/null || true; log "تم إيقاف الخدمات" ;;
    *) start_services ;;
esac
EOF
    chmod +x "$INSTALL_DIR/autostart-manager.sh"
    setup_autostart
}

setup_autostart() {
    echo ""
    echo "🔧 إعداد التشغيل التلقائي..."
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
    if [ -d "$HOME/.config/plasma-workspace/env" ]; then
        cat > "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" <<EOF
#!/bin/bash
sleep 25
"$INSTALL_DIR/autostart-manager.sh" &
EOF
        chmod +x "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh"
        echo "✅ تم إعداد التشغيل التلقائي لـ KDE Plasma"
    fi
    if command -v xfce4-session >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/xfce4/autostart"
        cp "$HOME/.config/autostart/gt-salat-dikr.desktop" "$HOME/.config/xfce4/autostart/"
        echo "✅ تم إعداد التشغيل التلقائي لـ XFCE"
    fi
    if [ -d "$HOME/.config/lxsession" ]; then
        mkdir -p "$HOME/.config/lxsession/LXDE"
        echo "@bash \"$INSTALL_DIR/autostart-manager.sh\"" >> "$HOME/.config/lxsession/LXDE/autostart" 2>/dev/null
        echo "✅ تم إعداد التشغيل التلقائي لـ LXDE/LXQt"
    fi
    echo "✅ تم إعداد التشغيل التلقائي"
}

setup_terminal() {
    echo ""
    echo "🔧 إعدادات الطرفية..."
    mkdir -p "$HOME/.local/bin"
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
        echo "✅ تم إنشاء رابط في: ~/.local/bin/gtsalat"
    fi
    # Bash
    if [ -f "$HOME/.bashrc" ]; then
        echo "🔧 إعداد Bash (.bashrc)..."
        GT_BLOCK="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'
if [ -f \"\$HOME/.local/bin/gtsalat\" ]; then
    gtsalat 2>/dev/null
fi
# نهاية كتلة GT-salat-dikر"
        if grep -q "# GT-salat-dikr" "$HOME/.bashrc"; then
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$HOME/.bashrc" 2>/dev/null
        fi
        echo "" >> "$HOME/.bashrc"
        echo "$GT_BLOCK" >> "$HOME/.bashrc"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى .bashrc"
    fi
    # Zsh
    if [ -f "$HOME/.zshrc" ]; then
        echo "🔧 إعداد Zsh (.zshrc)..."
        GT_BLOCK_ZSH="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'
if [ -f \"\$HOME/.local/bin/gtsalat\" ]; then
    gtsalat 2>/dev/null
fi
# نهاية كتلة GT-salat-dikر"
        if grep -q "# GT-salat-dikr" "$HOME/.zshrc"; then
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$HOME/.zshrc" 2>/dev/null
        fi
        echo "" >> "$HOME/.zshrc"
        echo "$GT_BLOCK_ZSH" >> "$HOME/.zshrc"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى .zshrc"
    fi
    # Fish
    if [ -d "$HOME/.config/fish" ]; then
        echo "🔧 إعداد Fish shell..."
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        mkdir -p "$HOME/.config/fish"
        GT_BLOCK_FISH="# GT-salat-dikr - تذكير الصلاة والأذكار
alias gtsalat='\$HOME/.local/bin/gtsalat'
if test -f \$HOME/.local/bin/gtsalat
    gtsalat 2>/dev/null
end
# نهاية كتلة GT-salat-dikر"
        if [ -f "$FISH_CONFIG" ] && grep -q "# GT-salat-dikr" "$FISH_CONFIG"; then
            sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/# نهاية كتلة GT-salat-dikر/d' "$FISH_CONFIG" 2>/dev/null
        fi
        echo "" >> "$FISH_CONFIG"
        echo "$GT_BLOCK_FISH" >> "$FISH_CONFIG"
        echo "✅ تم إضافة إعدادات GT-salat-dikr إلى Fish shell"
    fi
}

run_initial_setup() {
    echo ""
    echo "⚙️  الإعدادات الأولية..."
    if [ -f "$INSTALL_DIR/settings.conf" ]; then
        echo "📂 إعدادات موجودة مسبقاً، استخدامها..."
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
    echo "🔍 هذا يبدو أنه التثبيت الأول..."
    echo "🔄 تشغيل معالج الإعدادات..."
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        "$INSTALL_DIR/gt-salat-dikr.sh" --settings > /dev/null 2>&1 || {
            echo "⚠️  يمكنك تشغيل الإعدادات لاحقاً باستخدام: gtsalat --settings"
        }
    else
        echo "⚠️  ملف البرنامج الرئيسي غير موجود، لا يمكن تشغيل الإعدادات"
        echo "💡 قم بتشغيل الإعدادات يدوياً بعد التثبيت: gtsalat --settings"
    fi
}

start_services() {
    echo ""
    echo "🚀 بدء الخدمات..."
    if [ ! -f "$INSTALL_DIR/settings.conf" ]; then
        echo "⚠️  لم يتم إعداد البرنامج بعد"
        echo "💡 قم بتشغيل الإعدادات أولاً باستخدام: gtsalat --settings"
        return 1
    fi
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

copy_log_to_permanent_location() {
    if [ -f "$TEMP_LOG" ] && [ -d "$INSTALL_DIR" ]; then
        cp "$TEMP_LOG" "$INSTALL_DIR/install.log" 2>/dev/null || true
        rm -f "$TEMP_LOG" 2>/dev/null || true
    fi
}

setup_terminal_display() {
    echo ""
    echo "🔄 إعداد عرض الذكر في الطرفية..."
    cat > "$INSTALL_DIR/terminal-display.sh" <<'EOF'
#!/bin/bash
show_gt_salat_info() {
    if [ -f "$HOME/.local/bin/gtsalat" ]; then
        "$HOME/.local/bin/gtsalat" 2>/dev/null || true
    fi
}
if [[ $- == *i* ]] && [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
    show_gt_salat_info
fi
EOF
    chmod +x "$INSTALL_DIR/terminal-display.sh"
    add_to_shell_config() {
        local shell_file="$1"
        local shell_name="$2"
        if [ -f "$shell_file" ]; then
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
    add_to_shell_config "$HOME/.bashrc" ".bashrc"
    add_to_shell_config "$HOME/.zshrc" ".zshrc"
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
    ensure_installer
    echo "📝 بدء سجل التثبيت..."
    echo "════════════════════════════════════════════════════════" > "$TEMP_LOG"
    echo "بدء تثبيت GT-salat-dikr" >> "$TEMP_LOG"
    echo "التاريخ: $(date)" >> "$TEMP_LOG"
    echo "المستخدم: $(whoami)" >> "$TEMP_LOG"
    echo "════════════════════════════════════════════════════════" >> "$TEMP_LOG"
    
    echo "📁 مجلد التثبيت: $INSTALL_DIR"
    log "مجلد التثبيت: $INSTALL_DIR"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo "📂 مجلد موجود مسبقاً، تنظيف..."
        log "مجلد موجود مسبقاً، تنظيف المحتويات"
        if [ -f "$INSTALL_DIR/settings.conf" ]; then
            echo "💾 الاحتفاظ بالإعدادات الموجودة"
            cp "$INSTALL_DIR/settings.conf" "/tmp/gt-salat-settings-backup-$$.conf" 2>/dev/null || true
        fi
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.log" -delete 2>/dev/null || true
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.pid" -delete 2>/dev/null || true
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.tmp" -delete 2>/dev/null || true
    else
        mkdir -p "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    
    if [ -f "/tmp/gt-salat-settings-backup-$$.conf" ]; then
        cp "/tmp/gt-salat-settings-backup-$$.conf" "$INSTALL_DIR/settings.conf" 2>/dev/null || true
        rm -f "/tmp/gt-salat-settings-backup-$$.conf" 2>/dev/null || true
        echo "✅ تم استعادة الإعدادات السابقة"
    fi

    # تثبيت الاعتماديات قبل تنزيل الملفات (لضمان وجود jq و Python libraries)
    install_python_deps
    log "تم تثبيت اعتماديات Python"
    
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
    
    chmod +x "$INSTALL_DIR/gt-salat-dikr.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/gt-tray.py" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/uninstall.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/install-system-tray.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/install-python-deps.sh" 2>/dev/null || true
    
    download_icons
    log "تم تنزيل/إنشاء الأيقونات"
    
    setup_system_tray
    log "تم إعداد System Tray"
    
    setup_terminal
    log "تم إعداد الطرفية"
    
    setup_terminal_display
    log "تم إعداد عرض الذكر في الطرفية"
    
    run_initial_setup
    log "تم تنفيذ الإعدادات الأولية"
    
    start_services
    log "تم بدء الخدمات"
    
    copy_log_to_permanent_location
    
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
    rm -f "$TEMP_LOG" 2>/dev/null || true
}

main
exit 0
