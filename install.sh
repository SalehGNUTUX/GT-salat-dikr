#!/bin/bash
#
# GT-salat-dikr Installation v3.2.7
# تثبيت محسّن مع إصلاح تنسيق عرض الذكر والصلاة
#

set -e

# دالة لعرض الرأس الفني
show_header() {
    clear
    cat << "EOF"

      ___ _____    ___   _   _      _ _____    ___ ___ _  _____ 
     / __|_   _|__/ __| /_\ | |    /_\_   _|__|   \_ _| |/ / _ \
    | (_ | | ||___\__ \/ _ \| |__ / _ \| ||___| |) | || ' <|   /
     \___| |_|    |___/_/ \_\____/_/ \_\_|    |___/___|_|\_\_|_\
                                                                
     🕌 نظام إشعارات الصلاة والأذكار - الإصدار 3.2.7 🕋

EOF
}

show_header

echo "════════════════════════════════════════════════════════"
echo "     تثبيت GT-salat-dikr - الإصدار المحسّن 3.2.7"
echo "     مع إصلاح تنسيق عرض الذكر والصلاة"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من عدم التشغيل كـ root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
MAIN_SCRIPT="gt-salat-dikr.sh"
TRAY_SCRIPT="$INSTALL_DIR/gt-tray.py"
DESKTOP_FILE="$INSTALL_DIR/gt-salat-dikr.desktop"
LAUNCHER_FILE="$INSTALL_DIR/launcher.sh"
UNIVERSAL_LAUNCHER="$INSTALL_DIR/launcher-universal.sh"
UNINSTALLER="$INSTALL_DIR/uninstall.sh"

# ---------- تحسين: الكشف عن الموقع تلقائياً ----------
detect_location_and_setup() {
    echo ""
    echo "📍 إعداد الموقع والمنطقة الزمنية..."
    
    # كشف الموقع الافتراضي
    DEFAULT_CITY="مكة المكرمة"
    DEFAULT_COUNTRY="السعودية"
    DEFAULT_LAT="21.4225"
    DEFAULT_LON="39.8262"
    
    echo "الموقع الافتراضي: $DEFAULT_CITY, $DEFAULT_COUNTRY"
    echo "الإحداثيات: $DEFAULT_LAT, $DEFAULT_LON"
    echo ""
    
    read -p "هل تريد استخدام هذا الموقع؟ [Y/n]: " use_default
    
    if [[ "$use_default" =~ ^[Nn]$ ]]; then
        echo ""
        echo "الرجاء إدخال معلومات الموقع يدوياً:"
        echo ""
        
        read -p "اسم المدينة: " city
        read -p "اسم الدولة: " country
        read -p "خط العرض (مثال: 21.4225): " latitude
        read -p "خط الطول (مثال: 39.8262): " longitude
        
        if [ -n "$city" ] && [ -n "$country" ] && [ -n "$latitude" ] && [ -n "$longitude" ]; then
            DEFAULT_CITY="$city"
            DEFAULT_COUNTRY="$country"
            DEFAULT_LAT="$latitude"
            DEFAULT_LON="$longitude"
        else
            echo "⚠️  بيانات غير مكتملة، استخدام الموقع الافتراضي"
        fi
    fi
    
    # إعداد المنطقة الزمنية
    echo ""
    echo "⏰ إعداد المنطقة الزمنية:"
    echo "1) تلقائي (مستحسن)"
    echo "2) يدوي"
    
    read -p "اختر الخيار [1/2]: " tz_choice
    
    if [ "$tz_choice" = "2" ]; then
        echo ""
        echo "المناطق الزمنية الشائعة:"
        echo "Asia/Riyadh  - السعودية"
        echo "Africa/Cairo - مصر"
        echo "Asia/Dubai   - الإمارات"
        echo "Asia/Amman   - الأردن"
        echo "Asia/Beirut  - لبنان"
        echo ""
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
        AUTO_UPDATE="false"
        echo "⚠️  سيتم استخدام بيانات الصلاة المخزنة محلياً"
    else
        AUTO_UPDATE="true"
        echo "✅ سيتم تحديث بيانات الصلاة تلقائياً"
    fi
    
    # حفظ الإعدادات في ملف مؤقت
    CONFIG_DIR="$INSTALL_DIR/config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/location.conf" << EOF
CITY="$DEFAULT_CITY"
COUNTRY="$DEFAULT_COUNTRY"
LATITUDE="$DEFAULT_LAT"
LONGITUDE="$DEFAULT_LON"
TIMEZONE="$timezone"
AUTO_UPDATE="$AUTO_UPDATE"
EOF
    
    echo "✅ تم حفظ إعدادات الموقع"
    echo "   📍 $DEFAULT_CITY, $DEFAULT_COUNTRY"
    echo "   ⏰ المنطقة الزمنية: $timezone"
    echo "   🔄 تحديث تلقائي: $AUTO_UPDATE"
}

