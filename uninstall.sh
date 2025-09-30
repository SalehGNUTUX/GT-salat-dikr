[file name]: uninstall.sh
[file content begin]
#!/bin/bash
# سكربت إلغاء تثبيت GT-salat-dikr - متوافق مع النسخة المحسنة

set -euo pipefail

INSTALL_DIR="$HOME/.GT-salat-dikr"
LOCAL_BIN="$HOME/.local/bin/gtsalat"
AUTOSTART_FILE="$HOME/.config/autostart/gt-salat-dikr.desktop"
SYSTEMD_USER_SERVICE="$HOME/.config/systemd/user/gt-salat-dikr.service"

echo "╔══════════════════════════════════════════════╗"
echo "║         إلغاء تثبيت GT-salat-dikr           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# التحقق من وجود التثبيت
if [ ! -d "$INSTALL_DIR" ] && [ ! -f "$LOCAL_BIN" ] && [ ! -f "$AUTOSTART_FILE" ]; then
    echo "ℹ️  لم يتم العثور على أي تثبيت لـ GT-salat-dikr"
    exit 0
fi

# طلب التأكيد
echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل من نظامك."
read -p "هل أنت متأكد من المتابعة؟ [y/N]: " confirm
confirm=${confirm:-N}

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ تم إلغاء عملية الإزالة."
    exit 0
fi

echo ""
echo "🔄 بدء عملية الإزالة..."

# --- إيقاف الإشعارات أولاً ---
stop_notifications() {
    echo "⏹️  إيقاف الإشعارات النشطة..."
    
    # الطريقة 1: استخدام السكربت نفسه إذا كان متاحاً
    if [ -f "$INSTALL_DIR/gt-salat-dikr.sh" ]; then
        cd "$INSTALL_DIR" && bash "gt-salat-dikr.sh" --notify-stop >/dev/null 2>&1 || true
    fi
    
    # الطريقة 2: إيقاف عبر PID مباشرة
    local pid_file="$INSTALL_DIR/.gt-salat-dikr-notify.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            echo "✅ تم إيقاف عملية الإشعارات (PID: $pid)"
        fi
        rm -f "$pid_file" 2>/dev/null || true
    fi
    
    # إيقاف أي عمليات متبقية
    pkill -f "gt-salat-dikr" 2>/dev/null || true
    pkill -f "adhan-player" 2>/dev/null || true
}
stop_notifications

# --- إزالة خدمات systemd ---
remove_systemd_services() {
    if command -v systemctl >/dev/null 2>&1; then
        if [ -f "$SYSTEMD_USER_SERVICE" ]; then
            systemctl --user stop gt-salat-dikr.service 2>/dev/null || true
            systemctl --user disable gt-salat-dikr.service 2>/dev/null || true
            rm -f "$SYSTEMD_USER_SERVICE"
            echo "✅ تم إزالة خدمة systemd"
        fi
        systemctl --user daemon-reload 2>/dev/null || true
    fi
}
remove_systemd_services

# --- إزالة الملفات والمجلدات ---
remove_files() {
    echo "🗑️  حذف الملفات والمجلدات..."
    
    # مجلد التثبيت الرئيسي
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "✅ تم حذف مجلد التثبيت: $INSTALL_DIR"
    else
        echo "ℹ️  لم يتم العثور على مجلد التثبيت الرئيسي"
    fi
    
    # الاختصار من ~/.local/bin
    if [ -L "$LOCAL_BIN" ] || [ -f "$LOCAL_BIN" ]; then
        rm -f "$LOCAL_BIN"
        echo "✅ تم حذف الاختصار: $LOCAL_BIN"
    else
        echo "ℹ️  لم يتم العثور على الاختصار في ~/.local/bin"
    fi
    
    # خدمة autostart
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        echo "✅ تم حذف ملف autostart: $AUTOSTART_FILE"
    else
        echo "ℹ️  لم يتم العثور على ملف autostart"
    fi
    
    # ملفات سجلات قديمة
    local old_logs=(
        "$HOME/notify.log"
        "/tmp/gt-adhan-player*"
        "/tmp/gt-salat-dikr*"
    )
    
    for log_file in "${old_logs[@]}"; do
        if [ -e "$log_file" ]; then
            rm -f $log_file 2>/dev/null || true
        fi
    done
    echo "✅ تم تنظيف ملفات السجلات المؤقتة"
}
remove_files

# --- إزالة من ملفات التهيئة ---
cleanup_shell_files() {
    echo "🧹 تنظيف ملفات التهيئة..."
    
    # إزالة من .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if grep -q "GT-salat-dikr" "$HOME/.bashrc"; then
            sed -i '/GT-salat-dikr/d' "$HOME/.bashrc" 2>/dev/null || true
            echo "✅ تم تنظيف .bashrc"
        fi
    fi
    
    # إزالة من .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        if grep -q "GT-salat-dikr" "$HOME/.zshrc"; then
            sed -i '/GT-salat-dikr/d' "$HOME/.zshrc" 2>/dev/null || true
            echo "✅ تم تنظيف .zshrc"
        fi
    fi
    
    # إزالة من i3 config
    local i3_config="$HOME/.config/i3/config"
    if [ -f "$i3_config" ]; then
        if grep -q "GT-salat-dikr" "$i3_config"; then
            sed -i '/GT-salat-dikr/d' "$i3_config" 2>/dev/null || true
            echo "✅ تم تنظيف i3 config"
        fi
    fi
    
    # إزالة من Openbox autostart
    local openbox_auto="$HOME/.config/openbox/autostart"
    if [ -f "$openbox_auto" ]; then
        if grep -q "GT-salat-dikr" "$openbox_auto"; then
            sed -i '/GT-salat-dikr/d' "$openbox_auto" 2>/dev/null || true
            echo "✅ تم تنظيف Openbox autostart"
        fi
    fi
}
cleanup_shell_files

# --- التحقق النهائي ---
final_check() {
    echo ""
    echo "🔍 التحقق النهائي..."
    
    local remaining_files=()
    
    [ -d "$INSTALL_DIR" ] && remaining_files+=("$INSTALL_DIR")
    [ -f "$LOCAL_BIN" ] && remaining_files+=("$LOCAL_BIN")
    [ -f "$AUTOSTART_FILE" ] && remaining_files+=("$AUTOSTART_FILE")
    [ -f "$SYSTEMD_USER_SERVICE" ] && remaining_files+=("$SYSTEMD_USER_SERVICE")
    
    if [ ${#remaining_files[@]} -eq 0 ]; then
        echo "✅ تم إزالة جميع الملفات بنجاح"
        return 0
    else
        echo "⚠️  بعض الملفات لا تزال موجودة:"
        for file in "${remaining_files[@]}"; do
            echo "   - $file"
        done
        echo "💡 يمكنك حذفها يدوياً إذا لزم الأمر"
        return 1
    fi
}
final_check

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║      تم الإلغاء بنجاح! 🎉                  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📝 ملخص الإزالة:"
echo "   ✅ تم إيقاف جميع عمليات البرنامج"
echo "   ✅ تم حذف ملفات التثبيت"
echo "   ✅ تم تنظيف ملفات التهيئة"
echo "   ✅ تم إزالة خدمات التشغيل التلقائي"
echo ""
echo "🔧 لاحظ أن:"
echo "   - إعداداتك الشخصية تم حذفها"
echo "   - سجلات الاستخدام تم حذفها"
echo "   - يمكنك إعادة التثبيت في أي وقت"
echo ""
echo "🌐 للمزيد من المعلومات: https://github.com/SalehGNUTUX/GT-salat-dikr"
echo ""
[file content end]
