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
if curl -fsSL "$REPO_BASE/gt-salat-dikr.sh" -o gt-salat-dikr.sh; then
    echo "     ✓ تم تحميل السكربت الرئيسي"
else
    echo "     ❌ فشل تحميل السكربت الرئيسي"
    exit 1
fi
chmod +x gt-salat-dikr.sh

echo "  → تحميل ملف الأذكار..."
if curl -fsSL "$REPO_BASE/azkar.txt" -o azkar.txt; then
    echo "     ✓ تم تحميل ملف الأذكار من المستودع"
else
    echo "     ⚠️ فشل تحميل الأذكار - إنشاء ملف احتياطي..."
    # ملف أذكار احتياطي شامل
    cat > azkar.txt <<'EOF'
سبحان الله وبحمده، سبحان الله العظيم
%
لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير
%
اللهم صل على محمد وعلى آل محمد كما صليت على إبراهيم وعلى آل إبراهيم إنك حميد مجيد
%
اللهم بارك على محمد وعلى آل محمد كما باركت على إبراهيم وعلى آل إبراهيم إنك حميد مجيد
%
استغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه
%
حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم
%
لا حول ولا قوة إلا بالله العلي العظيم
%
الله لا إله إلا هو الحي القيوم لا تأخذه سنة ولا نوم له ما في السماوات وما في الأرض
%
اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك علي، وأبوء بذنبي فاغفر لي فإنه لا يغفر الذنوب إلا أنت
%
سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر
%
الحمد لله الذي بنعمته تتم الصالحات
%
اللهم إني أعوذ بك من الهم والحزن، والعجز والكسل، والجبن والبخل، وضلع الدين وغلبة الرجال
%
اللهم إني أعوذ بك من العجز والكسل، والجبن والهرم، والبخل، وأعوذ بك من عذاب القبر، ومن فتنة المحيا والممات
%
رضيت بالله ربا، وبالإسلام دينا، وبمحمد صلى الله عليه وسلم نبيا ورسولا
%
اللهم إني أسألك علما نافعا، ورزقا طيبا، وعملا متقبلا
%
اللهم أصلح لي ديني الذي هو عصمة أمري، وأصلح لي دنياي التي فيها معاشي، وأصلح لي آخرتي التي فيها معادي، واجعل الحياة زيادة لي في كل خير، واجعل الموت راحة لي من كل شر
%
بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم
%
أعوذ بكلمات الله التامات من شر ما خلق
%
اللهم إني أعوذ بك من شر نفسي، ومن شر كل دابة أنت آخذ بناصيتها، إن ربي على صراط مستقيم
%
حسبنا الله ونعم الوكيل
%
لا إله إلا أنت سبحانك إني كنت من الظالمين
%
يا حي يا قيوم برحمتك أستغيث أصلح لي شأني كله ولا تكلني إلى نفسي طرفة عين
%
اللهم اهدني فيمن هديت، وعافني فيمن عافيت، وتولني فيمن توليت، وبارك لي فيما أعطيت، وقني شر ما قضيت، إنك تقضي ولا يقضى عليك، إنه لا يذل من واليت، تباركت ربنا وتعاليت
%
سبحان الله عدد ما خلق، سبحان الله ملء ما خلق، سبحان الله عدد ما في الأرض والسماء، سبحان الله ملء ما في الأرض والسماء، سبحان الله عدد كل شيء، سبحان الله ملء كل شيء
%
لا إله إلا الله وحده لا شريك له، له الملك وله الحمد يحيي ويميت وهو على كل شيء قدير
%
اللهم إنك عفو تحب العفو فاعف عني
%
اللهم إني أسألك من الخير كله عاجله وآجله ما علمت منه وما لم أعلم، وأعوذ بك من الشر كله عاجله وآجله ما علمت منه وما لم أعلم
%
اللهم إني أسألك الجنة وما قرب إليها من قول أو عمل، وأعوذ بك من النار وما قرب إليها من قول أو عمل
%
سبحان الله وبحمده، عدد خلقه، ورضا نفسه، وزنة عرشه، ومداد كلماته
%
لا إله إلا الله الملك الحق المبين
%
اللهم إني أعوذ برضاك من سخطك، وبمعافاتك من عقوبتك، وأعوذ بك منك، لا أحصي ثناء عليك، أنت كما أثنيت على نفسك
%
يا مقلب القلوب ثبت قلبي على دينك
%
اللهم مصرف القلوب صرف قلوبنا على طاعتك
%
ما شاء الله كان، وما لم يشأ لم يكن
%
الحمد لله على كل حال
%
توكلت على الحي الذي لا يموت
%
اللهم لا سهل إلا ما جعلته سهلا، وأنت تجعل الحزن إذا شئت سهلا
%
اللهم إني أعوذ بك من زوال نعمتك، وتحول عافيتك، وفجاءة نقمتك، وجميع سخطك
%
اللهم كما حسنت خلقي فحسن خلقي
%
اللهم اجعلني شكورا، اجعلني صبورا، اجعلني في عيني صغيرا، وفي أعين الناس كبيرا
%
اللهم طهر قلبي من النفاق، وعملي من الرياء، ولساني من الكذب، وعيني من الخيانة، فإنك تعلم خائنة الأعين وما تخفي الصدور
EOF
    echo "     ✓ تم إنشاء ملف أذكار احتياطي شامل"
