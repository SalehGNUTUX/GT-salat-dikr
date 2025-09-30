#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.GT-salat-dikr"
APP_NAME="gtsalat"
SCRIPT_NAME="gt-salat-dikr.sh"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "🔹 تثبيت $APP_NAME ..."

# إنشاء المجلدات
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$(dirname "$DESKTOP_FILE")"

# التحقق من وجود الملف محليًا أو تحميله من GitHub
if [[ -f "./$SCRIPT_NAME" ]]; then
    echo "📂 وُجد $SCRIPT_NAME محليًا — سيتم استخدامه"
    cp "./$SCRIPT_NAME" "$INSTALL_DIR/$APP_NAME"
else
    echo "⬇️ لم أجد $SCRIPT_NAME محليًا — تنزيل من GitHub..."
    curl -fsSL "$REPO_BASE/$SCRIPT_NAME" -o "$INSTALL_DIR/$APP_NAME"
fi

chmod +x "$INSTALL_DIR/$APP_NAME"
echo "✅ تم تثبيت الملف التنفيذي: $INSTALL_DIR/$APP_NAME"

# تنزيل ملف الأذان إن وُجد
if curl --output /dev/null --silent --head --fail "$REPO_BASE/adhan.ogg"; then
    curl -fsSL "$REPO_BASE/adhan.ogg" -o "$CONFIG_DIR/adhan.ogg"
    echo "✅ تم تنزيل adhan.ogg إلى $CONFIG_DIR/"
else
    echo "⚠️ لم يتم العثور على adhan.ogg في المستودع"
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

echo "✅ تم إنشاء ملف التشغيل: $DESKTOP_FILE"
echo "🎉 التثبيت اكتمل بنجاح!"
