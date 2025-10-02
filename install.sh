#!/bin/bash
# مثبت GT-salat-dikr - متوافق مع النسخة المحسنة

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
ADHAN_FILE="adhan.ogg"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "═══════════════════════════════════════════════════════════"
echo "  🕌 تثبيت GT-salat-dikr - النسخة المحسنة 🕌"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "🔄 إنشاء مجلد التثبيت: $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- التحقق من الأدوات المطلوبة ---
echo "🔍 التحقق من الأدوات المطلوبة..."
check_requirements() {
    local missing_tools=()
    
    for tool in curl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ الأدوات التالية مطلوبة: ${missing_tools[*]}"
        echo "📦 على Ubuntu/Debian: sudo apt install ${missing_tools[*]}"
        echo "📦 على Fedora: sudo dnf install ${missing_tools[*]}"
        echo "📦 على Arch: sudo pacman -S ${missing_tools[*]}"
        exit 1
    fi
    echo "✅ جميع الأدوات متوفرة"
}
check_requirements

# --- إضافة ~/.local/bin إلى PATH ---
add_to_path() {
    echo "📝 تحديث مسار التنفيذ..."
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc_file" ]; then
            if ! grep -q "PATH.*\.local/bin" "$rc_file"; then
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$rc_file"
                echo "✅ تم إضافة PATH إلى $rc_file"
            fi
        fi
    done
    
    export PATH="$HOME/.local/bin:$PATH"
}
add_to_path

# --- تحميل الملفات ---
echo ""
echo "📥 جلب الملفات من المستودع..."

download_file() {
    local file="$1"
    local dest="$2"
    
    if curl -fsSL "$REPO_RAW_URL/$file" -o "$dest"; then
        echo "✅ تم جلب $file"
        return 0
    else
        echo "❌ فشل جلب $file"
        return 1
    fi
}

# تحميل السكربت الرئيسي
if ! download_file "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"; then
    exit 1
fi

# تحميل الأذكار
download_file "$AZKAR_FILE" "$INSTALL_DIR/$AZKAR_FILE"

# تحميل الأذان (اختياري)
if download_file "$ADHAN_FILE" "$INSTALL_DIR/$ADHAN_FILE"; then
    echo "🔊 سيعمل المشغل الرسومي للأذان"
else
    echo "⚠️ ستعمل الإشعارات النصية فقط بدون صوت"
fi

# جعل السكربت قابلاً للتنفيذ
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء اختصار ---
echo ""
echo "🔗 إنشاء اختصار التنفيذ..."
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$HOME/.local/bin/gtsalat"
echo "✅ يمكنك الآن استخدام: gtsalat"

# --- الإعدادات الأولية ---
echo ""
echo "⚙️  إعداد التهيئة الأولى..."
cd "$INSTALL_DIR"

# استخدام الإعدادات التلقائية إذا لم تكن موجودة
if [ ! -f "settings.conf" ]; then
    echo "🔧 تشغيل معالج الإعدادات..."
    if ! bash "$SCRIPT_NAME" --settings; then
        echo "⚠️  تم استخدام الإعدادات الافتراضية"
    fi
else
    echo "✅ الإعدادات موجودة مسبقاً"
fi

# --- إضافة التشغيل التلقائي للطرفية ---
echo ""
echo "🔧 إعداد التشغيل التلقائي..."
add_shell_integration() {
    local added=false
    
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc_file" ]; then
            if ! grep -q "GT-salat-dikr" "$rc_file"; then
                cat >> "$rc_file" <<EOF

# GT-salat-dikr - عرض ذكر وصلاة عند فتح الطرفية
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    "$INSTALL_DIR/$SCRIPT_NAME"
fi
EOF
                echo "✅ تم الإضافة إلى $rc_file"
                added=true
            fi
        fi
    done
    
    if [ "$added" = true ]; then
        echo "📝 سيظهر ذكر وصلاة عند كل فتح للطرفية"
    fi
}
add_shell_integration