fi

echo "  → تحميل ملف الأذان..."
if curl -fsSL "$REPO_BASE/adhan.ogg" -o adhan.ogg; then
    echo "     ✓ تم تحميل ملف الأذان"
else
    echo "     ⚠️ فشل تحميل الأذان - يمكنك إضافة ملف أذان لاحقاً في $INSTALL_DIR"
fi

# إنشاء الاختصار
echo "  → إنشاء اختصار gtsalat..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/gt-salat-dikr.sh" "$HOME/.local/bin/gtsalat"

# التأكد من أن ~/.local/bin في PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "  → إضافة ~/.local/bin إلى PATH..."
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            if ! grep -q '.local/bin' "$rc_file"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
            fi
        fi
    done
    export PATH="$HOME/.local/bin:$PATH"
fi

# ========== الإضافات الجديدة ==========

# 1. إضافة إلى bashrc للعرض عند فتح الطرفية
echo "  → إضافة GT-salat-dikr إلى الطرفية..."
if ! grep -q "GT-salat-dikr" ~/.bashrc; then
    cat >> ~/.bashrc << 'EOF'

# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية
"$HOME/.GT-salat-dikr/gt-salat-dikr.sh"
EOF
    echo "     ✓ تم إضافة GT-salat-dikr إلى ~/.bashrc"
else
    echo "     ⓘ GT-salat-dikr موجود مسبقاً في ~/.bashrc"
fi

# 2. إضافة إلى zshrc إذا كان موجوداً
if [ -f ~/.zshrc ] && ! grep -q "GT-salat-dikr" ~/.zshrc; then
    cat >> ~/.zshrc << 'EOF'

# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية
"$HOME/.GT-salat-dikr/gt-salat-dikr.sh"
EOF
    echo "     ✓ تم إضافة GT-salat-dikr إلى ~/.zshrc"
fi

# 3. إنشاء ملف autostart لبدء التشغيل التلقائي
echo "  → إنشاء بدء تشغيل تلقائي..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/gt-salat-dikr.desktop << EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 30 && $HOME/.GT-salat-dikr/gt-salat-dikr.sh --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
StartupNotify=false
Terminal=false
Comment=Automatic prayer times and azkar notifications
EOF
echo "     ✓ تم إنشاء بدء تشغيل تلقائي"

# 4. إنشاء systemd service (اختياري)
echo "  → إنشاء خدمة systemd (اختياري)..."
mkdir -p ~/.config/systemd/user
USER_ID=$(id -u)
cat > ~/.config/systemd/user/gt-salat-dikr.service << EOF
[Unit]
Description=GT-salat-dikr Prayer Notifications
After=graphical-session.target

[Service]
Type=simple
ExecStart=$HOME/.GT-salat-dikr/gt-salat-dikr.sh --child-notify
Restart=on-failure
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus"
Environment="DISPLAY=:0"

[Install]
WantedBy=default.target
EOF

# تفعيل الخدمة إذا طلب المستخدم
read -p "هل تريد تفعيل خدمة systemd للتشغيل التلقائي؟ [y/N]: " enable_systemd
if [[ "$enable_systemd" =~ ^[Yy]$ ]]; then
    systemctl --user daemon-reload
    systemctl --user enable gt-salat-dikr.service
    systemctl --user start gt-salat-dikr.service
    echo "     ✓ تم تفعيل خدمة systemd"
else
    echo "     ⓘ تم تخطي خدمة systemd"
fi

# ========== نهاية الإضافات ==========

echo ""
echo "✅ تم التثبيت بنجاح!"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  الخطوات التالية:"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🎯 الميزات المثبتة تلقائياً:"
echo "   ✓ اختصار gtsalat في PATH"
echo "   ✓ ملف أذكار شامل (${#AZKAR_COUNT} ذكر)"
echo "   ✓ عرض الأذكار عند فتح الطرفية"
echo "   ✓ بدء تشغيل تلقائي مع النظام"
echo "   ✓ خدمة systemd (اختياري)"
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
echo ""
echo "🔄 لتحديث الأذكار لاحقاً:"
echo "   gtsalat --update-azkar"
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
