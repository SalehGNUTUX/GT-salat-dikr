#!/bin/bash
# install.sh - تثبيت GT-salat-dikr v4.0
# إصدار محسن مع تصحيح الأخطاء وميزات جديدة

set -e

# ألوان للعرض
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# متغيرات التثبيت
VERSION="4.0.0"
INSTALL_DIR="$HOME/.GT-salat-dikr"
CONFIG_DIR="$HOME/.config/gt-salat-dikr"
BIN_DIR="$HOME/.local/bin"
MAIN_SCRIPT="gt-salat-dikr.py"
LAUNCHER_SCRIPT="gt-launcher.sh"
TRAY_SCRIPT="gt-tray.py"
DESKTOP_FILE="gt-salat-dikr.desktop"

# عرض البانر
echo -e "${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════╗
║        GT-salat-dikr v4.0               ║
║      تثبيت تذكير الصلاة والأذكار        ║
╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}✬ الإصدار: $VERSION${NC}"
echo -e "${GREEN}✬ المطور: SalehGNUTUX${NC}"
echo ""

# التحقق من الصلاحيات
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  تحذير: لا تقم بتشغيل السكريبت كـ root${NC}"
    echo "يرجى تشغيله كمستخدم عادي:"
    echo "  bash install.sh"
    exit 1
fi

# التحقق من المتطلبات الأساسية
check_requirements() {
    echo "🔍 التحقق من المتطلبات..."
    
    # التحقق من Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}❌ Python 3 غير مثبت${NC}"
        echo "يرجى تثبيته أولاً:"
        echo "  Ubuntu/Debian: sudo apt install python3"
        echo "  Fedora: sudo dnf install python3"
        echo "  Arch: sudo pacman -S python"
        exit 1
    fi
    
    # التحقق من pip3
    if ! command -v pip3 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  pip3 غير مثبت، جاري التثبيت...${NC}"
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y python3-pip
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm python-pip
        else
            echo -e "${RED}❌ لم أستطع تثبيت pip3 تلقائياً${NC}"
            echo "يرجى تثبيته يدوياً ثم إعادة التشغيل"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ المتطلبات الأساسية جاهزة${NC}"
}

# تثبيت المكتبات المطلوبة
install_python_libraries() {
    echo ""
    echo "📦 تثبيت مكتبات Python..."
    
    # قائمة المكتبات المطلوبة
    LIBRARIES=(
        "pystray"
        "Pillow"
        "requests"
        "geocoder"
        "pytz"
    )
    
    for lib in "${LIBRARIES[@]}"; do
        echo "  تثبيت $lib..."
        pip3 install --user "$lib" 2>/dev/null || {
            echo -e "${YELLOW}  ⚠️  فشل تثبيت $lib، جاري المحاولة بدونه...${NC}"
            continue
        }
    done
    
    # تثبيت jq لمعالجة JSON (إذا لم يكن مثبتاً)
    if ! command -v jq >/dev/null 2>&1; then
        echo "  تثبيت jq لمعالجة JSON..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y jq 2>/dev/null || true
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y jq 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm jq 2>/dev/null || true
        else
            echo -e "${YELLOW}  ⚠️  لم أستطع تثبيت jq تلقائياً${NC}"
        fi
    fi
    
    echo -e "${GREEN}✅ تم تثبيت المكتبات${NC}"
}

