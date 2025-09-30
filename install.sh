#!/bin/bash
# المثبت المبسط لـ GT-salat-dikr
# Author: gnutux

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
ADHAN_FILE="adhan.ogg"
LOCAL_BIN="$HOME/.local/bin"
REPO_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "🔄 تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- تحميل الملفات ---
echo "📥 جلب الملفات المطلوبة..."
curl -fsSL "$REPO_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"
curl -fsSL "$REPO_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"
curl -fsSL "$REPO_URL/$ADHAN_FILE" -o "$INSTALL_DIR/$ADHAN_FILE" || echo "⚠️ لم يتم جلب ملف الآذان (اختياري)"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إنشاء الرابط الرمزي ---
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء الرابط الرمزي gtsalat في $LOCAL_BIN/"

# --- إنشاء autostart ---
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 30 && $INSTALL_DIR/$SCRIPT_NAME --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Automatic prayer times and azkar notifications
EOF
echo "✅ تم إنشاء خدمة autostart"

echo ""
echo "🎉 تم التثبيت بنجاح!"
echo "🔧 يمكنك الآن تشغيل الإشعارات: gtsalat --notify-start"
echo "ℹ️ لإيقاف الإشعارات: gtsalat --notify-stop"
echo "📋 السجلات: $INSTALL_DIR/notify.log"
echo "📁 مجلد التثبيت: $INSTALL_DIR"
