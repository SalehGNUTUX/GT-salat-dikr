#!/bin/bash
# مثبت GT-salat-dikr - نسخة مُصلحة للإشعارات بدون مشاكل الطرفية

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "🔄 تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- إضافة ~/.local/bin إلى PATH (سطر واحد لكل طرفية) ---
add_to_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "📝 إضافة ~/.local/bin إلى PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
        export PATH="$HOME/.local/bin:$PATH"
        echo "✅ تم إضافة ~/.local/bin إلى PATH"
    fi
}
add_to_path

# --- تحميل الملفات ---
echo "📥 جلب الملفات المطلوبة..."

# تحميل azkar.txt
curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE" || {
    echo "❌ فشل جلب azkar.txt"
    exit 1
}
echo "✅ تم جلب azkar.txt"

# تحميل السكربت الرئيسي
curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME" || {
    echo "❌ فشل جلب $SCRIPT_NAME"
    exit 1
}
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "✅ تم جلب $SCRIPT_NAME"

# تحميل ملف الآذان (اختياري)
curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$INSTALL_DIR/adhan.ogg" 2>/dev/null || {
    echo "⚠️ تعذر جلب ملف الآذان (اختياري)"
}

# --- إنشاء اختصار ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- إعداد التشغيل التلقائي (خدمة autostart) ---
add_autostart_service() {
    local autostart_dir="$HOME/.config/autostart"
    local service_file="$autostart_dir/gt-salat-dikr.desktop"
    mkdir -p "$autostart_dir"

    cat > "$service_file" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "cd '$INSTALL_DIR' && sleep 25 && './$SCRIPT_NAME' --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Automatic prayer times and azkar notifications
EOF
    echo "✅ تم إضافة خدمة التشغيل التلقائي"
}
add_autostart_service

# --- الإعدادات الأولية ---
echo "⚙️  بدء إعدادات التهيئة الأولى..."
cd "$INSTALL_DIR" && bash "$SCRIPT_NAME" --settings

# --- بدء الإشعارات فوراً ---
echo "🔔 بدء إشعارات التذكير التلقائية..."
cd "$INSTALL_DIR" && nohup bash -c "sleep 10 && ./'$SCRIPT_NAME' --notify-start" > notify.log 2>&1 &

echo ""
echo "🎉 تم التثبيت بنجاح!"
echo ""
echo "🔧 للتحكم في الإشعارات:"
echo "   gtsalat --notify-start    # بدء الإشعارات"
echo "   gtsalat --notify-stop     # إيقاف الإشعارات"
echo "   gtsalat --show-timetable  # عرض مواقيت الصلاة"
echo "   gtsalat --settings        # تغيير الإعدادات"
echo ""
echo "📋 السجلات: $INSTALL_DIR/notify.log"
echo "📁 مجلد التثبيت: $INSTALL_DIR"
