#!/bin/bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.GT-salat-dikr"
APP_NAME="gtsalat"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"

echo "🗑️ إلغاء تثبيت $APP_NAME ..."

# إزالة الملف التنفيذي
rm -f "$INSTALL_DIR/$APP_NAME"

# إزالة الإعدادات
rm -rf "$CONFIG_DIR"

# إزالة ملف desktop launcher
rm -f "$DESKTOP_FILE"

echo "✅ تم الإلغاء بنجاح."
