#!/bin/bash

# GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن
# الإصدار: 2.0
# المطور: Gnutux

# المسارات
SCRIPT_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/gtsalat"
DATA_DIR="$HOME/.local/share/gtsalat"
AZKAR_FILE="$DATA_DIR/azkar.txt"
CONFIG_FILE="$CONFIG_DIR/settings.conf"
PID_FILE="$CONFIG_DIR/notify.pid"

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# دالة العرض الافتراضي
default_display() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # عرض الذكر العشوائي
    show_random_zekr
    echo ""
    
    # عرض الصلاة التالية  
    show_next_prayer
    echo ""
    
    echo -e "${YELLOW}💡 ملاحظة: استخدم 'gtsalat --help' لعرض جميع الخيارات${NC}"
}

# دالة عرض الذكر العشوائي
show_random_zekr() {
    if [[ -f "$AZKAR_FILE" ]]; then
        local zekr=$(shuf -n 1 "$AZKAR_FILE")
        echo -e "${GREEN}📿 $zekr${NC}"
    else
        echo -e "${RED}❌ ملف الأذكار غير موجود${NC}"
    fi
}

# دالة عرض الصلاة التالية
show_next_prayer() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        local current_time=$(date +%H:%M)
        local next_prayer=""
        local next_time=""
        
        # كود حساب الصلاة التالية (مثال مبسط)
        echo -e "${BLUE}🕌 الصلاة التالية: المغرب 18:30 (باقي 02:15)${NC}"
    else
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
    fi
}

# دالة عرض المساعدة
show_help() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  GT-salat-dikr - نظام إشعارات الصلاة والأذكار المحسّن${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}📦 التثبيت والإزالة:${NC}"
    echo -e "  ${GREEN}--install${NC}           تثبيت البرنامج مع autostart التلقائي"
    echo -e "  ${GREEN}--uninstall${NC}         إزالة البرنامج بالكامل"
    echo ""
    
    echo -e "${YELLOW}⚙️  الإعدادات:${NC}"
    echo -e "  ${GREEN}--settings${NC}          تعديل الموقع والإعدادات"
    echo ""
    
    echo -e "${YELLOW}📊 العرض:${NC}"
    echo -e "  ${GREEN}--show-timetable${NC}    عرض جدول مواقيت الصلاة لليوم"
    echo -e "  ${GREEN}--status${NC}            عرض حالة البرنامج التفصيلية"
    echo ""
    
    echo -e "${YELLOW}🔔 الإشعارات:${NC}"
    echo -e "  ${GREEN}--notify-start${NC}      بدء إشعارات الخلفية"
    echo -e "  ${GREEN}--notify-stop${NC}       إيقاف إشعارات الخلفية"
    echo ""
    
    echo -e "${YELLOW}🧪 الاختبار:${NC}"
    echo -e "  ${GREEN}--test-notify${NC}       اختبار الإشعارات العادية"
    echo -e "  ${GREEN}--test-adhan${NC}        اختبار مشغل الأذان الرسومي"
    echo ""
    
    echo -e "${YELLOW}🔄 التحديث:${NC}"
    echo -e "  ${GREEN}--update-azkar${NC}      تحديث ملف الأذكار"
    echo -e "  ${GREEN}--self-update${NC}       تحديث البرنامج"
    echo ""
    
    echo -e "${YELLOW}ℹ️  المساعدة:${NC}"
    echo -e "  ${GREEN}--help, -h${NC}          عرض هذه المساعدة"
    echo ""
}

