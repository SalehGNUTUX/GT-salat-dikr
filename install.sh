[file name]: install.sh
[file content begin]
#!/bin/bash
# مثبت GT-salat-dikr - نسخة مصححة تماماً

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "╔══════════════════════════════════════════════╗"
echo "║           تثبيت GT-salat-dikr               ║"
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
    # تنظيف التثبيت القديم
    rm -rf "$INSTALL_DIR"
    rm -f "$HOME/.local/bin/gtsalat"
    echo "🔄 تنظيف التثبيت القديم..."
fi

echo "🔄 إنشاء مجلد التثبيت في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# --- التحقق من الأدوات المطلوبة ---
check_requirements() {
    echo "🔍 التحقق من الأدوات المطلوبة..."
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "❌ curl غير مثبت - ضروري للتثبيت"
        echo "📦 على Ubuntu/Debian: sudo apt install curl"
        exit 1
    fi
    
    if ! command -v notify-send >/dev/null 2>&1; then
        echo "⚠️  تحذير: notify-send غير مثبت - الإشعارات قد لا تعمل"
    fi
    
    echo "✅ جميع الأدوات الأساسية متوفرة"
}
check_requirements

# --- تحميل الملفات ---
echo ""
echo "📥 جلب الملفات المطلوبة..."

# تحميل azkar.txt
echo "⏳ جلب ملف الأذكار..."
if curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$AZKAR_FILE"; then
    echo "✅ تم جلب azkar.txt"
else
    echo "❌ فشل جلب azkar.txt"
    exit 1
fi

# تحميل السكربت الرئيسي
echo "⏳ جلب السكربت الرئيسي..."
if curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$SCRIPT_NAME"; then
    echo "✅ تم جلب $SCRIPT_NAME"
else
    echo "❌ فشل جلب $SCRIPT_NAME"
    exit 1
fi

# تحميل ملف الآذان (اختياري)
echo "⏳ جلب ملف الآذان..."
if curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "adhan.ogg"; then
    echo "✅ تم جلب ملف الآذان"
else
    echo "⚠️  تعذر جلب ملف الآذان (سيتم استخدام بديل)"
    # إنشاء ملف آذان بديل فارغ
    touch "adhan.ogg"
fi

# منح صلاحيات التنفيذ
chmod +x "$SCRIPT_NAME"
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
Exec=bash -c "sleep 20 && '$INSTALL_DIR/$SCRIPT_NAME' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
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

# --- الإعدادات الأولية (مرة واحدة فقط) ---
echo ""
echo "⚙️  بدء إعدادات التهيئة الأولى..."

# التحقق إذا كانت الإعدادات موجودة مسبقاً
if [ ! -f "settings.conf" ]; then
    echo "🔧 إعدادات جديدة - بدء المعالج..."
    if bash "$SCRIPT_NAME" --settings; then
        echo "✅ تم إكمال الإعدادات بنجاح"
    else
        echo "⚠️  حدثت مشكلة أثناء الإعدادات"
        echo "💡 يمكنك تعديلها لاحقاً باستخدام: gtsalat --settings"
    fi
else
    echo "ℹ️  تم العثور على إعدادات سابقة - الاحتفاظ بها"
fi

# --- بدء الإشعارات فوراً ---
echo ""
echo "🔔 بدء إشعارات التذكير التلقائية..."
read -p "هل تريد بدء الإشعارات الآن؟ [Y/n]: " start_now
start_now=${start_now:-Y}

if [[ "$start_now" =~ ^[Yy]$ ]]; then
    echo "⏳ بدء الإشعارات في الخلفية..."
    
    # استخدام الطريقة المباشرة بدلاً من nohup
    if bash "$SCRIPT_NAME" --notify-start; then
        echo "✅ تم بدء الإشعارات بنجاح"
        sleep 2
        
        # التحقق من أن الإشعارات تعمل
        if [ -f ".gt-salat-dikr-notify.pid" ]; then
            local pid=$(cat ".gt-salat-dikr-notify.pid" 2>/dev/null || echo "")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "✅ الإشعارات تعمل بشكل صحيح (PID: $pid)"
            else
                echo "⚠️  الإشعارات بدأت ولكن قد تحتاج إلى فحص السجلات"
            fi
        fi
    else
        echo "❌ فشل بدء الإشعارات - يمكنك بدؤها يدوياً لاحقاً"
        echo "💡 استخدم: gtsalat --notify-start"
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
echo "   gtsalat                    # عرض ذكر ومواقيت الصلاة"
echo "   gtsalat --notify-start     # بدء الإشعارات"
echo "   gtsalat --notify-stop      # إيقاف الإشعارات"  
echo "   gtsalat --show-timetable   # عرض مواقيت الصلاة"
echo "   gtsalat --status          # عرض حالة البرنامج"
echo "   gtsalat --settings        # تغيير الإعدادات"
echo ""
echo "💡 نصائح:"
echo "   - استخدم 'gtsalat --status' للتحقق من حالة البرنامج"
echo "   - استخدم 'gtsalat --help' لعرض جميع الخيارات"
echo ""
echo "📖 للدعم: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
[file content end]
