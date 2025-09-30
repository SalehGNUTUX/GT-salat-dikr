#!/bin/bash
# مثبت GT-salat-dikr - نسخة مُصلحة للإشعارات وتهيئة الطرفية

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
curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE" && echo "✅ تم جلب azkar.txt"
curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME" && echo "✅ تم جلب $SCRIPT_NAME"
curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$INSTALL_DIR/adhan.ogg" 2>/dev/null && echo "✅ تم جلب ملف الآذان (اختياري)"

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء اختصار ---
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- إضافة ~/.local/bin إلى PATH إذا لم يكن موجود ---
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
done

# --- إضافة سطر تشغيل GT-salat-dikr تلقائيًا عند فتح الطرفية ---
add_to_shell_rc() {
    local rc="$1"
    local marker="# GT-salat-dikr: ذكر و صلاة"
    grep -F "$marker" "$rc" >/dev/null 2>&1 || cat >> "$rc" <<EOF

$marker
"$INSTALL_DIR/$SCRIPT_NAME"
"$LOCAL_BIN/gtsalat"
EOF
}

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && add_to_shell_rc "$rc"
done

# --- إعداد التشغيل التلقائي (autostart) ---
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

# --- إعدادات أولية فقط إذا لم توجد ---
if [ ! -f "$INSTALL_DIR/settings.conf" ]; then
    echo "⚙️ بدء إعدادات التهيئة الأولى..."
    bash "$INSTALL_DIR/$SCRIPT_NAME" --settings
fi

# --- بدء الإشعارات فوراً ---
echo "🔔 بدء إشعارات التذكير التلقائية..."
nohup bash -c "cd '$INSTALL_DIR' && sleep 10 && ./'$SCRIPT_NAME' --notify-start" > "$INSTALL_DIR/notify.log" 2>&1 &

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
