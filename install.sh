#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.GT-salat-dikr"
APP_NAME="gtsalat"
SCRIPT_NAME="gt-salat-dikr.sh"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"

echo "🔹 تثبيت $APP_NAME ..."

# إنشاء مجلدات أساسية
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$DESKTOP_FILE")"

# نسخ الملف التنفيذي
if [[ -f "$SCRIPT_NAME" ]]; then
    cp "$SCRIPT_NAME" "$INSTALL_DIR/$APP_NAME"
    chmod +x "$INSTALL_DIR/$APP_NAME"
    echo "✅ تم نسخ الملف التنفيذي إلى $INSTALL_DIR/$APP_NAME"
else
    echo "❌ لم أجد الملف $SCRIPT_NAME"
    exit 1
fi

# نسخ ملف الأذان إن وُجد
if [[ -f "adhan.ogg" ]]; then
    cp "adhan.ogg" "$CONFIG_DIR/"
    echo "✅ تم نسخ adhan.ogg إلى $CONFIG_DIR/"
else
    echo "⚠️ لم أجد ملف adhan.ogg، سيُستخدم المسار الافتراضي إن كان في السكربت"
fi

# إنشاء ملف desktop launcher
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=GT Salat Dikr
Exec=$INSTALL_DIR/$APP_NAME
Icon=utilities-terminal
Type=Application
Categories=Utility;
Terminal=true
EOF

echo "✅ تم إنشاء ملف التشغيل في القائمة: $DESKTOP_FILE"

echo "🎉 تم التثبيت بنجاح!"