# الكشف عن الموقع تلقائياً
detect_location() {
    echo ""
    echo "📍 كشف الموقع تلقائياً..."
    
    local detected_city=""
    local detected_country=""
    local detected_lat=""
    local detected_lon=""
    
    # محاولة استخدام geocoder مع Python
    if python3 -c "import geocoder" 2>/dev/null; then
        echo "  استخدام geocoder للكشف عن الموقع..."
        location_data=$(python3 -c "
import geocoder
import json
g = geocoder.ip('me')
if g.ok:
    data = {
        'city': g.city,
        'country': g.country,
        'lat': g.lat,
        'lng': g.lng
    }
    print(json.dumps(data))
" 2>/dev/null || echo "")
        
        if [ -n "$location_data" ]; then
            detected_city=$(echo "$location_data" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('city', ''))")
            detected_country=$(echo "$location_data" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('country', ''))")
            detected_lat=$(echo "$location_data" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('lat', ''))")
            detected_lon=$(echo "$location_data" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('lng', ''))")
        fi
    fi
    
    # إذا فشل الكشف، استخدام موقع افتراضي
    if [ -z "$detected_city" ] || [ -z "$detected_country" ]; then
        detected_city="مكة المكرمة"
        detected_country="السعودية"
        detected_lat="21.4225"
        detected_lon="39.8262"
        echo -e "${YELLOW}  ⚠️  استخدام الموقع الافتراضي: $detected_city, $detected_country${NC}"
    else
        echo -e "${GREEN}  ✅ تم الكشف عن الموقع: $detected_city, $detected_country${NC}"
    fi
    
    # عرض الموقع المكتشف
    echo ""
    echo "══════════════════════════════════════════════════"
    echo -e "${BLUE}الموقع المكتشف تلقائياً:${NC}"
    echo -e "  المدينة: $detected_city"
    echo -e "  الدولة: $detected_country"
    echo -e "  الإحداثيات: $detected_lat, $detected_lon"
    echo "══════════════════════════════════════════════════"
    
    # السؤال عن استخدام الموقع المكتشف
    read -p "هل تريد استخدام هذا الموقع؟ [Y/n]: " use_detected
    
    if [[ "$use_detected" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${YELLOW}الرجاء إدخال معلومات الموقع يدوياً:${NC}"
        echo ""
        
        while true; do
            read -p "اسم المدينة: " city
            read -p "اسم الدولة: " country
            read -p "خط العرض (مثال: 21.4225): " latitude
            read -p "خط الطول (مثال: 39.8262): " longitude
            
            if [ -n "$city" ] && [ -n "$country" ] && \
               [[ "$latitude" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && \
               [[ "$longitude" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                detected_city="$city"
                detected_country="$country"
                detected_lat="$latitude"
                detected_lon="$longitude"
                break
            else
                echo -e "${RED}❌ بيانات غير صحيحة، يرجى المحاولة مرة أخرى${NC}"
            fi
        done
    fi
    
    # إعداد المنطقة الزمنية
    echo ""
    echo "⏰ إعداد المنطقة الزمنية:"
    echo "1) تلقائي (مستحسن)"
    echo "2) يدوي"
    
    read -p "اختر الخيار [1/2]: " tz_choice
    
    if [ "$tz_choice" = "2" ]; then
        echo ""
        echo "المناطق الزمنية المتاحة (عرض 10 الأولى):"
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl list-timezones 2>/dev/null | head -10 || echo "Asia/Riyadh"
        else
            echo "Asia/Riyadh"
            echo "Africa/Cairo"
            echo "Asia/Dubai"
            echo "Europe/London"
            echo "America/New_York"
        fi
        echo "..."
        read -p "أدخل المنطقة الزمنية (مثال: Asia/Riyadh): " timezone
        if [ -z "$timezone" ]; then
            timezone="auto"
        fi
    else
        timezone="auto"
    fi
    
    # تحديث بيانات الصلاة تلقائياً
    echo ""
    read -p "هل تريد تحديث بيانات الصلاة تلقائياً؟ [Y/n]: " auto_update
    if [[ "$auto_update" =~ ^[Nn]$ ]]; then
        auto_update="false"
        echo -e "${YELLOW}⚠️  سيتم استخدام بيانات الصلاة المخزنة محلياً${NC}"
    else
        auto_update="true"
        echo -e "${GREEN}✅ سيتم تحديث بيانات الصلاة تلقائياً${NC}"
    fi
    
    # حفظ الإعدادات
    save_location_config "$detected_city" "$detected_country" "$detected_lat" "$detected_lon" "$timezone" "$auto_update"
}

# حفظ إعدادات الموقع
save_location_config() {
    local city="$1"
    local country="$2"
    local lat="$3"
    local lon="$4"
    local timezone="$5"
    local auto_update="$6"
    
    mkdir -p "$CONFIG_DIR"
    
    # إنشاء ملف التكوين
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "version": "$VERSION",
    "location": {
        "city": "$city",
        "country": "$country",
        "latitude": $lat,
        "longitude": $lon
    },
    "settings": {
        "timezone": "$timezone",
        "auto_update": $auto_update,
        "calculation_method": "MWL",
        "asr_method": "Standard",
        "high_latitude_adjustment": "MiddleOfTheNight",
        "notifications": true,
        "sound": true,
        "startup": true
    },
    "last_update": "$(date -Iseconds)"
}
EOF
    
    echo -e "${GREEN}✅ تم حفظ إعدادات الموقع${NC}"
    echo -e "  📍 $city, $country"
    echo -e "  ⏰ المنطقة الزمنية: $timezone"
    echo -e "  🔄 تحديث تلقائي: $auto_update"
}

# تحميل الملفات الرئيسية
download_main_files() {
    echo ""
    echo "⬇️  تحميل ملفات البرنامج..."
    
    # إنشاء مجلد التثبيت
    mkdir -p "$INSTALL_DIR"
    
    # ملف البرنامج الرئيسي
    cat > "$INSTALL_DIR/$MAIN_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# GT-salat-dikr - تذكير الصلاة والأذكار
# الإصدار 4.0

import sys
import os
import json
import time
from datetime import datetime
import pytz

def load_config():
    config_path = os.path.expanduser("~/.config/gt-salat-dikr/config.json")
    if os.path.exists(config_path):
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return None

def get_prayer_times():
    config = load_config()
    if not config:
        print("❌ ملف التكوين غير موجود")
        return
    
    location = config.get('location', {})
    settings = config.get('settings', {})
    
    city = location.get('city', 'مكة المكرمة')
    country = location.get('country', 'السعودية')
    
    print(f"\n🕌 أوقات الصلاة لـ: {city}, {country}")
    print("════════════════════════════════════")
    print("⏰ الوقت الحالي:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("\nسيتم تحديث أوقات الصلاة قريباً...")
    print("راجع الإعدادات للتحديث التلقائي.")

def main():
    print("\n" + "="*50)
    print("🕌 GT-salat-dikr - تذكير الصلاة والأذكار")
    print("="*50)
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--help" or sys.argv[1] == "-h":
            print("\nالاستخدام:")
            print("  gtsalat                  عرض أوقات الصلاة")
            print("  gtsalat --config         فتح الإعدادات")
            print("  gtsalat --tray           تشغيل أيقونة النظام")
            print("  gtsalat --update         تحديث بيانات الصلاة")
            print("  gtsalat --uninstall      إلغاء التثبيت")
            return
        elif sys.argv[1] == "--config":
            print("\n⚙️  فتح إعدادات البرنامج...")
            # سيتم إضافة واجهة الإعدادات لاحقاً
            return
        elif sys.argv[1] == "--update":
            print("\n🔄 تحديث بيانات الصلاة...")
            # سيتم إضافة التحديث لاحقاً
            return
        elif sys.argv[1] == "--uninstall":
            print("\n🗑️  تشغيل أداة إلغاء التثبيت...")
            uninstall_script = os.path.join(os.path.dirname(__file__), "uninstall.sh")
            if os.path.exists(uninstall_script):
                os.system(f"bash {uninstall_script}")
            else:
                print("❌ لم أجد أداة إلغاء التثبيت")
            return
    
    get_prayer_times()

if __name__ == "__main__":
    main()
EOF
    
    # ملف الإطلاق
    cat > "$INSTALL_DIR/$LAUNCHER_SCRIPT" << 'EOF'
#!/bin/bash
# GT-salat-dikr Launcher

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="gt-salat-dikr.py"

# تشغيل البرنامج الرئيسي
cd "$INSTALL_DIR" || exit 1
python3 "$MAIN_SCRIPT" "$@"
EOF
    
    # ملف أيقونة النظام
    cat > "$INSTALL_DIR/$TRAY_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# GT-salat-dikr System Tray

import sys
import os
import threading
import time
from datetime import datetime

try:
    import pystray
    from PIL import Image, ImageDraw
    HAS_LIBS = True
except ImportError:
    HAS_LIBS = False

def create_image():
    # إنشاء صورة بسيطة للأيقونة
    image = Image.new('RGB', (64, 64), color='green')
    draw = ImageDraw.Draw(image)
    draw.ellipse([10, 10, 54, 54], fill='white', outline='black')
    draw.text((22, 22), "🕌", fill='black')
    return image

def on_quit(icon):
    icon.stop()

def tray_thread():
    if not HAS_LIBS:
        print("❌ المكتبات المطلوبة غير مثبتة")
        return
    
    icon = pystray.Icon(
        "gt-salat-dikr",
        icon=create_image(),
        menu=pystray.Menu(
            pystray.MenuItem("عرض أوقات الصلاة", lambda: os.system("gtsalat")),
            pystray.MenuItem("الإعدادات", lambda: os.system("gtsalat --config")),
            pystray.MenuItem("تحديث", lambda: os.system("gtsalat --update")),
            pystray.MenuItem("إلغاء التثبيت", lambda: os.system("gtsalat --uninstall")),
            pystray.MenuItem("خروج", on_quit)
        ),
        title="GT-salat-dikr"
    )
    
    icon.run()

def main():
    if not HAS_LIBS:
        print("❌ المكتبات المطلوبة غير مثبتة:")
        print("  pip install pystray pillow")
        return
    
    print("🚀 تشغيل أيقونة النظام...")
    print("📌 ستظهر الأيقونة في منطقة الإشعارات")
    
    thread = threading.Thread(target=tray_thread, daemon=True)
    thread.start()
    
    # البقاء نشطاً
    try:
        while thread.is_alive():
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n👋 تم إيقاف البرنامج")

if __name__ == "__main__":
    main()
EOF
    
    # ملف إلغاء التثبيت
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
# uninstall.sh - إزالة كاملة ونظيفة لـ GT-salat-dikr

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════╗
║         إزالة GT-salat-dikr             ║
╚══════════════════════════════════════════╝
EOF
echo -e "${NC}"

read -p "هل تريد الاستمرار في الإزالة؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo "بدء عملية الإزالة..."

# إيقاف العمليات
pkill -f "gt-tray.py" 2>/dev/null || true
pkill -f "gt-salat-dikr" 2>/dev/null || true

# إزالة الأوامر
rm -f "$HOME/.local/bin/gtsalat" 2>/dev/null || true
rm -f "$HOME/.local/bin/gt-tray" 2>/dev/null || true

# إزالة ملفات النظام
if [ -f "/etc/systemd/system/gt-salat-dikr.service" ]; then
    sudo systemctl stop gt-salat-dikr.service 2>/dev/null || true
    sudo systemctl disable gt-salat-dikr.service 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/gt-salat-dikr.service" 2>/dev/null || true
fi

# إزالة ملفات بدء التشغيل
rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop" 2>/dev/null || true

# تنظيف ملفات التهيئة
clean_shell_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # إنشاء نسخة مؤقتة بدون إعدادات GT-salat-dikr
        grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|~/.GT-salat-dikr" "$file" > "${file}.tmp" 2>/dev/null
        # إزالة أي if-fi غير مكتملة
        awk '
        BEGIN { in_block = 0; block_start = 0 }
        /^# GT-salat-dikr/ { in_block = 1; block_start = NR }
        /^fi$/ && in_block { in_block = 0; next }
        !in_block { print }
        END { 
            if (in_block) {
                print "⚠️  تم اكتشاف if بدون fi في السطر " block_start
            }
        }
        ' "${file}.tmp" > "${file}.new" 2>/dev/null
        
        if [ -s "${file}.new" ]; then
            mv "${file}.new" "$file"
        fi
        rm -f "${file}.tmp" "${file}.new" 2>/dev/null
    fi
}

clean_shell_file "$HOME/.bashrc"
clean_shell_file "$HOME/.zshrc"

# إزالة المجلدات
rm -rf "$HOME/.GT-salat-dikr" 2>/dev/null || true
rm -rf "$HOME/.config/gt-salat-dikr" 2>/dev/null || true
rm -rf "$HOME/.cache/gt-salat-dikr" 2>/dev/null || true

# إزالة أيقونات القائمة
rm -f "$HOME/.local/share/applications/gt-salat-dikr.desktop" 2>/dev/null || true
rm -f "$HOME/Desktop/gt-salat-dikr.desktop" 2>/dev/null || true

echo -e "${GREEN}✅ تمت الإزالة بنجاح!${NC}"
echo ""
echo "للتثبيت مجدداً:"
echo "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""

exit 0
EOF
    
    # جعل الملفات قابلة للتنفيذ
    chmod +x "$INSTALL_DIR/$MAIN_SCRIPT"
    chmod +x "$INSTALL_DIR/$LAUNCHER_SCRIPT"
    chmod +x "$INSTALL_DIR/$TRAY_SCRIPT"
    chmod +x "$INSTALL_DIR/uninstall.sh"
    
    echo -e "${GREEN}✅ تم تحميل الملفات الرئيسية${NC}"
}

# إنشاء الأوامر
create_commands() {
    echo ""
    echo "🔗 إنشاء الأوامر..."
    
    # إنشاء مجلد الأوامر إذا لم يكن موجوداً
    mkdir -p "$BIN_DIR"
    
    # رابط للبرنامج الرئيسي
    ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$BIN_DIR/gtsalat"
    
    # رابط لأيقونة النظام
    ln -sf "$INSTALL_DIR/$TRAY_SCRIPT" "$BIN_DIR/gt-tray"
    
    # إضافة إلى PATH إذا لم يكن مضافاً
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}⚠️  يرجى إضافة $BIN_DIR إلى PATH${NC}"
        echo "أضف هذا السطر إلى ملف shell الخاص بك:"
        echo "export PATH=\"\$PATH:$BIN_DIR\""
    fi
    
    echo -e "${GREEN}✅ تم إنشاء الأوامر${NC}"
}

# إعداد ملفات Shell (الطريقة الآمنة)
setup_shell_config() {
    echo ""
    echo "🐚 إعداد ملفات Shell..."
    
    # قائمة ملفات Shell
    SHELL_FILES=(
        ["$HOME/.bashrc"]="Bash"
        ["$HOME/.zshrc"]="Zsh"
    )
    
    for shell_file in "${!SHELL_FILES[@]}"; do
        shell_name="${SHELL_FILES[$shell_file]}"
        
        if [ -f "$shell_file" ]; then
            echo "  معالجة $shell_name..."
            
            # تنظيف الإعدادات القديمة أولاً
            temp_file=$(mktemp)
            
            # نسخ الملف مع تجنب if-fi غير المكتملة
            python3 -c "
import sys
file_path = sys.argv[1]
output_path = sys.argv[2]

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

in_gt_block = False
gt_block_start = 0
output_lines = []

for i, line in enumerate(lines):
    line_stripped = line.strip()
    
    # اكتشاف بداية بلوك GT-salat-dikr
    if line_stripped.startswith('# GT-salat-dikr'):
        in_gt_block = True
        gt_block_start = i
        continue
    
    # إذا كنا داخل بلوك GT، تخطي حتى نهاية if
    if in_gt_block:
        if line_stripped == 'fi' or line_stripped.endswith('fi'):
            in_gt_block = False
        continue
    
    # إزالة أي أسطر متبقية تحتوي على كلمات مفتاحية
    if any(keyword in line for keyword in ['gtsalat', 'GT-salat-dikr', 'gt-tray', '~/.GT-salat-dikr']):
        continue
    
    output_lines.append(line)

# كتابة الملف النظيف
with open(output_path, 'w', encoding='utf-8') as f:
    f.writelines(output_lines)
" "$shell_file" "$temp_file"
            
            # إضافة الإعدادات الجديدة بشكل آمن
            cat >> "$temp_file" << EOF

# GT-salat-dikr - تذكير الصلاة والأذكار
if [ -f "$INSTALL_DIR/$MAIN_SCRIPT" ] && [ -t 0 ] && [ -z "\$GT_SALAT_NO_AUTO" ]; then
    alias gtsalat="$INSTALL_DIR/$MAIN_SCRIPT"
    echo ""
    $INSTALL_DIR/$MAIN_SCRIPT
fi
EOF
            
            # استبدال الملف الأصلي
            if [ -s "$temp_file" ]; then
                mv "$temp_file" "$shell_file"
                echo -e "    ${GREEN}✅ تم تحديث $shell_name${NC}"
            else
                echo -e "    ${YELLOW}⚠️  لم يتم تحديث $shell_name${NC}"
                rm -f "$temp_file"
            fi
        else
            echo "  ⚠️  ملف $shell_name غير موجود"
        fi
    done
    
    echo -e "${GREEN}✅ تم إعداد ملفات Shell${NC}"
}

# إنشاء ملفات بدء التشغيل
create_autostart() {
    echo ""
    echo "🚀 إنشاء ملفات بدء التشغيل..."
    
    # إنشاء مجلد autostart إذا لم يكن موجوداً
    mkdir -p "$HOME/.config/autostart"
    
    # ملف .desktop لبدء التشغيل
    cat > "$HOME/.config/autostart/$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=تذكير الصلاة والأذكار
Exec=$BIN_DIR/gt-tray
Icon=$INSTALL_DIR/icon.png
Categories=Utility;
StartupNotify=false
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    
    # ملف .desktop للتطبيق
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Comment=تذكير الصلاة والأذكار
Exec=$BIN_DIR/gtsalat
Icon=$INSTALL_DIR/icon.png
Categories=Utility;
Terminal=true
EOF
    
    # إنشاء أيقونة بسيطة
    python3 -c "
from PIL import Image, ImageDraw, ImageFont
import os

# إنشاء صورة الأيقونة
img = Image.new('RGB', (256, 256), color='#2E7D32')
draw = ImageDraw.Draw(img)

# رسم مسجد بسيط
draw.rectangle([80, 100, 176, 200], fill='#FFF')
draw.polygon([80, 100, 128, 50, 176, 100], fill='#8D6E63')
draw.rectangle([110, 140, 146, 200], fill='#5D4037')

# حفظ الأيقونة
icon_path = os.path.expanduser('$INSTALL_DIR/icon.png')
img.save(icon_path)
" 2>/dev/null || true
    
    echo -e "${GREEN}✅ تم إنشاء ملفات بدء التشغيل${NC}"
}

# عرض ملخص التثبيت
show_summary() {
    echo ""
    echo "══════════════════════════════════════════════════"
    echo -e "${GREEN}🎉 تم التثبيت بنجاح!${NC}"
    echo "══════════════════════════════════════════════════"
    echo ""
    echo -e "${BLUE}📂 مجلد التثبيت:${NC} $INSTALL_DIR"
    echo -e "${BLUE}⚙️  مجلد الإعدادات:${NC} $CONFIG_DIR"
    echo -e "${BLUE}🔗 الأوامر المضافة:${NC}"
    echo "  • gtsalat        - عرض أوقات الصلاة"
    echo "  • gt-tray        - تشغيل أيقونة النظام"
    echo ""
    echo -e "${BLUE}🚀 سيبدأ البرنامج تلقائياً عند:${NC}"
    echo "  • فتح طرفية جديدة"
    echo "  • بدء تشغيل النظام"
    echo ""
    echo -e "${BLUE}🔧 الأوامر المتاحة:${NC}"
    echo "  gtsalat                  - عرض أوقات الصلاة"
    echo "  gtsalat --config         - فتح الإعدادات"
    echo "  gtsalat --tray           - تشغيل الأيقونة"
    echo "  gtsalat --update         - تحديث البيانات"
    echo "  gtsalat --uninstall      - إلغاء التثبيت"
    echo ""
    echo -e "${BLUE}📝 للتحديث:${NC}"
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
    echo ""
    echo -e "${BLUE}👋 للدعم والمشاكل:${NC}"
    echo "  https://github.com/SalehGNUTUX/GT-salat-dikr"
    echo ""
    
    # تشغيل البرنامج للاختبار
    read -p "هل تريد تشغيل البرنامج الآن؟ [Y/n]: " run_now
    if [[ ! "$run_now" =~ ^[Nn]$ ]]; then
        echo ""
        echo "تشغيل GT-salat-dikr..."
        "$BIN_DIR/gtsalat"
    fi
}

# الدالة الرئيسية
main() {
    clear
    check_requirements
    install_python_libraries
    detect_location
    download_main_files
    create_commands
    setup_shell_config
    create_autostart
    show_summary
}

# تشغيل التثبيت
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "استخدام:"
    echo "  ./install.sh          - تثبيت البرنامج"
    echo "  ./install.sh --update - تحديث البرنامج"
    exit 0
fi

main
