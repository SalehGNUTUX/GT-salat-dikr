#!/bin/bash
# مثبت GT-salat-dikr - نسخة مُصلحة للإشعارات والطرفيات
# Author: gnutux (معدل)

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
LOCAL_BIN="$HOME/.local/bin"

echo "🔄 تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOCAL_BIN"

# --- إضافة ~/.local/bin إلى PATH ---
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
    export PATH="$LOCAL_BIN:$PATH"
    echo "✅ تم إضافة ~/.local/bin إلى PATH"
fi

# --- تحميل الملفات ---
echo "📥 جلب الملفات المطلوبة..."

curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE" && echo "✅ تم جلب azkar.txt"
curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME" && echo "✅ تم جلب $SCRIPT_NAME"
curl -fsSL "$REPO_RAW_URL/adhan.ogg" -o "$INSTALL_DIR/adhan.ogg" || echo "⚠️ تعذر جلب ملف الآذان (اختياري)"

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء اختصار ---
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- تضمين السكربت في الطرفيات ---
add_to_shellrc() {
    local line="# GT-salat-dikr: ذكر و صلاة"
    local script_path="$INSTALL_DIR/$SCRIPT_NAME"
    local link_path="$LOCAL_BIN/gtsalat"

    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        [[ -f "$rc" ]] || continue
        if ! grep -Fxq "$line" "$rc"; then
            echo "" >> "$rc"
            echo "$line" >> "$rc"
            echo "$script_path" >> "$rc"
            echo "$link_path" >> "$rc"
        fi
    done
    echo "✅ تم تضمين GT-salat-dikr في ملفات الطرفية"
}
add_to_shellrc

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

# --- إعداد التهيئة الأولى ---
cd "$INSTALL_DIR" && bash "$SCRIPT_NAME" --settings

# --- بدء الإشعارات فوراً ---
nohup bash -c "cd '$INSTALL_DIR' && sleep 10 && './$SCRIPT_NAME' --notify-start" > "$INSTALL_DIR/notify.log" 2>&1 &

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
