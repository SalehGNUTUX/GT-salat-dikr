#!/bin/bash
# سكربت إلغاء تثبيت GT-salat-dikr

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
LOCAL_BIN="$HOME/.local/bin/gtsalat"
AUTOSTART_FILE="$HOME/.config/autostart/gt-salat-dikr.desktop"

echo "🗑️ بدء عملية إزالة GT-salat-dikr..."

# إزالة مجلد التثبيت
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "✅ تم حذف مجلد التثبيت: $INSTALL_DIR"
else
    echo "ℹ️ لم يتم العثور على مجلد التثبيت."
fi

# إزالة الاختصار من ~/.local/bin
if [ -L "$LOCAL_BIN" ] || [ -f "$LOCAL_BIN" ]; then
    rm -f "$LOCAL_BIN"
    echo "✅ تم حذف الاختصار: $LOCAL_BIN"
else
    echo "ℹ️ لم يتم العثور على الاختصار في ~/.local/bin"
fi

# إزالة خدمة autostart
if [ -f "$AUTOSTART_FILE" ]; then
    rm -f "$AUTOSTART_FILE"
    echo "✅ تم حذف ملف autostart: $AUTOSTART_FILE"
else
    echo "ℹ️ لم يتم العثور على ملف autostart"
fi

# إزالة السجلات إن وُجدت
if [ -f "$HOME/notify.log" ]; then
    rm -f "$HOME/notify.log"
    echo "✅ تم حذف ملف السجل: $HOME/notify.log"
fi

echo ""
echo "🎉 تم إلغاء تثبيت GT-salat-dikr بالكامل."
echo "يمكنك إعادة تثبيته الآن من جديد لتجربة نظيفة."
