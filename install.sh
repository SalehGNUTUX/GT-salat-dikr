#!/bin/bash
#
# GT-salat-dikr Simplified Installation Script - v3.2.2
# تجربة مستخدم سلسة ومثالية
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# منع التشغيل بصلاحيات root
if [ "$EUID" -eq 0 ]; then
    echo "❌ لا تشغل هذا السكربت بصلاحيات root، استخدم حساب المستخدم العادي."
    exit 1
fi

# المسارات
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

chmod +x "$MAIN_SCRIPT"

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
        # سنقوم بإنشائها لاحقاً إذا لزم
    fi
done

# إنشاء أيقونة افتراضية إذا لم يتم تحميل أي منها
if [ ! -f "$ICON_DIR/prayer-icon-32.png" ]; then
    echo "  🔨 إنشاء أيقونة افتراضية باستخدام Python..."

    # إنشاء سكربت Python لإنشاء الأيقونات
    cat > "$ICON_DIR/create_icons.py" <<'PYTHON_ICON_EOF'
#!/usr/bin/env python3
from PIL import Image, ImageDraw
import os

def create_icon(size):
    """إنشاء أيقونة مسجد بسيطة"""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # ألوان جميلة
    green_dark = (46, 125, 50)
    green_light = (56, 142, 60)
    blue = (33, 97, 140)
    yellow = (255, 235, 59)

    # حساب الأحجام النسبية
    base_y1 = int(size * 0.6)
    base_y2 = int(size * 0.8)
    wall_y1 = int(size * 0.44)
    wall_y2 = int(size * 0.6)
    dome_y1 = int(size * 0.12)
    dome_y2 = int(size * 0.3)

    # رسم مسجد بسيط
    # القاعدة
    draw.rectangle([size//4, base_y1, size*3//4, base_y2], fill=green_dark)
    # الجدار
    draw.rectangle([size*5//16, wall_y1, size*11//16, wall_y2], fill=green_light)
    # القبة
    draw.ellipse([size*3//8, dome_y1, size*5//8, dome_y2], fill=blue)
    # الهلال
    draw.arc([size*7//16, int(size*0.25), size*9//16, int(size*0.35)],
             30, 150, fill=yellow, width=max(2, size//16))

    return img

# إنشاء وحفظ الأيقونات
icon_dir = os.path.dirname(os.path.abspath(__file__))
for sz in [32, 64, 128]:
    icon = create_icon(sz)
    icon.save(os.path.join(icon_dir, f"prayer-icon-{sz}.png"))
    print(f"تم إنشاء أيقونة {sz}x{sz}")

PYTHON_ICON_EOF

    chmod +x "$ICON_DIR/create_icons.py"

    if command -v python3 >/dev/null 2>&1 && python3 -c "from PIL import Image" 2>/dev/null; then
        python3 "$ICON_DIR/create_icons.py" && rm "$ICON_DIR/create_icons.py"
    else
        echo "  ⚠️  Python3 أو Pillow غير مثبت، سيتم استخدام أيقونة نصية"
    fi
fi

echo "✅ تم تحضير الأيقونات"

# ---------- المرحلة 4: الكشف التلقائي عن الموقع ----------
echo ""
echo "📍 الكشف التلقائي عن الموقع..."

# قيم افتراضية (الرياض)
LAT="24.7136"
LON="46.6753"
CITY="الرياض"
COUNTRY="السعودية"
METHOD_ID=4  # أم القرى
METHOD_NAME="Umm Al-Qura University, Makkah"

# محاولة الكشف التلقائي
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    echo "🔍 جاري الكشف عن موقعك..."
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
            echo "✅ تم الكشف عن الموقع: $CITY, $COUNTRY"
        else
            echo "⚠️  تعذر الكشف الدقيق، استخدام القيم الافتراضية"
        fi
    else
        echo "⚠️  تعذر الاتصال بخدمة الموقع، استخدام القيم الافتراضية"
    fi
else
    echo "⚠️  الأدوات غير متوفرة للكشف، استخدام القيم الافتراضية"
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
    echo "  ⏳ جاري تحميل بيانات الصلاة (قد يستغرق بضع ثواني)..."

    # التحقق من اتصال الإنترنت
    if curl -s --connect-timeout 5 https://api.aladhan.com >/dev/null 2>&1; then
        # استخدام السكربت الرئيسي لتحميل البيانات
        if [ -f "$MAIN_SCRIPT" ]; then
            # تشغيل في الخلفية بدون إخراج
            "$MAIN_SCRIPT" --update-timetables >/tmp/gt-salat-update.log 2>&1 &
            UPDATE_PID=$!

            # انتظار لمدة 15 ثانية كحد أقصى
            sleep 2
            if ps -p $UPDATE_PID >/dev/null 2>&1; then
                echo "  ✅ جاري التحميل في الخلفية..."
                # نترك العملية تكمل في الخلفية
                disown $UPDATE_PID 2>/dev/null || true
            else
                echo "  ✅ تم تحميل بعض بيانات الصلاة"
            fi
        else
            echo "  ⚠️  السكربت الرئيسي غير موجود"
        fi
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
        # التحقق إذا كانت الإعدادات موجودة مسبقاً
        if ! grep -q "gtsalat" "$shell_file" 2>/dev/null; then
            {
                echo ""
                echo "# GT-salat-dikr - تذكير الصلاة والأذكار"
                echo "alias gtsalat='~/.local/bin/gtsalat 2>/dev/null || $INSTALL_DIR/$MAIN_SCRIPT'"
                echo "if [ -f \"$INSTALL_DIR/$MAIN_SCRIPT\" ]; then"
                echo "    echo ''"
                echo "    $INSTALL_DIR/$MAIN_SCRIPT"
                echo "fi"
            } >> "$shell_file"
            echo "  ✅ تم إضافة إعدادات إلى $shell_name"
        else
            echo "  ℹ️  الإعدادات موجودة مسبقاً في $shell_name"
        fi
    else
        echo "  ⚠️  ملف $shell_name غير موجود"
    fi
}

# إعدادات لأنواع الطرفيات المختلفة
echo "  إعداد Bash..."
setup_shell_config "$HOME/.bashrc" "Bash"
setup_shell_config "$HOME/.bash_profile" "Bash Profile"

if [ -f "$HOME/.zshrc" ]; then
    echo "  إعداد Zsh..."
    setup_shell_config "$HOME/.zshrc" "Zsh"
fi

echo "✅ تم إعداد الطرفية لعرض الذكر وموعد الصلاة عند الافتتاح"

# ---------- المرحلة 9: System Tray ----------
echo ""
echo "🖥️  إعداد أيقونة شريط المهام (System Tray)..."

# تحميل سكربت System Tray
echo "⬇️  تحميل سكربت System Tray..."
if curl -fsSL "$REPO_BASE/gt-tray.py" -o "$TRAY_SCRIPT" 2>/dev/null; then
    chmod +x "$TRAY_SCRIPT"
    echo "✅ تم تحميل سكربت System Tray"
else
    # إنشاء سكربت System Tray افتراضي
    echo "🔨 إنشاء سكربت System Tray افتراضي..."
    cat > "$TRAY_SCRIPT" <<'PYTHON_TRAY_EOF'
#!/usr/bin/env python3
"""
GT-salat-dikr System Tray Icon
"""

import os
import sys
import subprocess
import threading
import time

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    LIBRARIES_AVAILABLE = True
except ImportError:
    LIBRARIES_AVAILABLE = False
    print("❌ المكتبات المطلوبة غير مثبتة")
    print("💡 قم بتثبيتها: pip install pystray pillow")
    sys.exit(1)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = os.path.expanduser("~/.GT-salat-dikr")
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")

    def run_cmd(self, cmd, use_terminal=True):
        """تشغيل أمر"""
        try:
            if use_terminal:
                # محاولة استخدام terminal موجود
                subprocess.Popen(
                    ["x-terminal-emulator", "-e", f"bash -c '{cmd}; exec bash'"],
                    start_new_session=True
                )
            else:
                subprocess.Popen(cmd, shell=True, start_new_session=True)
        except:
            try:
                subprocess.Popen(cmd, shell=True, start_new_session=True)
            except Exception as e:
                print(f"❌ خطأ: {e}")

    def get_next_prayer(self):
        """الحصول على الصلاة القادمة"""
        try:
            result = subprocess.run(
                [self.main_script],
                capture_output=True,
                text=True,
                timeout=5
            )
            for line in result.stdout.split('\n'):
                if 'الصلاة القادمة:' in line:
                    return line.strip()
        except:
            pass
        return "الصلاة القادمة: جاري التحديث..."

    def load_icon(self):
        """تحميل الأيقونة"""
        icon_paths = [
            os.path.join(self.install_dir, "icons", "prayer-icon-32.png"),
            os.path.join(self.install_dir, "icons", "prayer-icon-64.png"),
        ]

        for path in icon_paths:
            if os.path.exists(path):
                try:
                    return Image.open(path)
                except:
                    continue

        # إنشاء أيقونة افتراضية
        img = Image.new('RGBA', (32, 32), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)
        draw.rectangle([8, 20, 24, 26], fill=(46, 125, 50))
        draw.rectangle([10, 14, 22, 20], fill=(56, 142, 60))
        draw.ellipse([10, 6, 22, 14], fill=(33, 97, 140))
        draw.arc([14, 8, 18, 12], 30, 150, fill=(255, 235, 59), width=2)
        return img

    def create_menu(self):
        """إنشاء القائمة"""
        next_prayer = self.get_next_prayer()

        menu = [
            MenuItem("🕌 GT-salat-dikr", None, enabled=False),
            MenuItem("══════════════════", None, enabled=False),
            MenuItem(f"⏰ {next_prayer}", None, enabled=False),
            MenuItem("", None, enabled=False),
            MenuItem("📊 مواقيت اليوم",
                lambda: self.run_cmd(f"{self.main_script} --show-timetable")),
            MenuItem("🕊️  إظهار ذكر",
                lambda: self.run_cmd(f"{self.main_script}")),
            MenuItem("📈 حالة البرنامج",
                lambda: self.run_cmd(f"{self.main_script} --status")),
            MenuItem("", None, enabled=False),
            MenuItem("⚙️  الإعدادات",
                lambda: self.run_cmd(f"{self.main_script} --settings")),
            MenuItem("🔄 تحديث المواقيت",
                lambda: self.run_cmd(f"{self.main_script} --update-timetables")),
            MenuItem("", None, enabled=False),
            MenuItem("🔔 التحكم بالإشعارات:", None, enabled=False),
            MenuItem("  ▶️  تشغيل",
                lambda: self.run_cmd(f"{self.main_script} --notify-start", False)),
            MenuItem("  ⏸️  إيقاف",
                lambda: self.run_cmd(f"{self.main_script} --notify-stop", False)),
            MenuItem("", None, enabled=False),
            MenuItem("🖥️  إدارة الأيقونة:", None, enabled=False),
            MenuItem("  🔄 إعادة تشغيل", lambda: self.restart()),
            MenuItem("  ❌ إغلاق", lambda: self.icon.stop()),
            MenuItem("", None, enabled=False),
            MenuItem("❓ المساعدة",
                lambda: self.run_cmd(f"{self.main_script} --help"))
        ]

        return Menu(*menu)

    def restart(self):
        """إعادة التشغيل"""
        print("🔄 إعادة تشغيل...")
        self.icon.stop()
        time.sleep(1)
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def update_tooltip(self):
        """تحديث التلميح"""
        while True:
            if self.icon and self.icon.visible:
                try:
                    prayer = self.get_next_prayer()
                    self.icon.title = f"GT-salat-dikr\n{prayer}"
                except:
                    pass
            time.sleep(60)

    def run(self):
        """تشغيل الأيقونة"""
        print("🚀 بدء أيقونة System Tray...")
        print("📌 الأيقونة في شريط المهام")
        print("🖱️  انقر بزر الماوس الأيمن للقائمة")

        icon_image = self.load_icon()
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr",
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

if __name__ == "__main__":
    if not LIBRARIES_AVAILABLE:
        sys.exit(1)

    tray = PrayerTray()
    tray.run()
PYTHON_TRAY_EOF

    chmod +x "$TRAY_SCRIPT"
    echo "✅ تم إنشاء سكربت System Tray افتراضي"
fi

# ---------- المرحلة 10: تثبيت تبعيات Python ----------
echo ""
echo "📦 التحقق من مكتبات Python..."

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

# ---------- المرحلة 11: بدء System Tray ----------
echo ""
echo "🚀 بدء تشغيل الخدمات..."

# بدء System Tray إذا كانت المكتبات متوفرة
if [ "$PYTHON_DEPS_OK" -eq 1 ] && [ -f "$TRAY_SCRIPT" ]; then
    echo "🖥️  بدء تشغيل System Tray..."
    python3 "$TRAY_SCRIPT" >/dev/null 2>&1 &
    sleep 2
    if ps -p $! >/dev/null 2>&1; then
        echo "✅ تم تشغيل System Tray"
        echo "📌 انقر بزر الماوس الأيمن على الأيقونة للتحكم"
    else
        echo "⚠️  تعذر تشغيل System Tray"
    fi
else
    echo "ℹ️  يمكنك تشغيل System Tray لاحقاً:"
    echo "   gtsalat --tray  أو  python3 ~/.GT-salat-dikr/gt-tray.py"
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
echo "1. من الطرفية:"
echo "   gtsalat --tray"
echo "   أو"
echo "   python3 ~/.GT-salat-dikr/gt-tray.py"
echo ""
echo "2. للتشغيل التلقائي، أضف لـ ~/.bashrc:"
echo "   [ -f ~/.GT-salat-dikr/gt-tray.py ] && python3 ~/.GT-salat-dikr/gt-tray.py &"
echo "════════════════════════════════════════════════════════"

echo ""
echo "✅ تم اكتمال التثبيت! جرب الأمر: gtsalat"
echo ""

# تشغيل الأمر الأولي لعرض البيانات
sleep 2
"$INSTALL_DIR/$MAIN_SCRIPT" 2>/dev/null || true
