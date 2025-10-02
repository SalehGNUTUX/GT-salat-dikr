#!/bin/bash
# مثبت GT-salat-dikr - النسخة المحسنة مع كل المزايا الجديدة

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

echo "🔄 التثبيت في: $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- إضافة ~/.local/bin إلى PATH ---
add_to_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "📝 إضافة ~/.local/bin إلى PATH..."
        for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
            if [ -f "$rc_file" ]; then
                if ! grep -q "\.local/bin" "$rc_file"; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
                fi
            fi
        done
        export PATH="$HOME/.local/bin:$PATH"
        echo "✅ تم إضافة ~/.local/bin إلى PATH"
    fi
}
add_to_path

# --- تحميل الملفات ---
echo ""
echo "📥 جلب الملفات المطلوبة..."

# تحميل azkar.txt
echo "📖 جلب ملف الأذكار..."
if curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "✅ تم جلب azkar.txt"
else
    echo "❌ فشل جلب azkar.txt"
    exit 1
fi

# تحميل السكربت الرئيسي (النسخة المحسنة)
echo "🔄 جلب السكربت الرئيسي (النسخة المحسنة)..."
if curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "✅ تم جلب $SCRIPT_NAME"
else
    echo "❌ فشل جلب $SCRIPT_NAME"
    exit 1
fi

# تحميل ملف الآذان
echo "🔊 جلب ملف الأذان..."
if curl -fsSL "$REPO_RAW_URL/$ADHAN_FILE" -o "$INSTALL_DIR/$ADHAN_FILE"; then
    echo "✅ تم جلب ملف الأذان"
else
    echo "⚠️ تعذر جلب ملف الأذان - سيتم استخدام الإشعارات النصية فقط"
fi

# جعل السكربت قابلاً للتنفيذ
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء اختصار ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار: gtsalat"

# --- إضافة التشغيل التلقائي للطرفية ---
add_to_shell_rc() {
    local RC_FILE="$1"
    if [ -f "$RC_FILE" ]; then
        if ! grep -Fq "$INSTALL_DIR/$SCRIPT_NAME" "$RC_FILE"; then
            echo "" >> "$RC_FILE"
            echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$RC_FILE"
            echo "cd '$INSTALL_DIR' && './$SCRIPT_NAME'" >> "$RC_FILE"
            echo "✅ تم الإضافة إلى $RC_FILE"
        else
            echo "ℹ️ موجود مسبقاً في $RC_FILE"
        fi
    fi
}

echo ""
echo "🔗 إضافة التشغيل التلقائي للطرفية..."
add_to_shell_rc "$HOME/.bashrc"
add_to_shell_rc "$HOME/.zshrc"

# --- إنشاء ملفات التشغيل التلقائي المتقدمة ---
create_advanced_autostart() {
    echo "🚀 إنشاء خدمات التشغيل التلقائي المتقدمة..."
    
    # 1. XDG Autostart
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Name[ar]=إشعارات الصلاة والأذكار
Exec=bash -c "cd '$INSTALL_DIR' && sleep 30 && './$SCRIPT_NAME' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-MATE-Autostart-enabled=true
StartupNotify=false
Terminal=false
Icon=preferences-system-time
Comment=Automatic prayer times and azkar notifications
Comment[ar]=إشعارات تلقائية لأوقات الصلاة والأذكار
Categories=Utility;
EOF

    # 2. systemd user service
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Notifications
After=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$SCRIPT_NAME --child-notify
Restart=on-failure
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"

[Install]
WantedBy=default.target
EOF

    # تفعيل systemd service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable gt-salat-dikr.service 2>/dev/null || true
        echo "✅ تم إنشاء وتفعيل systemd service"
    fi

    echo "✅ تم إنشاء جميع خدمات التشغيل التلقائي"
}
create_advanced_autostart

# --- الإعدادات الأولية ---
echo ""
echo "⚙️  بدء إعدادات التهيئة الأولى..."
cd "$INSTALL_DIR"
if ! bash "$SCRIPT_NAME" --settings; then
    echo "⚠️  فشل الإعدادات التلقائية، سيتم استخدام الإعدادات الافتراضية"
