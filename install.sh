#!/bin/bash
#
# GT-salat-dikr Complete Installation v3.2.3
# تثبيت كامل مع إصلاحات شاملة
#

set -e

# دالة لعرض الرأس الفني
show_header() {
    cat << "EOF"

      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.3 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     مرحباً بك في تثبيت GT-salat-dikr!"
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
DESKTOP_FILE="$INSTALL_DIR/gt-salat-dikr.desktop"
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

# ---------- المرحلة 3: إنشاء Launcher ذكي ----------
echo ""
echo "🔧 إنشاء مُشغّل ذكي للتطبيق..."

cat > "$INSTALL_DIR/launcher.sh" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Launcher - مُشغّل ذكي يمنع التكرار
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOCK_FILE="/tmp/gt-salat-launcher.lock"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

# دالة للتحقق من تشغيل System Tray
check_tray_running() {
    # التحقق عبر PID
    if [ -f "/tmp/gt-salat-tray.pid" ]; then
        local pid=$(cat "/tmp/gt-salat-tray.pid" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            echo "✅ System Tray يعمل بالفعل (PID: $pid)"
            return 0
        fi
    fi
    
    # التحقق عبر pgrep
    if pgrep -f "gt-tray.py" >/dev/null 2>&1; then
        local pid=$(pgrep -f "gt-tray.py" | head -1)
        echo "✅ System Tray يعمل بالفعل (PID: $pid)"
        return 0
    fi
    
    return 1
}

# دالة بدء System Tray
start_tray() {
    echo "🚀 بدء تشغيل System Tray..."
    
    # التحقق من مكتبات Python
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ Python3 غير مثبت"
        return 1
    fi
    
    # التحقق من وجود الملف
    if [ ! -f "$TRAY_SCRIPT" ]; then
        echo "❌ ملف System Tray غير موجود: $TRAY_SCRIPT"
        return 1
    fi
    
    # تأكد من متغيرات البيئة
    export DISPLAY="${DISPLAY:-:0}"
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
    
    # تشغيل System Tray
    cd "$INSTALL_DIR"
    python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    local tray_pid=$!
    
    # حفظ PID للاستخدام المستقبلي
    echo $tray_pid > "/tmp/gt-salat-tray.pid"
    sleep 3
    
    if ps -p $tray_pid >/dev/null 2>&1; then
        echo "🎉 تم تشغيل System Tray بنجاح!"
        echo "📌 PID: $tray_pid"
        echo "📍 الأيقونة في شريط المهام"
        return 0
    else
        echo "❌ فشل تشغيل System Tray"
        rm -f "/tmp/gt-salat-tray.pid" 2>/dev/null || true
        return 1
    fi
}

# دالة عرض رسالة معلومات
show_info() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "🕌 GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "🔧 الإجراءات المتاحة:"
    echo "════════════════════════════════════════════════════════"
    echo "1. تشغيل System Tray (إذا لم يكن يعمل)"
    echo "2. التحقق من حالة البرنامج"
    echo "3. عرض مواقيت الصلاة"
    echo "4. إدارة الإشعارات"
    echo "════════════════════════════════════════════════════════"
    echo ""
}

# الدالة الرئيسية
main() {
    # التحقق من القفل لمنع التشغيل المتكرر السريع
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
        if [ $lock_age -lt 5 ]; then
            echo "⏳ يتم المعالجة، انتظر قليلاً..."
            exit 0
        fi
    fi
    
    touch "$LOCK_FILE"
    
    # عرض معلومات
    show_info
    
    # التحقق من حالة System Tray
    if check_tray_running; then
        echo ""
        echo "💡 نصائح:"
        echo "════════════════════════════════════════════════════════"
        echo "• System Tray يعمل بالفعل في شريط المهام"
        echo "• انقر بزر الماوس الأيمن على الأيقونة للتحكم"
        echo "• يمكنك استخدام الأمر 'gtsalat' في الطرفية"
        echo "════════════════════════════════════════════════════════"
        
        # عرض معلومات الصلاة
        echo ""
        echo "📊 معلومات الصلاة الحالية:"
        echo "════════════════════════════════════════════════════════"
        "$MAIN_SCRIPT" 2>/dev/null || echo "جاري تحميل البيانات..."
        echo "════════════════════════════════════════════════════════"
    else
        echo "🔍 System Tray غير نشط، جاري التشغيل..."
        echo ""
        
        if start_tray; then
            echo ""
            echo "✅ تم بنجاح! يمكنك الآن:"
            echo "════════════════════════════════════════════════════════"
            echo "1. البحث عن الأيقونة في شريط المهام"
            echo "2. النقر بزر الماوس الأيمن للتحكم"
            echo "3. استخدام 'gtsalat --help' للمزيد"
            echo "════════════════════════════════════════════════════════"
        else
            echo ""
            echo "❌ تعذر تشغيل System Tray"
            echo "════════════════════════════════════════════════════════"
            echo "💡 الحلول المقترحة:"
            echo "1. تأكد من تثبيت Python3"
            echo "2. ثبت المكتبات: pip install pystray pillow"
            echo "3. استخدم 'gtsalat --tray' من الطرفية"
            echo "════════════════════════════════════════════════════════"
        fi
    fi
    
    # تنظيف القفل
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

# التنفيذ
main
exit 0
EOF

chmod +x "$INSTALL_DIR/launcher.sh"

# ---------- المرحلة 4: إنشاء ملف .desktop مزدوج التصنيف ----------
echo ""
echo "🖥️  إنشاء ملف تطبيق في قائمة البرامج..."

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GT-salat-dikr
GenericName=Prayer Times & Azkar Notifications
Comment=نظام إشعارات الصلاة والأذكار مع System Tray
Exec=$INSTALL_DIR/launcher.sh
Icon=$INSTALL_DIR/icons/prayer-icon-64.png
Terminal=false
StartupNotify=false
Categories=Utility;Education;
Keywords=prayer;islam;azkar;notification;reminder;صلاة;أذكار;إسلام;تذكير;
MimeType=
X-GNOME-FullName=GT-salat-dikr Prayer Reminder
X-GNOME-DocPath=
X-GNOME-Bugzilla-Bugzilla=GT-salat-dikr
X-GNOME-Bugzilla-Product=gt-salat-dikr
X-GNOME-Bugzilla-Component=general
X-GNOME-Bugzilla-Version=3.2.3
X-GNOME-Bugzilla-ExtraInfoScript=$INSTALL_DIR/gt-salat-dikr.sh --version
StartupWMClass=gt-salat-dikr
EOF

# نسخ ملف .desktop لجميع المواقع الممكنة
echo "📁 نسخ ملف التطبيق إلى قوائم النظام..."

DESKTOP_LOCATIONS=(
    "$HOME/.local/share/applications/gt-salat-dikr.desktop"
    "$HOME/.local/share/applications/GT-salat-dikr.desktop"
    "$HOME/Desktop/gt-salat-dikr.desktop"
)

for location in "${DESKTOP_LOCATIONS[@]}"; do
    mkdir -p "$(dirname "$location")"
    cp "$DESKTOP_FILE" "$location" 2>/dev/null && echo "  ✅ تم النسخ إلى: $(dirname "$location")"
done

# إنشاء رابط مباشر للأوامر
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true
ln -sf "$INSTALL_DIR/launcher.sh" "$HOME/.local/bin/gt-salat-launcher" 2>/dev/null || true

# ---------- المرحلة 5: إصلاح التشغيل التلقائي ----------
echo ""
echo "🔧 إصلاح التشغيل التلقائي عند الإقلاع..."

cat > "$INSTALL_DIR/autostart-fixed.sh" <<'EOF'
#!/bin/bash
#
# GT-salat-dikr Auto-start Fixed
#

set -e

INSTALL_DIR="$(dirname "$(realpath "$0")")"
LOG_FILE="$INSTALL_DIR/autostart.log"
MAX_WAIT=120

# دالة التسجيل
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# دالة الانتظار لتحميل الواجهة
wait_for_desktop() {
    log "⏳ انتظار تحميل واجهة المستخدم..."
    
    local wait_time=0
    
    # الطريقة 1: انتظار ظهور ملف .Xauthority
    while [ ! -f "$HOME/.Xauthority" ] && [ $wait_time -lt 30 ]; do
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    # الطريقة 2: انتظار ظهور DISPLAY
    wait_time=0
    while [ -z "$DISPLAY" ] && [ $wait_time -lt $MAX_WAIT ]; do
        sleep 3
        # محاولات مختلفة لاكتشاف DISPLAY
        if [ -S "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=":0"
        elif [ -S "/tmp/.X11-unix/X1" ]; then
            export DISPLAY=":1"
        else
            # محاولة اكتشاف من عمليات Xorg
            local xdisplay=$(ps aux | grep -o ":[0-9]" | grep ":" | head -1)
            if [ -n "$xdisplay" ]; then
                export DISPLAY="$xdisplay"
            fi
        fi
        wait_time=$((wait_time + 3))
        log "الانتظار: ${wait_time}ثانية - DISPLAY=$DISPLAY"
    done
    
    # تأكد من DBUS
    local dbus_found=false
    for bus_path in "/run/user/$(id -u)/bus" "/var/run/user/$(id -u)/bus" "/tmp/dbus-$(id -u)"*; do
        if [ -S "$bus_path" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_path"
            dbus_found=true
            break
        fi
    done
    
    if [ "$dbus_found" = false ]; then
        # محاولة استخراج من عملية dbus
        local dbus_pid=$(pgrep -u "$(id -u)" dbus-daemon | head -1)
        if [ -n "$dbus_pid" ]; then
            local dbus_env=$(tr '\0' '\n' < "/proc/$dbus_pid/environ" | grep DBUS_SESSION_BUS_ADDRESS || true)
            if [ -n "$dbus_env" ]; then
                export "$dbus_env"
            fi
        fi
    fi
    
    # انتظار نهائي للتأكد
    sleep 15
    log "✅ بيئة المستخدم جاهزة"
}

# دالة بدء الخدمات
start_services() {
    log "🚀 بدء خدمات GT-salat-dikر..."
    
    # 1. بدء الإشعارات
    log "بدء إشعارات الصلاة..."
    cd "$INSTALL_DIR"
    
    # التحقق من الإعدادات أولاً
    if [ ! -f "settings.conf" ]; then
        log "⚠️  لا توجد إعدادات، جاري الإعداد التلقائي..."
        ./gt-salat-dikr.sh --settings 2>&1 | head -20 >> "$LOG_FILE"
        sleep 5
    fi
    
    # بدء الإشعارات
    if ./gt-salat-dikr.sh --notify-start >> "$LOG_FILE" 2>&1; then
        log "✅ تم بدء الإشعارات"
    else
        log "⚠️  محاولة بديلة لبدء الإشعارات..."
        nohup bash -c 'cd "$INSTALL_DIR" && ./gt-salat-dikr.sh --child-notify >> "$LOG_FILE" 2>&1' &
    fi
    
    # 2. بدء System Tray (بعد تأخير)
    sleep 20
    log "محاولة بدء System Tray..."
    
    if command -v python3 >/dev/null 2>&1 && [ -f "gt-tray.py" ]; then
        # التحقق من عدم التشغيل المسبق
        if ! pgrep -f "gt-tray.py" >/dev/null 2>&1; then
            # تشغيل مع متغيرات البيئة
            DISPLAY="${DISPLAY:-:0}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" \
            python3 ./gt-tray.py >> "$LOG_FILE" 2>&1 &
            local tray_pid=$!
            sleep 10
            
            if ps -p $tray_pid >/dev/null 2>&1; then
                log "✅ System Tray يعمل (PID: $tray_pid)"
                echo $tray_pid > "/tmp/gt-salat-tray.pid"
            else
                log "⚠️  فشل بدء System Tray"
            fi
        else
            log "✅ System Tray يعمل بالفعل"
        fi
    else
        log "❌ System Tray غير متوفر"
    fi
}

# الدالة الرئيسية
main() {
    log "════════════════════════════════════════════════════════"
    log "بدء GT-salat-dikر التلقائي - $(date)"
    log "المستخدم: $(whoami), UID: $(id -u)"
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

# إعداد autostart
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr (Auto-start)
Comment=Start prayer notifications on login
Exec=bash -c 'sleep 25 && "$INSTALL_DIR/autostart-fixed.sh"'
Icon=$INSTALL_DIR/icons/prayer-icon-32.png
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
StartupNotify=false
EOF

# ---------- المرحلة 6: تحديث ملف System Tray ----------
echo ""
echo "🔄 تحديث ملف System Tray..."

# تحديث ملف gt-tray.py للتعامل مع PID بشكل أفضل
cat > "$INSTALL_DIR/gt-tray.py" <<'EOF'
#!/usr/bin/env python3
"""
GT-salat-dikr System Tray - الإصدار المحسن مع إدارة PID
"""

import os
import sys
import subprocess
import threading
import time
import tempfile
import re
import fcntl
import signal
from pathlib import Path

INSTALL_DIR = os.path.expanduser("~/.GT-salat-dikr")
sys.path.insert(0, INSTALL_DIR)

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"❌ المكتبات غير مثبتة: {e}")
    print("💡 قم بتثبيت: pip install --user pystray pillow")
    sys.exit(1)

# ملف PID
PID_FILE = "/tmp/gt-salat-tray.pid"

def save_pid():
    """حفظ PID للتطبيقات الأخرى"""
    try:
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
    except:
        pass

def remove_pid():
    """حذف ملف PID"""
    try:
        os.remove(PID_FILE)
    except:
        pass

def check_existing():
    """التحقق من وجود نسخة أخرى"""
    try:
        if os.path.exists(PID_FILE):
            with open(PID_FILE, 'r') as f:
                old_pid = int(f.read().strip())
                # التحقق إذا كانت العملية لا تزال تعمل
                try:
                    os.kill(old_pid, 0)
                    print(f"✅ System Tray يعمل بالفعل (PID: {old_pid})")
                    print("💡 إذا لم تظهر الأيقونة، حاول إعادة تشغيلها")
                    return True
                except:
                    # العملية ميتة، يمكننا المتابعة
                    pass
    except:
        pass
    return False

def remove_ansi_codes(text):
    """إزالة أكواد ANSI"""
    if not text:
        return text
    ansi_escape = re.compile(r'\x1B[@-_][0-?]*[ -/]*[@-~]')
    return ansi_escape.sub('', text)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = INSTALL_DIR
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")
        self.icon_dir = os.path.join(self.install_dir, "icons")
        
        # التحقق من وجود نسخة أخرى
        if check_existing():
            sys.exit(0)
        
        # حفظ PID الحالي
        save_pid()
        
    def __del__(self):
        """تنظيف عند الخروج"""
        remove_pid()

    def run_cmd_in_terminal(self, cmd, title="GT-salat-dikr"):
        """تشغيل أمر في terminal"""
        try:
            script_content = f'''#!/bin/bash
echo "{title}"
echo "══════════════════════════════════════════════════"
cd "{self.install_dir}"
{cmd}
echo ""
echo "══════════════════════════════════════════════════"
read -p "اضغط Enter للإغلاق... "
'''
            script_file = tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False)
            script_file.write(script_content)
            script_file.close()
            os.chmod(script_file.name, 0o755)

            terminals = [
                ('gnome-terminal', ['--', 'bash', script_file.name]),
                ('konsole', ['-e', 'bash', script_file.name]),
                ('xfce4-terminal', ['-e', 'bash', script_file.name]),
                ('mate-terminal', ['-e', 'bash', script_file.name]),
                ('xterm', ['-e', 'bash', script_file.name]),
            ]

            for terminal, args in terminals:
                if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                    subprocess.Popen([terminal] + args, start_new_session=True)
                    return True

            subprocess.Popen(['bash', script_file.name], start_new_session=True)
            return True

        except Exception as e:
            print(f"❌ خطأ في فتح terminal: {e}")
            return False

    def get_prayer_info(self):
        """الحصول على معلومات الصلاة"""
        try:
            result = subprocess.run(
                [self.main_script, '--status'],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            
            if result.returncode == 0:
                output = remove_ansi_codes(result.stdout)
                lines = output.split('\n')
                
                for line in lines:
                    line = line.strip()
                    if 'الصلاة القادمة:' in line:
                        clean_line = line.replace('الصلاة القادمة:', '').strip()
                        # استخراج الوقت إذا كان موجوداً
                        time_match = re.search(r'(\d{1,2}:\d{2})', clean_line)
                        if time_match:
                            time_str = time_match.group(1)
                            prayer_name = clean_line.replace(time_str, '').strip()
                            return f"🕌 {prayer_name} ⏰ {time_str}"
                        return f"🕌 {clean_line}"
                
        except Exception as e:
            print(f"⚠️  خطأ: {e}")
        
        return "🕌 الصلاة القادمة: جاري التحديث..."

    def load_icon(self):
        """تحميل الأيقونة"""
        icon_paths = [
            os.path.join(self.icon_dir, "prayer-icon-32.png"),
            os.path.join(self.icon_dir, "prayer-icon-64.png"),
            os.path.join(self.icon_dir, "prayer-icon-48.png"),
            os.path.join(self.icon_dir, "icon.png"),
        ]

        for path in icon_paths:
            if os.path.exists(path):
                try:
                    return Image.open(path)
                except:
                    continue

        # أيقونة افتراضية
        img = Image.new('RGBA', (32, 32), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)
        draw.rectangle([8, 20, 24, 26], fill=(46, 125, 50))
        draw.rectangle([10, 14, 22, 20], fill=(56, 142, 60))
        draw.ellipse([10, 6, 22, 14], fill=(33, 97, 140))
        draw.arc([14, 8, 18, 12], 30, 150, fill=(255, 235, 59), width=2)
        return img

    def create_menu(self):
        """إنشاء قائمة System Tray"""
        prayer_info = self.get_prayer_info()

        menu_items = []
        menu_items.append(MenuItem("🕌 GT-salat-dikr", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        menu_items.append(MenuItem(f"{prayer_info}", None, enabled=False))
        menu_items.append(MenuItem("", None, enabled=False))
        
        menu_items.append(MenuItem("📊 مواقيت اليوم",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --show-timetable", "مواقيت الصلاة")))
        
        menu_items.append(MenuItem("🕊️  إظهار ذكر",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh", "ذكر اليوم")))
        
        menu_items.append(MenuItem("📈 حالة البرنامج",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --status", "حالة البرنامج")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        
        menu_items.append(MenuItem("⚙️  الإعدادات",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --settings", "الإعدادات")))
        
        menu_items.append(MenuItem("🔄 تحديث المواقيت",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --update-timetables", "تحديث المواقيت")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        
        menu_items.append(MenuItem("🔔 الإشعارات:", None, enabled=False))
        menu_items.append(MenuItem("  ▶️  تشغيل",
            lambda: subprocess.run([self.main_script, '--notify-start'], cwd=self.install_dir)))
        
        menu_items.append(MenuItem("  ⏸️  إيقاف",
            lambda: subprocess.run([self.main_script, '--notify-stop'], cwd=self.install_dir)))

        menu_items.append(MenuItem("", None, enabled=False))
        
        menu_items.append(MenuItem("🖥️  الأيقونة:", None, enabled=False))
        menu_items.append(MenuItem("  🔄 إعادة تشغيل", self.restart_tray))
        menu_items.append(MenuItem("  ❌ إغلاق", self.stop_tray))

        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        
        menu_items.append(MenuItem("❓ المساعدة",
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --help", "مساعدة")))

        return Menu(*menu_items)

    def restart_tray(self):
        """إعادة تشغيل System Tray"""
        print("🔄 إعادة تشغيل الأيقونة...")
        if self.icon:
            self.icon.stop()
        time.sleep(2)
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def stop_tray(self):
        """إيقاف System Tray"""
        print("⏹️  إيقاف الأيقونة...")
        if self.icon:
            self.icon.stop()

    def update_tooltip(self):
        """تحديث التلميح"""
        while True:
            if self.icon and hasattr(self.icon, 'visible') and self.icon.visible:
                try:
                    info = self.get_prayer_info()
                    self.icon.title = f"GT-salat-dikr\n{info}"
                except:
                    pass
            time.sleep(60)

    def run(self):
        """تشغيل System Tray"""
        print("🚀 بدء System Tray...")
        print("📌 الأيقونة في شريط المهام")
        print("🖱️  انقر بزر الماوس الأيمن للتحكم")

        icon_image = self.load_icon()
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr - تذكير الصلاة والأذكار",
            self.create_menu()
        )

        updater = threading.Thread(target=self.update_tooltip, daemon=True)
        updater.start()

        try:
            self.icon.run()
        except KeyboardInterrupt:
            print("\n✅ تم الإغلاق")
        except Exception as e:
            print(f"❌ خطأ: {e}")
        finally:
            remove_pid()

def main():
    if not LIBRARIES_AVAILABLE:
        print("❌ لا يمكن تشغيل System Tray")
        return 1

    if not os.path.exists(os.path.expanduser("~/.GT-salat-dikr/gt-salat-dikr.sh")):
        print("❌ البرنامج غير مثبت")
        return 1

    tray = PrayerTray()
    tray.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x "$INSTALL_DIR/gt-tray.py"

# ---------- المرحلة 7: الإعدادات النهائية ----------
echo ""
echo "⚙️  الإعدادات النهائية..."

# تحديث ملف الإعدادات إذا لزم
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚙️  جاري الإعداد التلقائي للموقع..."
    "$INSTALL_DIR/$MAIN_SCRIPT" --settings 2>&1 | tail -10
fi

# بدء الخدمات الآن
echo ""
echo "🚀 بدء الخدمات الآن..."

# بدء autostart في الخلفية
bash -c "sleep 8 && '$INSTALL_DIR/autostart-fixed.sh' >/dev/null 2>&1 &" &

# ---------- المرحلة 8: الرسالة النهائية الترحيبية ----------
echo ""
echo "══════════════════════════════════════════════════════════════════════════════"
show_header
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 مبروك! تم تثبيت GT-salat-dikr بنجاح 🎉"
echo ""
echo "✨ الميزات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✅ 1. تشغيل تلقائي عند إقلاع النظام"
echo "✅ 2. أيقونة في قائمة البرامج (قسمي: الأدوات والتعليم)"
echo "✅ 3. System Tray يمنع التكرار"
echo "✅ 4. ملف إلغاء تثبيت جاهز للاستخدام"
echo "✅ 5. Launcher ذكي لإدارة التطبيق"
echo "✅ 6. إشعارات الصلاة والأذكار التلقائية"
echo "✅ 7. تخزين محلي لمواقيت الصلاة"
echo "✅ 8. تحديث أسبوعي تلقائي"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 كيفية البدء:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "1. 🔍 ابحث عن 'GT-salat-dikr' في قائمة البرامج"
echo "2. 🖱️  انقر عليه لفتح System Tray"
echo "3. 📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
echo "4. ⚙️  عدل الإعدادات إذا لزم: gtsalat --settings"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔧 الأوامر المتاحة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "gtsalat                    # عرض ذكر وموعد الصلاة"
echo "gtsalat --status          # حالة البرنامج"
echo "gtsalat --show-timetable  # مواقيت اليوم"
echo "gtsalat --settings        # تعديل الإعدادات"
echo "gtsalat --tray            # تشغيل System Tray يدوياً"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📁 الملفات المثبتة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "📍 المثبت:      $INSTALL_DIR/"
echo "📍 الإعدادات:   $CONFIG_FILE"
echo "📍 System Tray: $TRAY_SCRIPT"
echo "📍 Launcher:    $INSTALL_DIR/launcher.sh"
echo "📍 إلغاء تثبيت: $UNINSTALLER"
echo "📍 السجلات:     $INSTALL_DIR/autostart.log"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🔄 لإلغاء التثبيت:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "bash $UNINSTALLER"
echo "أو"
echo "~/GT-salat-dikr/uninstall.sh"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "📞 الدعم والمساعدة:"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "• اكتب 'gtsalat --help' لرؤية جميع الأوامر"
echo "• اقرأ ملف README للمزيد من المعلومات"
echo "• للأسئلة: راجع صفحة المشروع على GitHub"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "🕌 جعل الله هذا العمل في ميزان حسناتنا جميعاً"
echo "📅 $(date)"
echo ""
