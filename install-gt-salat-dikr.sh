#!/bin/bash
# مثبت GT-salat-dikr (مُحدّث) — ينسخ adhan.ogg إن وُجد ويتيح تفعيل self-update في الإعداد
# مبني على المثبّت الذي زودتني به سابقًا. :contentReference[oaicite:3]{index=3}

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- إضافة ~/.local/bin إلى PATH إن لم تكن مضافة ---
add_to_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "إضافة ~/.local/bin إلى PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
        echo 'set -gx PATH "$HOME/.local/bin" $PATH' >> "$HOME/.config/fish/config.fish" 2>/dev/null || true
        export PATH="$HOME/.local/bin:$PATH"
        echo "تم إضافة ~/.local/bin إلى PATH"
    fi
}
add_to_path

# --- نسخ أو تنزيل azkar.txt ---
if [ -f "$AZKAR_FILE" ]; then
    cp "$AZKAR_FILE" "$INSTALL_DIR/$AZKAR_FILE"
    echo "تم نسخ azkar.txt محليًا."
elif curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "تم جلب azkar.txt من الإنترنت."
else
    echo "تعذر العثور على azkar.txt محليًا أو تحميله من الإنترنت."
    exit 2
fi

# --- نسخ أو تنزيل السكربت الرئيسي ---
if [ -f "$SCRIPT_NAME" ]; then
    cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    echo "تم نسخ $SCRIPT_NAME محليًا."
elif curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "تم جلب $SCRIPT_NAME من الإنترنت."
else
    echo "تعذر العثور على $SCRIPT_NAME محليًا أو تحميله من الإنترنت."
    exit 2
fi
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- إذا وُجد ملف adhan.ogg في نفس مجلد التثبيت، انسخه ---
if [ -f "adhan.ogg" ]; then
    cp "adhan.ogg" "$INSTALL_DIR/adhan.ogg"
    echo "تم نسخ ملف الآذان (adhan.ogg) إلى مجلد التثبيت."
else
    echo "لم يتم العثور على adhan.ogg محليًا. يمكنك وضع ملف adhan.ogg في $INSTALL_DIR لاحقًا."
fi

# --- إنشاء اختصار في ~/.local/bin/gtsalat ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- الكشف التلقائي عن نوع الطرفية وإضافة الإعدادات إلى rc files ---
detect_and_add_to_shell() {
    local shells_added=0
    local shell_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
        "$HOME/.bash_profile"
        "$HOME/.bash_login"
        "$HOME/.config/fish/config.fish"
    )
    for rc_file in "${shell_files[@]}"; do
        if [ -f "$rc_file" ]; then
            if ! grep -Fq "GT-salat-dikr" "$rc_file"; then
                echo "" >> "$rc_file"
                echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$rc_file"
                echo "bash \"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                echo "alias gtsalat=\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                echo "تم الإضافة إلى $rc_file"
                shells_added=$((shells_added + 1))
            fi
        fi
    done
    if [ $shells_added -eq 0 ] && [ ! -f "$HOME/.profile" ]; then
        touch "$HOME/.profile"
        echo "" >> "$HOME/.profile"
        echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$HOME/.profile"
        echo "bash \"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$HOME/.profile"
        echo "alias gtsalat=\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$HOME/.profile"
        echo "تم الإضافة إلى $HOME/.profile"
    fi
}

detect_and_add_to_shell

# --- إضافة خدمة تشغيل تلقائي (autostart) ---
add_autostart_service() {
    local autostart_dir="$HOME/.config/autostart"
    local service_file="$autostart_dir/gt-salat-dikr.desktop"
    mkdir -p "$autostart_dir"

    # نسأل المستخدم إن كان يريد التحديث الذاتي تلقائيًا عند بدء التشغيل
    read -p "هل تريد تمكين التحديث الذاتي للسكريبت عند بدء التشغيل؟ (سيُجرى فحص صغير للتحديث) [y/N]: " ans
    ans=${ans:-N}
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        AUTO_FLAG="--self-update && sleep 1 &&"
        echo "AUTO_SELF_UPDATE=1" >> "$INSTALL_DIR/settings.conf" 2>/dev/null || true
    else
        AUTO_FLAG=""
    fi

    cat > "$service_file" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Exec=bash -c "sleep 10 && $AUTO_FLAG $INSTALL_DIR/$SCRIPT_NAME --notify-start"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment[ar]=إشعارات تلقائية لمواقيت الصلاة والأذكار
Comment=Automatic prayer times and azkar notifications
EOF

    echo "تم إضافة خدمة التشغيل التلقائي عند بدء النظام ($service_file)"
}

add_autostart_service

# --- تشغيل معالج الإعدادات الأولية (مرّ واحد) ---
echo "بدء إعدادات التهيئة الأولى..."
"$INSTALL_DIR/$SCRIPT_NAME" --settings

# --- بدء الإشعارات التلقائية في الخلفية ---
echo "بدء إشعارات التذكير التلقائية..."
nohup bash -c "sleep 2 && $INSTALL_DIR/$SCRIPT_NAME --notify-start" >/dev/null 2>&1 &

echo ""
echo "✅ تم تثبيت GT-salat-dikr بنجاح في $INSTALL_DIR"
echo ""
echo "📋 اختصارات:"
echo "   gtsalat -> $LOCAL_BIN/gtsalat"
echo ""
echo "لإدارة الإشعارات: gtsalat --notify-stop و gtsalat --notify-start"
echo "لتحديث الأذكار: gtsalat --update-azkar"
echo "لتحديث السكربت من المستودع: gtsalat --self-update"
