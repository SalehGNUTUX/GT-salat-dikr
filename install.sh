#!/bin/bash

set -e

INSTALL_DIR="$HOME/.GT-salat-dikr"
SCRIPT_NAME="gt-salat-dikr.sh"
AZKAR_FILE="azkar.txt"
ADHAN_FILE="adhan.ogg"
REPO_RAW_URL="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"

echo "🕌 تثبيت GT-salat-dikr في $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# --- الحصول على ملف الأذكار من الريبو ---
echo "📥 جلب ملف الأذكار..."
if curl -fsSL "$REPO_RAW_URL/$AZKAR_FILE" -o "$INSTALL_DIR/$AZKAR_FILE"; then
    echo "✅ تم جلب azkar.txt من الإنترنت."
else
    echo "❌ تعذر تحميل ملف الأذكار من الإنترنت."
    exit 2
fi

# --- الحصول على ملف الأذان ---
echo "📥 جلب ملف الأذان..."
if curl -fsSL "$REPO_RAW_URL/$ADHAN_FILE" -o "$INSTALL_DIR/$ADHAN_FILE"; then
    echo "✅ تم جلب adhan.ogg من الإنترنت."
else
    echo "⚠️ تعذر تحميل ملف الأذان، سيتم استخدام الإشعارات النصية فقط."
fi

# --- الحصول على السكربت الرئيسي ---
echo "📥 جلب السكربت الرئيسي..."
if curl -fsSL "$REPO_RAW_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "✅ تم جلب $SCRIPT_NAME من الإنترنت."
else
    echo "❌ تعذر تحميل السكربت الرئيسي من الإنترنت."
    exit 2
fi
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# --- تشغيل معالج الإعدادات الأولية ---
echo "⚙️  تشغيل معالج الإعدادات..."
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
            echo "✅ تم الإضافة إلى $RC_FILE"
        else
            echo "ℹ️ السكربت مضاف مسبقًا إلى $RC_FILE"
        fi
    fi
}

echo "🔗 إضافة إلى ملفات shell..."
add_to_shell_rc "$HOME/.bashrc"
add_to_shell_rc "$HOME/.zshrc"

# --- إنشاء اختصار في ~/.local/bin/gtsalat ---
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$LOCAL_BIN/gtsalat"
echo "✅ تم إنشاء اختصار gtsalat في $LOCAL_BIN/"

# --- فحص PATH ---
if ! echo "$PATH" | grep -q "$LOCAL_BIN" ; then
    echo ""
    echo "⚠️  تنبيه: مجلد $LOCAL_BIN ليس في متغير PATH لديك."
    echo "أضف السطر التالي إلى ملف .bashrc أو .zshrc ثم أعد تحميل الطرفية:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- بدء الإشعار التلقائي ---
echo "🔔 بدء الإشعارات التلقائية..."
if "$INSTALL_DIR/$SCRIPT_NAME" --notify-start; then
    echo "✅ تم بدء الإشعارات التلقائية."
else
    echo "⚠️  تعذر بدء الإشعارات التلقائية، يمكنك بدؤها يدويًا لاحقًا."
fi

# --- إنشاء ملفات autostart ---
echo "🚀 إنشاء ملفات التشغيل التلقائي..."
"$INSTALL_DIR/$SCRIPT_NAME" --install > /dev/null 2>&1 || true

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  🎉 تم تثبيت GT-salat-dikr بنجاح!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📍 الموقع: $INSTALL_DIR"
echo "🔗 الاختصار: gtsalat"
echo ""
echo "💡 أوامر سريعة:"
echo "   gtsalat                    - عرض ذكر وصلاة التالية"
echo "   gtsalat --show-timetable   - عرض مواقيت الصلاة"
echo "   gtsalat --notify-stop      - إيقاف الإشعارات"
echo "   gtsalat --settings         - تغيير الإعدادات"
echo "   gtsalat --help             - عرض جميع الخيارات"
echo ""

if [ "$added" = true ]; then
    echo "✅ تمت الإضافة التلقائية - سيظهر لك ذكر وصلاة عند كل فتح للطرفية."
else
    echo "ℹ️  لإظهار الذكر والصلاة تلقائيًا، أضف هذا السطر لملف shell:"
    echo "   \"$INSTALL_DIR/$SCRIPT_NAME\""
fi

echo ""
echo "📝 ملاحظة: الإشعارات تعمل تلقائيًا في الخلفية وسيتم تشغيلها عند بدء النظام."
echo ""
