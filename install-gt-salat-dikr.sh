#!/bin/bash

set -e

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- إصلاح PATH لإضافة ~/.local/bin تلقائيًا إن لم يكن موجود ---
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;; # موجود بالفعل
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# ----------------------------------------------------------------

# --- الحصول على ملف الأذكار من الريبو أو من نفس المجلد ---
if [ -f "$AZKAR_FILE" ]; then
    cp "$AZKAR_FILE" "$INSTALL_DIR/$AZKAR_FILE"
elif curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "تم جلب azkar.txt من الإنترنت."
else
    echo "تعذر العثور على azkar.txt محليًا أو تحميله من الإنترنت."
    exit 2
fi

# --- الحصول على السكربت الرئيسي من الريبو أو من نفس المجلد ---
if [ -f "$SCRIPT_NAME" ]; then
    cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
elif curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "تم جلب $SCRIPT_NAME من الإنترنت."
else
    echo "تعذر العثور على $SCRIPT_NAME محليًا أو تحميله من الإنترنت."
    exit 2
fi
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- تشغيل معالج الإعدادات الأولية ---
"$INSTALL_DIR/$SCRIPT_NAME" --settings

# --- إضافة إلى bashrc أو zshrc ---
added=false
add_to_shell_rc() {
    RC_FILE="$1"
    if [ -f "$RC_FILE" ]; then
        if ! grep -Fq "$INSTALL_DIR/$SCRIPT_NAME" "$RC_FILE"; then
            echo "" >> "$RC_FILE"
            echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$RC_FILE"
            echo "\"$INSTALL_DIR/$SCRIPT_NAME\"" >> "$RC_FILE"
            added=true
        fi
    fi
}
add_to_shell_rc "$HOME/.bashrc"
add_to_shell_rc "$HOME/.zshrc"

# --- إنشاء اختصار في ~/.local/bin/gtsalat ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"

# --- فحص PATH ---
if ! echo "$PATH" | grep -q "$LOCAL_BIN" ; then
    echo ""
    echo "تنبيه: مجلد $LOCAL_BIN ليس في متغير PATH لديك."
    echo "أضف السطر التالي إلى ملف .bashrc أو .zshrc ثم أعد تحميل الطرفية:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- بدء الإشعار التلقائي (افتراضي كل 5 دقائق) ---
"$INSTALL_DIR/$SCRIPT_NAME" --notify-start

echo ""
echo "تم تثبيت GT-salat-dikr في $INSTALL_DIR"
echo "تم إنشاء اختصار gtsalat ويمكنك تشغيل البرنامج مباشرة بهذا الأمر:"
echo "  gtsalat"
echo ""
echo "لعرض مواقيت الصلاة:   gtsalat --show-timetable"
echo "لإيقاف الإشعار:      gtsalat --notify-stop"
echo "لتغيير الإعدادات:    gtsalat --settings"
if [ "$added" = true ]; then
    echo ""
    echo "تمت إضافة السطر للـ bashrc أو zshrc وسيظهر لك ذكر وصلاة عند كل مرة تفتح فيها الطرفية."
else
    echo "أضف يدويًا السطر التالي لملف إعدادات الطرفية:"
    echo "\"$INSTALL_DIR/$SCRIPT_NAME\""
fi
