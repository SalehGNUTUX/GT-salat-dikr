#!/bin/bash
# مثبت GT-salat-dikr - نسخة مُحدثة ومحسّنة

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
LOCAL_BIN="$HOME/.local/bin"

echo "🔄 تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOCAL_BIN"

# --- تحميل الملفات ---
echo "📥 جلب الملفات المطلوبة..."
curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"
curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"
curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$INSTALL_DIR/adhan.ogg" || true

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء اختصار ---
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- إضافة السكربت إلى ملفات الطرفية ---
add_to_shell_rc() {
    local rc="$1"
    local marker="# GT-salat-dikr: ذكر و صلاة"
    grep -F "$marker" "$rc" >/dev/null 2>&1 || cat >> "$rc" <<EOF

$marker
"$INSTALL_DIR/$SCRIPT_NAME"
"$LOCAL_BIN/gtsalat"
EOF
}
[ -f "$HOME/.bashrc" ] && add_to_shell_rc "$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && add_to_shell_rc "$HOME/.zshrc"

# --- إعداد التشغيل التلقائي ---
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
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

# --- الإعداد الأولي (مرة واحدة فقط) ---
if [ ! -f "$INSTALL_DIR/.initialized" ]; then
    echo "⚙️ بدء إعدادات التهيئة الأولى..."
    cd "$INSTALL_DIR" && bash "$SCRIPT_NAME" --settings
    touch "$INSTALL_DIR/.initialized"
fi

# --- بدء الإشعارات فوراً ---
echo "🔔 بدء إشعارات التذكير التلقائية..."
cd "$INSTALL_DIR" && nohup bash -c "./$SCRIPT_NAME --notify-start" > "$INSTALL_DIR/notify.log" 2>&1 &

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