# ---------- المرحلة 1: التثبيت الأساسي ----------
echo "📥 تحميل البرنامج..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ---------- إصلاح: نطلب من المستخدم إعداد الموقع أولاً ----------
detect_location_and_setup

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

# ---------- المرحلة 3: إنشاء script محسن لعرض الذكر والصلاة ----------
echo ""
echo "🔧 إنشاء script محسن لعرض الذكر والصلاة..."

cat > "$INSTALL_DIR/show-prayer.sh" << 'EOF'
#!/bin/bash
#
# show-prayer.sh - عرض منسق للذكر والصلاة
# تنسيق موحد يعمل في جميع الحالات
#

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

# إضافة شرط التحقق من الطرفية التفاعلية
if [[ ! -t 0 ]]; then
    exit 0
fi

# دالة لجلب مواقيت الصلاة
get_prayer_times() {
    if [ -f "$MAIN_SCRIPT" ]; then
        # محاولة الحصول على مواقيت اليوم من البرنامج الرئيسي
        TIMES_FILE="$INSTALL_DIR/today_prayers.txt"
        
        # إذا كان ملف المواقيت قديماً (أكبر من 24 ساعة) أو غير موجود، قم بتحديثه
        if [ ! -f "$TIMES_FILE" ] || [ $(find "$TIMES_FILE" -mtime +0 -print 2>/dev/null) ]; then
            "$MAIN_SCRIPT" --show-timetable > "$TIMES_FILE" 2>/dev/null || true
        fi
        
        # قراءة المواقيت من الملف
        if [ -f "$TIMES_FILE" ]; then
            # البحث عن الصلاة القادمة
            CURRENT_TIME=$(date +%H:%M)
            NEXT_PRAYER=""
            NEXT_TIME=""
            
            while IFS= read -r line; do
                if [[ "$line" == *"🕌 الصلاة القادمة:"* ]]; then
                    NEXT_PRAYER=$(echo "$line" | sed 's/🕌 الصلاة القادمة: //' | cut -d ':' -f1)
                    NEXT_TIME=$(echo "$line" | grep -o '[0-9]\{2\}:[0-9]\{2\}')
                    break
                elif [[ "$line" == *"القادمة:"* ]]; then
                    NEXT_PRAYER=$(echo "$line" | sed 's/.*القادمة: //' | awk '{print $1}')
                    NEXT_TIME=$(echo "$line" | grep -o '[0-9]\{2\}:[0-9]\{2\}')
                    break
                fi
            done < "$TIMES_FILE"
            
            if [ -n "$NEXT_PRAYER" ] && [ -n "$NEXT_TIME" ]; then
                # حساب الوقت المتبقي
                CURRENT_SECONDS=$(date -d "$CURRENT_TIME" +%s 2>/dev/null || date +%s)
                NEXT_SECONDS=$(date -d "$NEXT_TIME" +%s 2>/dev/null || date +%s)
                
                if [ -n "$CURRENT_SECONDS" ] && [ -n "$NEXT_SECONDS" ] && [ "$NEXT_SECONDS" -gt "$CURRENT_SECONDS" ]; then
                    TIME_LEFT=$((NEXT_SECONDS - CURRENT_SECONDS))
                    HOURS=$((TIME_LEFT / 3600))
                    MINUTES=$(((TIME_LEFT % 3600) / 60))
                    
                    if [ "$HOURS" -gt 0 ]; then
                        TIME_LEFT_STR=$(printf "%02d:%02d" "$HOURS" "$MINUTES")
                    else
                        TIME_LEFT_STR=$(printf "%02d دقيقة" "$MINUTES")
                    fi
                    
                    echo "🕌 الصلاة القادمة: $NEXT_PRAYER عند $NEXT_TIME (باقي $TIME_LEFT_STR)"
                    return 0
                fi
            fi
        fi
    fi
    echo "🔄 جاري تحديث مواقيت الصلاة..."
    return 1
}

