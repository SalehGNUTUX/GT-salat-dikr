#!/bin/bash
# مُثبّت GT-salat-dikr الذكي — 2025-10-05
# إعداد تلقائي للطرفية، autostart، وsystemd
set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"
SERVICE_FILE="$HOME/.config/systemd/user/gt-salat-dikr.service"
AUTOSTART_FILE="$HOME/.config/autostart/gt-salat-dikr.desktop"

echo "🕌 مثبت GT-salat-dikr — إعداد الذكر والصلاة"

# إنشاء مجلد التثبيت
mkdir -p "$INSTALL_DIR"
cp -f ./gt-salat-dikr.sh "$SCRIPT"
chmod +x "$SCRIPT"

# ===== [ إصلاح السطر 1013 إذا وجد ] =====
if grep -q '"\$PRAYER_NAME""\$PRAYER_TIME"' "$SCRIPT"; then
    sed -i 's/"$PRAYER_NAME""$PRAYER_TIME"/"$PRAYER_NAME" "$PRAYER_TIME"/' "$SCRIPT"
fi

# ===== [ فحص الكود ] =====
bash -n "$SCRIPT" && echo "✅ لا توجد أخطاء نحوية."

# ===== [ إعداد ملفات الطرفية ] =====
for rc in ~/.bashrc ~/.zshrc; do
    if [ -f "$rc" ] && ! grep -q "GT-salat-dikr" "$rc"; then
        echo "🌀 إضافة إعداد التشغيل إلى $rc"
        cat >> "$rc" << 'EOF'

# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية
"$HOME/.GT-salat-dikr/gt-salat-dikr.sh"
EOF
    fi
done

# ===== [ واجهة الاختيار التفاعلي ] =====
echo
echo "اختر طريقة التشغيل التلقائي:"
echo "1) systemd (موصى بها)"
echo "2) autostart (لكافة البيئات)"
echo "3) كليهما"
echo "4) لا شيء"
read -rp "➡️ أدخل رقم الخيار [1-4]: " choice

enable_systemd=false
enable_autostart=false

case "$choice" in
    1) enable_systemd=true ;;
    2) enable_autostart=true ;;
    3) enable_systemd=true; enable_autostart=true ;;
    *) echo "❌ لن يتم إنشاء تشغيل تلقائي." ;;
esac

# ===== [ إعداد systemd ] =====
if $enable_systemd; then
    mkdir -p "$(dirname "$SERVICE_FILE")"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=GT-salat-dikr Notifications
After=graphical-session.target

[Service]
Type=simple
ExecStart=$SCRIPT --child-notify
Restart=on-failure
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus"
Environment="DISPLAY=:0"

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now gt-salat-dikr.service
    echo "✅ تم تفعيل خدمة systemd للمستخدم."
fi

# ===== [ إعداد autostart ] =====
if $enable_autostart; then
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 20 && $SCRIPT --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
StartupNotify=false
Terminal=false
EOF
    echo "✅ تم إنشاء ملف autostart."
fi

echo
echo "🎉 تم تثبيت GT-salat-dikr بنجاح!"
echo "📍 مجلد التثبيت: $INSTALL_DIR"
echo "💡 يمكنك تجربة التشغيل الآن بالأمر:"
echo "   $SCRIPT"
echo
echo "لإلغاء التثبيت:"
echo "   $SCRIPT --uninstall"