# --- إنشاء خدمات التشغيل التلقائي ---
setup_autostart() {
    echo "🚀 إعداد التشغيل التلقائي عند بدء النظام..."
    
    # نظام autostart لبيئات سطح المكتب
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr
Name[ar]=إشعارات الصلاة والأذكار
Comment=Automatic prayer times and azkar notifications
Comment[ar]=إشعارات تلقائية لأوقات الصلاة والأذكار
Exec=bash -c "sleep 30 && cd '$INSTALL_DIR' && ./'$SCRIPT_NAME' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Type=Application
Categories=Utility;
Icon=preferences-system-time
EOF
    echo "✅ تم إنشاء autostart لبيئات سطح المكتب"

    # نظام systemd للمستخدم
    if command -v systemctl >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/systemd/user"
        cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Notifications
After=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$SCRIPT_NAME --child-notify
Restart=on-failure
RestartSec=30
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus

[Install]
WantedBy=default.target
EOF
        
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user enable gt-salat-dikr.service >/dev/null 2>&1 || true
        echo "✅ تم تفعيل systemd service"
    fi
}
setup_autostart

# --- بدء الخدمة ---
echo ""
echo "🔔 بدء خدمة الإشعارات..."
start_notifications() {
    cd "$INSTALL_DIR"
    
    # إيقاف أي خدمة سابقة
    pkill -f "gt-salat-dikr.sh --child-notify" 2>/dev/null || true
    sleep 2
    
    # بدء الخدمة الجديدة
    nohup bash -c "
        export DBUS_SESSION_BUS_ADDRESS='unix:path=/run/user/$(id -u)/bus'
        export DISPLAY='${DISPLAY:-:0}'
        cd '$INSTALL_DIR'
        sleep 10
        exec './$SCRIPT_NAME' --notify-start
    " > "$INSTALL_DIR/startup.log" 2>&1 &
    
    echo "⏳ انتظر 15 ثانية لبدء الخدمة..."
    sleep 15
    
    # التحقق من التشغيل
    if [ -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" ]; then
        local pid=$(cat "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "✅ الخدمة تعمل (PID: $pid)"
            return 0
        fi
    fi
    
    echo "⚠️  الخدمة لم تبدأ بعد، جرب: gtsalat --notify-start"
    return 1
}
start_notifications

# --- اختبار الميزات ---
echo ""
echo "🧪 اختبار الميزات الأساسية..."
cd "$INSTALL_DIR"

echo "📖 اختبار عرض الأذكار..."
if ./"$SCRIPT_NAME" 2>/dev/null | grep -q .; then
    echo "✅ عرض الأذكار يعمل"
else
    echo "⚠️  مشكلة في عرض الأذكار"
fi

echo "🔔 اختبار الإشعارات..."
if ./"$SCRIPT_NAME" --test-notify 2>/dev/null; then
    echo "✅ الإشعارات تعمل"
else
    echo "⚠️  مشكلة في الإشعارات"
fi

# --- العرض النهائي ---
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  🎉 تم التثبيت بنجاح!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✨ الميزات المثبتة:"
echo "   📱 مشغل أذان رسومي مع واجهة تفاعلية"
echo "   🔔 إشعارات صوتية ومرئية للصلاة"
echo "   📖 أذكار عشوائية تلقائية"
echo "   🕒 تنبيه قبل الصلاة بـ10 دقائق"
echo "   🌍 دعم 20+ طريقة لحساب المواقيت"
echo "   🔄 تحديث تلقائي"
echo "   💾 تشغيل تلقائي عند بدء النظام"
echo ""
echo "🔧 أوامر التحكم:"
echo "   gtsalat                    # عرض ذكر وصلاة تالية"
echo "   gtsalat --notify-start     # بدء الإشعارات"
echo "   gtsalat --notify-stop      # إيقاف الإشعارات"
echo "   gtsalat --show-timetable   # مواقيت الصلاة"
echo "   gtsalat --status           # حالة النظام"
echo "   gtsalat --test-adhan       # اختبار الأذان"
echo "   gtsalat --test-notify      # اختبار الإشعارات"
echo "   gtsalat --settings         # الإعدادات"
echo "   gtsalat --self-update      # تحديث"
echo ""
echo "📁 معلومات التثبيت:"
echo "   المجلد: $INSTALL_DIR"
echo "   السجلات: $INSTALL_DIR/notify.log"
echo "   إعدادات: $INSTALL_DIR/settings.conf"
echo ""
echo "💡 نصائح:"
echo "   - الإشعارات ستبدأ تلقائياً عند إعادة التشغيل"
echo "   - استخدم gtsalat --status للتحقق من العمل"
echo "   - gtsalat --test-adhan لاختبار مشغل الأذان"
echo ""

# عرض حالة أولية
echo "📊 الحالة الحالية:"
cd "$INSTALL_DIR" && ./"$SCRIPT_NAME" --status 2>/dev/null || echo "⚠️  جرب: gtsalat --status"

echo ""
echo "🎊 تم الانتهاء! جرب البرنامج الآن: gtsalat"