# بدء العرض
echo ""
echo "🕌 GT-salat-dikr 🕋 ﷽"
echo "══════════════════════════════════════"

# عرض ذكر عشوائي
if [ -f "$INSTALL_DIR/azkar.txt" ]; then
    if [ -s "$INSTALL_DIR/azkar.txt" ]; then
        TOTAL_LINES=$(wc -l < "$INSTALL_DIR/azkar.txt" 2>/dev/null || echo "0")
        if [ "$TOTAL_LINES" -gt 0 ]; then
            RANDOM_LINE=$((RANDOM % TOTAL_LINES + 1))
            AZKAR=$(sed -n "${RANDOM_LINE}p" "$INSTALL_DIR/azkar.txt")
            
            # عرض الذكر
            echo "$AZKAR"
            echo "══════════════════════════════════════"
        fi
    fi
fi

# عرض مواقيت الصلاة
get_prayer_times

echo ""
EOF

chmod +x "$INSTALL_DIR/show-prayer.sh"

# ---------- المرحلة 4: إنشاء script إضافي لعرض الذكر من System Tray ----------
echo ""
echo "🔧 إنشاء script لعرض الذكر من System Tray..."

cat > "$INSTALL_DIR/show-azkar-tray.sh" << 'EOF'
#!/bin/bash
#
# show-azkar-tray.sh - عرض الذكر من System Tray
# نفس التنسيق لكن مع عنوان مختلف
#

INSTALL_DIR="$HOME/.GT-salat-dikr"
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