fi

# --- بدء الإشعارات فوراً (بطريقة محسنة) ---
echo ""
echo "🔔 بدء إشعارات التذكير التلقائية..."
cd "$INSTALL_DIR"

# تنظيف أي عمليات سابقة
pkill -f "gt-salat-dikr.sh --child-notify" 2>/dev/null || true
sleep 2

# بدء العملية الجديدة
nohup bash -c "
    cd '$INSTALL_DIR'
    export DBUS_SESSION_BUS_ADDRESS='unix:path=/run/user/$(id -u)/bus'
    export DISPLAY='${DISPLAY:-:0}'
    sleep 15
    exec './$SCRIPT_NAME' --notify-start
" > "$INSTALL_DIR/install.log" 2>&1 &

# --- الانتظار والتحقق من التشغيل ---
echo "⏳ الانتظار لبدء الخدمة (15 ثانية)..."
sleep 15

# التحقق المتقدم من أن الإشعارات تعمل
check_service_status() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ -f "$INSTALL_DIR/.gt-salat-dikr-notify.pid" ]; then
            PID=$(cat "$INSTALL_DIR/.gt-salat-dikr-notify.pid" 2>/dev/null || echo "")
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                echo "✅ تم بدء إشعارات GT-salat-dikr (PID: $PID)"
                return 0
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "⏳ محاولة $attempt/$max_attempts - إعادة المحاولة..."
            sleep 5
        fi
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  الإشعارات قيد البدء... قد تحتاج لبدء يدوي"
    return 1
}

check_service_status

# --- عرض المزايا المثبتة ---
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  🎉 تم التثبيت بنجاح! المزايا المتوفرة:"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✨ المزايا الجديدة:"
echo "   📱 مشغل أذان رسومي مع واجهة (zenity/yad/kdialog)"
echo "   🔔 إشعارات صوتية ومرئية للصلاة"
echo "   📖 أذكار عشوائية كل 5 دقائق"
echo "   🕒 تنبيه قبل الصلاة بـ10 دقائق"
echo "   🌍 دعم جميع طرق حساب المواقيت"
echo "   🔄 تحديث تلقائي للأذكار والبرنامج"
echo "   💾 تشغيل تلقائي عند بدء النظام"
echo ""
echo "🔧 أوامر التحكم:"
echo "   gtsalat                    # عرض ذكر وصلاة التالية"
echo "   gtsalat --notify-start     # بدء الإشعارات"
echo "   gtsalat --notify-stop      # إيقاف الإشعارات"
echo "   gtsalat --show-timetable   # عرض مواقيت الصلاة"
echo "   gtsalat --status           # عرض حالة النظام"
echo "   gtsalat --test-adhan       # اختبار مشغل الأذان"
echo "   gtsalat --test-notify      # اختبار الإشعارات"
echo "   gtsalat --settings         # تغيير الإعدادات"
echo "   gtsalat --self-update      # تحديث البرنامج"
echo ""
echo "📁 معلومات التثبيت:"
echo "   المجلد: $INSTALL_DIR"
echo "   السجلات: $INSTALL_DIR/notify.log"
echo "   الإعدادات: $INSTALL_DIR/settings.conf"
echo ""
echo "💡 سيتم تشغيل الإشعارات تلقائياً عند:"
echo "   - فتح الطرفية (عرض ذكر وصلاة)"
echo "   - بدء النظام (إشعارات خلفية)"
echo "   - وقت الصلاة (أذان رسومي)"
echo ""

# اختبار سريع
echo "🧪 إجراء اختبار سريع..."
cd "$INSTALL_DIR"
if ./"$SCRIPT_NAME" --test-notify; then
    echo "✅ اختبار الإشعارات ناجح"
else
    echo "⚠️  اختبار الإشعارات فشل - تحقق من إعدادات DBUS"
fi

echo ""
echo "🎊 تم الانتهاء من التثبيت! جرب: gtsalat --status"