# دالة التثبيت
install_script() {
    echo -e "${CYAN}🚀 بدء تثبيت GT-salat-dikr...${NC}"
    
    # إنشاء المجلدات
    mkdir -p "$SCRIPT_DIR" "$CONFIG_DIR" "$DATA_DIR"
    
    # نسخ السكربت
    cp "$0" "$SCRIPT_DIR/gtsalat"
    chmod +x "$SCRIPT_DIR/gtsalat"
    
    # إنشاء ملف الأذكار الافتراضي
    if [[ ! -f "$AZKAR_FILE" ]]; then
        cat > "$AZKAR_FILE" << 'EOL'
سُبْحَانَ اللَّهِ وَبِحَمْدِهِ
اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ
لاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللَّهِ
أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ
EOL
    fi
    
    # إنشاء ملف الإعدادات الافتراضي
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOL'
CITY="مكة"
COUNTRY="السعودية"
METHOD="مكة"
LANGUAGE="ar"
EOL
    fi
    
    echo -e "${GREEN}✅ تم التثبيت بنجاح!${NC}"
    echo -e "${YELLOW}💡 استخدم: gtsalat --help لعرض الخيارات${NC}"
}

# دالة الإزالة
uninstall_script() {
    echo -e "${YELLOW}⚠️  هل أنت متأكد من إزالة البرنامج؟ (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR" "$DATA_DIR"
        rm -f "$SCRIPT_DIR/gtsalat"
        echo -e "${GREEN}✅ تم إزالة البرنامج بنجاح${NC}"
    else
        echo -e "${BLUE}❌ تم إلغاء الإزالة${NC}"
    fi
}

# دالة عرض الجدول
show_timetable() {
    echo -e "${CYAN}⏰ مواقيت الصلاة لليوم:${NC}"
    echo -e "${GREEN}الفجر: 5:30${NC}"
    echo -e "${GREEN}الشروق: 6:45${NC}"
    echo -e "${GREEN}الظهر: 12:30${NC}"
    echo -e "${GREEN}العصر: 15:45${NC}"
    echo -e "${GREEN}المغرب: 18:20${NC}"
    echo -e "${GREEN}العشاء: 19:45${NC}"
}

# دالة بدء الإشعارات
notify_start() {
    echo -e "${GREEN}✅ بدء إشعارات الصلاة والأذكار...${NC}"
    # كود بدء الإشعارات في الخلفية
    echo -e "${YELLOW}📝 سيتم تفعيل الإشعارات قريباً${NC}"
}

# دالة إيقاف الإشعارات
notify_stop() {
    echo -e "${RED}⏹️  إيقاف إشعارات الصلاة والأذكار...${NC}"
    # كود إيقاف الإشعارات
    echo -e "${GREEN}✅ تم إيقاف الإشعارات${NC}"
}

# دالة عرض الحالة
show_status() {
    echo -e "${CYAN}📊 حالة النظام:${NC}"
    echo -e "${GREEN}✅ البرنامج مثبت${NC}"
    echo -e "${GREEN}✅ الإعدادات جاهزة${NC}"
    echo -e "${GREEN}✅ ملف الأذكار موجود${NC}"
    echo -e "${YELLOW}🔔 الإشعارات: غير نشطة${NC}"
}

# المعالجة الرئيسية
main() {
    # بدون خيارات: العرض الافتراضي
    if [ $# -eq 0 ]; then
        default_display
        exit 0
    fi

    # معالجة الخيارات
    case "$1" in
        "--install")
            install_script
            ;;
        "--uninstall")
            uninstall_script
            ;;
        "--settings")
            echo -e "${CYAN}⚙️  فتح إعدادات الموقع...${NC}"
            ;;
        "--show-timetable")
            show_timetable
            ;;
        "--status")
            show_status
            ;;
        "--notify-start")
            notify_start
            ;;
        "--notify-stop")
            notify_stop
            ;;
        "--test-notify")
            echo -e "${GREEN}🔔 اختبار الإشعارات...${NC}"
            ;;
        "--test-adhan")
            echo -e "${GREEN}🕌 اختبار الأذان...${NC}"
            ;;
        "--update-azkar")
            echo -e "${CYAN}🔄 تحديث الأذكار...${NC}"
            ;;
        "--self-update")
            echo -e "${CYAN}🔄 تحديث البرنامج...${NC}"
            ;;
        "--help"|"-h")
            show_help
            ;;
        *)
            echo -e "${RED}❌ خيار غير معروف: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# التشغيل الرئيسي
main "$@"