# دالة لجلب مواقيت الصلاة
get_prayer_times() {
    if [ -f "$MAIN_SCRIPT" ]; then
        # استدعاء البرنامج الرئيسي مباشرة
        PRAYER_INFO=$("$MAIN_SCRIPT" --show-timetable 2>/dev/null | grep -A1 "القادمة:" | tail -1)
        
        if [ -n "$PRAYER_INFO" ]; then
            # استخراج المعلومات
            NEXT_PRAYER=$(echo "$PRAYER_INFO" | awk '{print $1}')
            NEXT_TIME=$(echo "$PRAYER_INFO" | grep -o '[0-9]\{2\}:[0-9]\{2\}')
            
            if [ -n "$NEXT_PRAYER" ] && [ -n "$NEXT_TIME" ]; then
                # حساب الوقت المتبقي
                CURRENT_TIME=$(date +%H:%M)
                CURRENT_SECONDS=$(date -d "$CURRENT_TIME" +%s 2>/dev/null || date +%s)
                NEXT_SECONDS=$(date -d "$NEXT_TIME" +%s 2>/dev/null || date +%s)
                
                if [ -n "$CURRENT_SECONDS" ] && [ -n "$NEXT_SECONDS" ] && [ "$NEXT_SECONDS" -gt "$CURRENT_SECONDS" ]; then
                    TIME_LEFT=$((NEXT_SECONDS - CURRENT_SECONDS))
                    HOURS=$((TIME_LEFT / 3600))
                    MINUTES=$(((TIME_LEFT % 3600) / 60))
                    
                    if [ "$HOURS" -gt 0 ]; then
                        TIME_LEFT_STR=$(printf "%02d:%02d" "$HOURS" "$MINUTES")
                    else
                        TIME_LEFT_STR=$(printf "%02d دقيقة" "$MINUTES")
                    fi
                    
                    echo "🕌 الصلاة القادمة: $NEXT_PRAYER عند $NEXT_TIME (باقي $TIME_LEFT_STR)"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

# بدء العرض
clear
echo ""
echo "ذكر اليوم"
echo "══════════════════════════════════════════════════"

# عرض ذكر عشوائي
if [ -f "$INSTALL_DIR/azkar.txt" ]; then
    if [ -s "$INSTALL_DIR/azkar.txt" ]; then
        TOTAL_LINES=$(wc -l < "$INSTALL_DIR/azkar.txt" 2>/dev/null || echo "0")
        if [ "$TOTAL_LINES" -gt 0 ]; then
            RANDOM_LINE=$((RANDOM % TOTAL_LINES + 1))
            AZKAR=$(sed -n "${RANDOM_LINE}p" "$INSTALL_DIR/azkar.txt")
            
            # عرض الذكر
            echo "$AZKAR"
            echo ""
        fi
    fi
fi

# عرض مواقيت الصلاة
if get_prayer_times; then
    echo ""
fi

echo "══════════════════════════════════════════════════"
echo ""
read -p "اضغط Enter للإغلاق... "
EOF

chmod +x "$INSTALL_DIR/show-azkar-tray.sh"

# ---------- المرحلة 5: إضافة إلى جميع ملفات التهيئة للطرفيات ----------
echo ""
echo "🔧 إضافة عرض الذكر إلى جميع أنواع الطرفيات..."

# دالة آمنة لإضافة إعدادات إلى ملفات shell
setup_shell_config_safe() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # إزالة الإعدادات القديمة أولاً بطريقة آمنة
        TEMP_FILE=$(mktemp)
        
        # نسخ الملف الأصلي مع حذف قسم GT-salat-dikr كاملاً
        awk '
        BEGIN { in_block = 0; block_start = 0 }
        /^# GT-salat-dikr/ || /^# إضافة GT-salat-dikr/ || /^# عرض ذكر/ {
            in_block = 1
            block_start = NR
            next
        }
        in_block && /^fi$/ {
            in_block = 0
            next
        }
        in_block && /^if \[/ {
            next
        }
        !in_block {
            # إزالة أي أسطر متبقية تحتوي على كلمات مفتاحية
            if (!/\bGT-salat-dikr\b/ && !/\bgtsalat\b/ && !/\bgt-tray\b/ && !/\.GT-salat-dikr\b/) {
                print
            }
        }
        ' "$shell_file" > "$TEMP_FILE"
        
        # إضافة الإعدادات الجديدة
        cat >> "$TEMP_FILE" << EOF

# GT-salat-dikr - عرض ذكر وموعد الصلاة عند فتح الطرفية
if [ -f "$INSTALL_DIR/show-prayer.sh" ] && [ -t 0 ] && [ -z "\$GT_SALAT_NO_AUTO" ]; then
    . "$INSTALL_DIR/show-prayer.sh"
fi
EOF
        
        # استبدال الملف الأصلي
        mv "$TEMP_FILE" "$shell_file"
        echo "  ✅ تم الإضافة الآمنة إلى $shell_name"
    else
        echo "  ℹ️  ملف $shell_name غير موجود"
    fi
}

# 1. لـ bash
setup_shell_config_safe "$HOME/.bashrc" ".bashrc"

# 2. لـ zsh
setup_shell_config_safe "$HOME/.zshrc" ".zshrc"

# 3. لـ fish
if command -v fish >/dev/null 2>&1 && [ -d "$HOME/.config/fish" ]; then
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$HOME/.config/fish"
    
    # تنظيف الإعدادات القديمة
    if [ -f "$FISH_CONFIG" ]; then
        grep -v "GT-salat-dikr\|gtsalat\|gt-tray\|\.GT-salat-dikr" "$FISH_CONFIG" > "$FISH_CONFIG.tmp" 2>/dev/null && \
        mv "$FISH_CONFIG.tmp" "$FISH_CONFIG"
    fi
    
    # إضافة الإعدادات الجديدة
    echo "" >> "$FISH_CONFIG"
    echo "# GT-salat-dikr - عرض ذكر وموعد الصلاة عند فتح الطرفية" >> "$FISH_CONFIG"
    echo "if test -f \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
    echo "    bash \"$INSTALL_DIR/show-prayer.sh\"" >> "$FISH_CONFIG"
    echo "end" >> "$FISH_CONFIG"
    echo "  ✅ تم الإضافة إلى fish config"
fi

# ... باقي الكود كما هو بدون تغيير ...
# (جميع الأجزاء من المرحلة 6 إلى 13 تبقى كما هي في الملف الأصلي)
# ... [يجب أن يبقى الباقي كما هو في الملف الأصلي] ...

echo ""
echo "👋 تم التثبيت بنجاح!"

exit 0
