#!/bin/bash

set -e

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- إصلاح PATH لإضافة ~/.local/bin تلقائيًا ---
add_to_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "إضافة ~/.local/bin إلى PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        echo 'set -gx PATH "$HOME/.local/bin" $PATH' >> "$HOME/.config/fish/config.fish" 2>/dev/null || true
        export PATH="$HOME/.local/bin:$PATH"
        echo "تم إضافة ~/.local/bin إلى PATH"
    fi
}
add_to_path
# ----------------------------------------------------------------

# --- الحصول على ملف الأذكار من الريبو أو من نفس المجلد ---
if [ -f "$AZKAR_FILE" ]; then
    cp "$AZKAR_FILE" "$INSTALL_DIR/$AZKAR_FILE"
    echo "تم نسخ azkar.txt محليًا."
elif curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "تم جلب azkar.txt من الإنترنت."
else
    echo "تعذر العثور على azkar.txt محليًا أو تحميله من الإنترنت."
    exit 2
fi

# --- الحصول على السكربت الرئيسي من الريبو أو من نفس المجلد ---
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

# --- إنشاء اختصار في ~/.local/bin/gtsalat ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
chmod +x "$LOCAL_BIN/gtsalat"
echo "تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- الكشف التلقائي عن نوع الطرفية وإضافة الإعدادات ---
detect_and_add_to_shell() {
    local shells_added=0

    # قائمة بجميع ملفات الإعداد المحتملة
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

                # إضافة الأمر المناسب لنوع الطرفية
                if [[ "$rc_file" == *"fish"* ]]; then
                    echo "bash \"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                    echo "alias gtsalat=\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                else
                    echo "bash \"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                    echo "alias gtsalat=\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$rc_file"
                fi

                echo "تم الإضافة إلى $rc_file"
                shells_added=$((shells_added + 1))
            fi
        fi
    done

    # إذا لم يتم الإضافة إلى أي ملف، ننشئ ملف .profile افتراضي
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

# --- تشغيل معالج الإعدادات الأولية ---
echo "بدء إعدادات التهيئة الأولى..."
"$INSTALL_DIR/$SCRIPT_NAME" --settings

# --- بدء الإشعار التلقائي (افتراضي كل 5 دقائق) ---
echo "بدء إشعارات التذكير التلقائية..."
"$INSTALL_DIR/$SCRIPT_NAME" --notify-start

echo ""
echo "✅ تم تثبيت GT-salat-dikr بنجاح في $INSTALL_DIR"
echo ""
echo "📋 تم إضافة هذه الإعدادات إلى جميع ملفات الطرفية:"
echo "   # GT-salat-dikr: ذكر وصلاة عند فتح الطرفية"
echo "   bash \"$INSTALL_DIR/$SCRIPT_NAME\""
echo "   alias gtsalat=\"$INSTALL_DIR/$SCRIPT_NAME\""
echo ""
echo "🎯 الأوامر المتاحة:"
echo "   gtsalat                 - عرض ذكر وموعد الصلاة القادمة"
echo "   gtsalat --show-timetable - عرض مواقيت الصلاة كاملة"
echo "   gtsalat t               - اختصار لعرض مواقيت الصلاة"
echo "   gtsalat --settings      - تغيير الإعدادات"
echo "   gtsalat --notify-stop   - إيقاف الإشعارات التلقائية"
echo "   gtsalat --notify-start  - بدء الإشعارات التلقائية"
echo "   gtsalat --update-azkar  - تحديث الأذكار من الإنترنت"
echo ""
echo "🌍 يدعم جميع أنواع الطرفيات: bash, zsh, fish وغيرها"
echo ""
echo "للتأكد من العمل، جرب:"
echo "  gtsalat --show-timetable"
