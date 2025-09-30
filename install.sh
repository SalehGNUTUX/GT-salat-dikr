[file name]: install-gt-salat-dikr.sh
[file content begin]
#!/bin/bash
# مثبت GT-salat-dikr - نسخة محسنة ومتوافقة مع الإصدار الجديد

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "╔══════════════════════════════════════════════╗"
echo "║           تثبيت GT-salat-dikr               ║"
echo "║           النسخة المحسنة                   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# التحقق من التثبيت المسبق
if [ -d "$INSTALL_DIR" ] && [ -f "$HOME/.local/bin/gtsalat" ]; then
    echo "⚠️  تم العثور على تثبيت سابق لـ GT-salat-dikr"
    read -p "هل تريد إعادة التثبيت؟ [y/N]: " reinstall
    reinstall=${reinstall:-N}
    if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
        echo "❌ تم إلغاء التثبيت."
        exit 0
    fi
    echo "🔄 المتابعة بإعادة التثبيت..."
fi

echo "🔄 إنشاء مجلد التثبيت في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- التحقق من الأدوات المطلوبة ---
check_requirements() {
    echo "🔍 التحقق من الأدوات المطلوبة..."
    
    local missing_tools=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if ! command -v notify-send >/dev/null 2>&1; then
        echo "⚠️  تحذير: notify-send غير مثبت - الإشعارات قد لا تعمل"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "⚠️  تحذير: jq غير مثبت - بعض الميزات قد لا تعمل"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ الأدوات التالية غير مثبتة: ${missing_tools[*]}"
        echo "📦 يرجى تثبيتها أولاً باستخدام مدير الحزم الخاص بتوزيعتك."
        exit 1
    fi
    
    echo "✅ جميع الأدوات الأساسية متوفرة"
}
check_requirements

# --- إضافة ~/.local/bin إلى PATH ---
add_to_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "📝 إضافة ~/.local/bin إلى PATH..."
        
        # إضافة إلى .bashrc
        if [ -f "$HOME/.bashrc" ]; then
            if ! grep -q "\.local/bin" "$HOME/.bashrc"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            fi
        fi
        
        # إضافة إلى .zshrc
        if [ -f "$HOME/.zshrc" ]; then
            if ! grep -q "\.local/bin" "$HOME/.zshrc"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
            fi
        fi
        
        # تعيين PATH للجلسة الحالية
        export PATH="$HOME/.local/bin:$PATH"
        echo "✅ تم إضافة ~/.local/bin إلى PATH"
    fi
}
add_to_path

# --- تحميل الملفات ---
echo ""
echo "📥 جلب الملفات المطلوبة..."

# تحميل azkar.txt
echo "⏳ جلب ملف الأذكار..."
if curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "✅ تم جلب azkar.txt"
else
    echo "❌ فشل جلب azkar.txt"
    exit 1
fi

# تحميل السكربت الرئيسي
echo "⏳ جلب السكربت الرئيسي..."
if curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "✅ تم جلب $SCRIPT_NAME"
else
    echo "❌ فشل جلب $SCRIPT_NAME"
    exit 1
fi

# تحميل ملف الآذان (اختياري)
echo "⏳ جلب ملف الآذان..."
if curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$INSTALL_DIR/adhan.ogg"; then
    echo "✅ تم جلب ملف الآذان"
else
    echo "⚠️  تعذر جلب ملف الآذان (سيتم استخدام بديل)"
    # إنشاء ملف آذان بديل فارغ
    touch "$INSTALL_DIR/adhan.ogg"
fi

# منح صلاحيات التنفيذ
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "✅ تم منح صلاحيات التنفيذ للسكربت"

# --- إنشاء اختصار ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
if ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"; then
    echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"
else
    echo "❌ فشل إنشاء الاختصار"
    exit 1
fi

# --- إعداد التشغيل التلقائي ---
setup_autostart() {
    echo ""
    echo "⚙️  إعداد التشغيل التلقائي..."
    
    local autostart_dir="$HOME/.config/autostart"
    local service_file="$autostart_dir/gt-salat-dikr.desktop"
    mkdir -p "$autostart_dir"

    cat > "$service_file" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Name[ar]=إشعارات الصلاة والأذكار
Exec=bash -c "sleep 25 && '$INSTALL_DIR/$SCRIPT_NAME' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
Comment=Automatic prayer times and azkar notifications
Comment[ar]=إشعارات تلقائية لأوقات الصلاة والأذكار
Icon=preferences-system-time
Categories=Utility;
EOF

    if [ -f "$service_file" ]; then
        echo "✅ تم إضافة خدمة التشغيل التلقائي"
    else
        echo "❌ فشل إنشاء خدمة التشغيل التلقائي"
    fi
}
setup_autostart

# --- الإعدادات الأولية ---
echo ""
echo "⚙️  بدء إعدادات التهيئة الأولى..."
cd "$INSTALL_DIR"

# تشغيل معالج الإعدادات
if bash "$SCRIPT_NAME" --settings; then
    echo "✅ تم إكمال الإعدادات بنجاح"
else
    echo "⚠️  حدثت مشكلة أثناء الإعدادات - يمكنك تعديلها لاحقاً باستخدام: gtsalat --settings"
fi

# --- بدء الإشعارات فوراً ---
echo ""
echo "🔔 بدء إشعارات التذكير التلقائية..."
read -p "هل تريد بدء الإشعارات الآن؟ [Y/n]: " start_now
start_now=${start_now:-Y}

if [[ "$start_now" =~ ^[Yy]$ ]]; then
    if cd "$INSTALL_DIR" && nohup bash -c "sleep 5 && ./'$SCRIPT_NAME' --notify-start" > /dev/null 2>&1 & then
        echo "✅ تم بدء الإشعارات في الخلفية"
        sleep 2
        # التحقق من أن الإشعارات تعمل
        if [ -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" ]; then
            local pid=$(cat "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "✅ الإشعارات تعمل بشكل صحيح (PID: $pid)"
            else
                echo "⚠️  الإشعارات بدأت ولكن قد تحتاج إلى فحص السجلات"
            fi
        fi
    else
        echo "❌ فشل بدء الإشعارات - يمكنك بدؤها يدوياً لاحقاً"
    fi
else
    echo "ℹ️  يمكنك بدء الإشعارات لاحقاً باستخدام: gtsalat --notify-start"
fi

# --- عرض ملخص التثبيت ---
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            تم التثبيت بنجاح! 🎉            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📋 معلومات التثبيت:"
echo "   📁 مجلد التثبيت: $INSTALL_DIR"
echo "   📝 سجلات البرنامج: $INSTALL_DIR/notify.log"
echo "   🔧 الاختصار: gtsalat (متاح من أي مكان)"
echo ""
echo "🎛️  أوامر التحكم:"
echo "   gtsalat --notify-start    # بدء الإشعارات"
echo "   gtsalat --notify-stop     # إيقاف الإشعارات"
echo "   gtsalat --show-timetable  # عرض مواقيت الصلاة"
echo "   gtsalat --status          # عرض حالة البرنامج"
echo "   gtsalat --settings        # تغيير الإعدادات"
echo "   gtsalat --test-notify     # اختبار الإشعارات"
echo "   gtsalat --test-adhan      # اختبار الأذان"
echo ""
echo "💡 نصائح:"
echo "   - استخدم 'gtsalat --status' للتحقق من حالة البرنامج"
echo "   - استخدم 'gtsalat --help' لعرض جميع الخيارات"
echo "   - السجلات متاحة في: $INSTALL_DIR/notify.log"
echo ""
echo "📖 للدعم والمزيد: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
[file content end]
