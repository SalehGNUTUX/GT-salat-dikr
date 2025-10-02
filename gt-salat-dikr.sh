#!/bin/bash
#
# GT-salat-dikr Enhanced Installation Script
# يدعم جميع توزيعات Linux وبيئات سطح المكتب
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من الصلاحيات
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  تحذير: لا تشغل هذا السكربت بصلاحيات root"
    echo "   استخدم حساب المستخدم العادي."
    exit 1
fi

# المتغيرات
INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

# التحقق من الأدوات المطلوبة
echo "🔍 فحص المتطلبات..."
MISSING_TOOLS=()

if ! command -v curl >/dev/null 2>&1; then
    MISSING_TOOLS+=("curl")
fi

if ! command -v jq >/dev/null 2>&1; then
    MISSING_TOOLS+=("jq")
fi

if ! command -v notify-send >/dev/null 2>&1; then
    MISSING_TOOLS+=("libnotify (notify-send)")
fi

# اكتشاف الأدوات الرسومية
GUI_FOUND=0
if command -v zenity >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ zenity متوفر"
elif command -v yad >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ yad متوفر"
elif command -v kdialog >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ kdialog متوفر"
fi

if [ $GUI_FOUND -eq 0 ]; then
    echo "  ⚠️ لم يتم العثور على أداة رسومية (zenity/yad/kdialog)"
    echo "     سيتم استخدام إشعارات بسيطة فقط"
fi

# عرض الأدوات الناقصة
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "❌ الأدوات التالية مفقودة:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "   - $tool"
    done
    echo ""
    echo "📦 تعليمات التثبيت حسب التوزيعة:"
    echo ""
    echo "Debian/Ubuntu/Mint:"
    echo "  sudo apt install curl jq libnotify-bin zenity"
    echo ""
    echo "Fedora/RHEL/CentOS:"
    echo "  sudo dnf install curl jq libnotify zenity"
    echo ""
    echo "Arch/Manjaro:"
    echo "  sudo pacman -S curl jq libnotify zenity"
    echo ""
    echo "openSUSE:"
    echo "  sudo zypper install curl jq libnotify-tools zenity"
    echo ""
    read -p "هل تريد المتابعة على أي حال؟ (قد لا تعمل بعض الميزات) [y/N]: " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        echo "تم إلغاء التثبيت."
        exit 1
    fi
fi

echo ""
echo "📥 جاري التحميل والتثبيت..."

# إنشاء مجلد التثبيت
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# تحميل الملفات الرئيسية
echo "  → تحميل السكربت الرئيسي..."
curl -fsSL "$REPO_BASE/gt-salat-dikr.sh" -o gt-salat-dikr.sh
chmod +x gt-salat-dikr.sh

echo "  → تحميل ملف الأذكار..."
curl -fsSL "$REPO_BASE/azkar.txt" -o azkar.txt 2>/dev/null || {
    echo "     تحذير: فشل تحميل azkar.txt - سيتم إنشاء ملف افتراضي"
    cat > azkar.txt <<'EOF'
سبحان الله وبحمده، سبحان الله العظيم
%
لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير
%
اللهم صل على محمد وعلى آل محمد
%
استغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه
%
حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم
EOF
}

echo "  → تحميل ملف الأذان..."
curl -fsSL "$REPO_BASE/adhan.ogg" -o adhan.ogg 2>/dev/null || {
    echo "     تحذير: فشل تحميل adhan.ogg - ابحث عن ملف أذان وضعه في $INSTALL_DIR"
}

# إنشاء الاختصار
echo "  → إنشاء اختصار gtsalat..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat"

# إعداد الطرفيات لدعم التشغيل التلقائي لجميع الأنواع
echo "  → إعداد الطرفيات لدعم تشغيل GT-salat-dikr تلقائياً..."

# bash
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && ! grep -q 'gt-salat-dikr' "$BASHRC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    echo '[[ -f "$HOME/.GT-salat-dikr/gt-salat-dikr.sh" ]] && source "$HOME/.GT-salat-dikr/gt-salat-dikr.sh"' >> "$BASHRC"
fi

# zsh
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && ! grep -q 'gt-salat-dikr' "$ZSHRC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    echo '[[ -f "$HOME/.GT-salat-dikr/gt-salat-dikr.sh" ]] && source "$HOME/.GT-salat-dikr/gt-salat-dikr.sh"' >> "$ZSHRC"
fi

# fish
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"
if [ ! -f "$FISH_CONFIG" ] || ! grep -q 'gt-salat-dikr' "$FISH_CONFIG"; then
    echo 'set -gx PATH $HOME/.local/bin $PATH' >> "$FISH_CONFIG"
    echo 'source $HOME/.GT-salat-dikr/gt-salat-dikr.sh' >> "$FISH_CONFIG"
fi

# ksh أو طرفيات أخرى باستخدام .profile
PROFILE="$HOME/.profile"
if [ -f "$PROFILE" ] && ! grep -q 'gt-salat-dikr' "$PROFILE"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
    echo '[[ -f "$HOME/.GT-salat-dikr/gt-salat-dikr.sh" ]] && source "$HOME/.GT-salat-dikr/gt-salat-dikr.sh"' >> "$PROFILE"
fi

# تحديث PATH الحالي للجلسة
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "✅ تم التثبيت بنجاح!"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  الخطوات التالية:"
echo "════════════════════════════════════════════════════════"
echo ""
echo "1️⃣  إعداد الموقع والإعدادات:"
echo "   gtsalat --settings"
echo ""
echo "2️⃣  بدء الإشعارات:"
echo "   gtsalat --notify-start"
echo ""
echo "3️⃣  عرض مواقيت الصلاة:"
echo "   gtsalat --show-timetable"
echo ""
echo "4️⃣  اختبار الإشعارات:"
echo "   gtsalat --test-notify"
echo "   gtsalat --test-adhan"
echo ""
echo "ℹ️  للحصول على المساعدة الكاملة:"
echo "   gtsalat --help"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# سؤال المستخدم عن الإعداد الفوري
read -p "هل تريد إعداد البرنامج الآن؟ [Y/n]: " setup_now
setup_now=${setup_now:-Y}

if [[ "$setup_now" =~ ^[Yy]$ ]]; then
    echo ""
    "$INSTALL_DIR/gt-salat-dikr.sh" --settings
    
    echo ""
    read -p "هل تريد بدء الإشعارات الآن؟ [Y/n]: " start_now
    start_now=${start_now:-Y}
    
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        "$INSTALL_DIR/gt-salat-dikr.sh" --notify-start
        echo ""
        echo "🎉 تم! البرنامج يعمل الآن في الخلفية"
        echo "   وسيبدأ تلقائياً عند بدء تشغيل النظام"
    fi
else
    echo ""
    echo "💡 لإعداد البرنامج لاحقاً، شغّل: gtsalat --settings"
fi

echo ""
echo "🌟 شكراً لاستخدام GT-salat-dikr!"
echo "════════════════════════════════════════════════════════"
