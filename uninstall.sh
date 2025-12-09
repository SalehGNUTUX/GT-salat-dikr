#!/bin/bash
#
# GT-salat-dikr Complete Uninstall Script - v3.2.2-full
# إزالة كاملة للبرنامج وكل مكوناته
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  إزالة GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# منع التشغيل بصلاحيات root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root، استخدم حساب المستخدم العادي."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
LOG_FILE="$INSTALL_DIR/uninstall.log"

# دالة التسجيل
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# بدء عملية الإزالة
log "بدأت عملية الإزالة"

# ---------- المرحلة 1: التحقق والتأكيد ----------
echo ""
echo "⚠️  تحذير: هذه العملية ستحذف:"
echo "════════════════════════════════════════════════════════"
echo "• مجلد البرنامج: $INSTALL_DIR"
echo "• إعدادات المستخدم والملفات المحفوظة"
echo "• خدمات التشغيل التلقائي"
echo "• أيقونة System Tray"
echo "• إعدادات الطرفية (bashrc, zshrc)"
echo "════════════════════════════════════════════════════════"

read -p "هل أنت متأكد من الإزالة الكاملة؟ [y/N]: " CONFIRM
CONFIRM=${CONFIRM:-N}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "✅ تم إلغاء عملية الإزالة"
    exit 0
fi

echo ""
read -p "هل تريد حفظ نسخة احتياطية من الإعدادات؟ [Y/n]: " BACKUP
BACKUP=${BACKUP:-Y}

# إنشاء نسخة احتياطية إذا طلب المستخدم
if [[ "$BACKUP" =~ ^[Yy]$ ]]; then
    BACKUP_DIR="$HOME/gt-salat-dikr-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    log "إنشاء نسخة احتياطية في: $BACKUP_DIR"
    
    # نسخ الملفات المهمة
    if [ -d "$INSTALL_DIR" ]; then
        cp -r "$INSTALL_DIR/settings.conf" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "$INSTALL_DIR/monthly_timetables" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "$INSTALL_DIR/azkar.txt" "$BACKUP_DIR/" 2>/dev/null || true
        
        echo "✅ تم إنشاء نسخة احتياطية في: $BACKUP_DIR"
        echo "📁 الملفات المحفوظة:"
        ls -la "$BACKUP_DIR/" 2>/dev/null | grep -v "^total"
    else
        echo "⚠️  مجلد التثبيت غير موجود، لا توجد بيانات للنسخ الاحتياطي"
    fi
fi

# ---------- المرحلة 2: إيقاف جميع الخدمات والعمليات ----------
echo ""
echo "🛑 إيقاف جميع الخدمات والعمليات..."
log "إيقاف الخدمات والعمليات"

# إيقاف خدمات systemd
if command -v systemctl >/dev/null 2>&1; then
    echo "🔧 إيقاف خدمات systemd..."
    
    SERVICES=(
        "gt-salat-dikr-autostart.service"
        "gt-salat-dikr.service"
        "gt-salat-tray.service"
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl --user is-active "$service" >/dev/null 2>&1; then
            log "إيقاف خدمة: $service"
            systemctl --user stop "$service" 2>/dev/null || true
            systemctl --user disable "$service" 2>/dev/null || true
            echo "  ✅ تم إيقاف: $service"
        fi
    done
    
    # إزالة ملفات الخدمات
    rm -f "$HOME/.config/systemd/user/gt-salat-*.service" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
fi

# إيقاف عمليات sysvinit/autostart
echo "🔧 إيقاف عمليات التشغيل التلقائي..."

# قتل جميع عمليات GT-salat-dikr
PIDS=$(pgrep -f "gt-salat-dikr\|gt-tray.py\|autostart-manager" 2>/dev/null || true)

if [ -n "$PIDS" ]; then
    log "قائمة عمليات للقتل: $PIDS"
    for pid in $PIDS; do
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            echo "  ✅ تم إيقاف العملية: $pid"
        fi
    done
fi

# تأخير للتأكد من توقف العمليات
sleep 3

# ---------- المرحلة 3: إزالة ملفات التشغيل التلقائي ----------
echo ""
echo "🗑️  إزالة ملفات التشغيل التلقائي..."

# إزالة ملفات desktop autostart
DESKTOP_FILES=(
    "$HOME/.config/autostart/gt-salat-dikr.desktop"
    "$HOME/.config/autostart/gt-salat-tray.desktop"
    "$HOME/.config/autostart/gt-salat-dikr-autostart.desktop"
    "$HOME/.config/autostart/gt-salat-dikr-full.desktop"
)

for file in "${DESKTOP_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        log "إزالة ملف autostart: $file"
        echo "  ✅ تم إزالة: $(basename "$file")"
    fi
done

# إزالة إعدادات Plasma (KDE)
if [ -d "$HOME/.config/plasma-workspace/env" ]; then
    rm -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" 2>/dev/null || true
    echo "  ✅ تم إزالة إعدادات KDE Plasma"
fi

# ---------- المرحلة 4: إزالة إعدادات الطرفية ----------
echo ""
echo "🔧 تنظيف إعدادات الطرفية..."

clean_shell_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        # إنشاء نسخة احتياطية قبل التعديل
        cp "$shell_file" "${shell_file}.bak-before-uninstall" 2>/dev/null || true
        
        # إزالة كتل GT-salat-dikr
        sed -i '/# GT-salat-dikr - تذكير الصلاة والأذكار/,/fi/d' "$shell_file" 2>/dev/null || true
        sed -i '/alias gtsalat/d' "$shell_file" 2>/dev/null || true
        sed -i '/gt-salat-dikr/d' "$shell_file" 2>/dev/null || true
        sed -i '/GT-salat-dikr/d' "$shell_file" 2>/dev/null || true
        sed -i '/~\/.local\/bin\/gtsalat/d' "$shell_file" 2>/dev/null || true
        
        # إزالة الأسطر الفارغة الزائدة
        sed -i '/^$/N;/^\n$/D' "$shell_file" 2>/dev/null || true
        
        log "تنظيف ملف: $shell_file"
        echo "  ✅ تم تنظيف: $shell_name"
    fi
}

# تنظيف ملفات shell المختلفة
clean_shell_config "$HOME/.bashrc" "Bash"
clean_shell_config "$HOME/.bash_profile" "Bash Profile"
clean_shell_config "$HOME/.zshrc" "Zsh"

# إزالة الرابط من PATH
if [ -L "$HOME/.local/bin/gtsalat" ]; then
    rm -f "$HOME/.local/bin/gtsalat"
    echo "  ✅ تم إزالة الرابط من PATH"
fi

# إزالة مجلد .local/bin إذا كان فارغاً
if [ -d "$HOME/.local/bin" ] && [ -z "$(ls -A "$HOME/.local/bin" 2>/dev/null)" ]; then
    rmdir "$HOME/.local/bin" 2>/dev/null || true
fi

# ---------- المرحلة 5: إزالة مجلد التثبيت ----------
echo ""
echo "🗑️  إزالة مجلد التثبيت..."

if [ -d "$INSTALL_DIR" ]; then
    # عرض محتويات المجلد قبل الحذف
    echo "📁 محتويات المجلد الذي سيتم حذفه:"
    ls -la "$INSTALL_DIR/" 2>/dev/null || echo "  (فارغ أو غير قابل للقراءة)"
    
    read -p "هل تريد حذف مجلد التثبيت بالكامل؟ [Y/n]: " DELETE_DIR
    DELETE_DIR=${DELETE_DIR:-Y}
    
    if [[ "$DELETE_DIR" =~ ^[Yy]$ ]]; then
        # محاولة حذف المجلد
        if rm -rf "$INSTALL_DIR"; then
            log "حذف مجلد التثبيت: $INSTALL_DIR"
            echo "✅ تم حذف مجلد التثبيت"
        else
            # محاولة حذف محتويات المجلد
            echo "⚠️  تعذر حذف المجلد، جاري حذف المحتويات..."
            rm -rf "${INSTALL_DIR:?}/"* 2>/dev/null || true
            rmdir "$INSTALL_DIR" 2>/dev/null || true
            log "حذف محتويات مجلد التثبيت: $INSTALL_DIR"
            echo "✅ تم حذف محتويات مجلد التثبيت"
        fi
    else
        echo "⚠️  تم الاحتفاظ بمجلد التثبيت: $INSTALL_DIR"
        log "تم الاحتفاظ بمجلد التثبيت بناءً على طلب المستخدم"
    fi
else
    echo "ℹ️  مجلد التثبيت غير موجود: $INSTALL_DIR"
fi

# ---------- المرحلة 6: تنظيف الملفات المؤقتة ----------
echo ""
echo "🧹 تنظيف الملفات المؤقتة..."

# إزالة ملفات PID
rm -f /tmp/gt-*.pid 2>/dev/null || true
rm -f /tmp/gt-* 2>/dev/null || true

# إزالة ملفات القفل
rm -f "$HOME/.cache/gt-salat-*" 2>/dev/null || true

# إزالة ملفات النظام
rm -f /tmp/dbus-*/gt-* 2>/dev/null || true

echo "✅ تم تنظيف الملفات المؤقتة"

# ---------- المرحلة 7: التحقق النهائي ----------
echo ""
echo "🔍 التحقق النهائي..."

# التحقق من بقاء أي عمليات
REMAINING_PIDS=$(pgrep -f "gt-salat-dikr\|gt-tray.py" 2>/dev/null || true)
if [ -n "$REMAINING_PIDS" ]; then
    echo "⚠️  لا تزال هناك عمليات تعمل:"
    echo "$REMAINING_PIDS"
    read -p "هل تريد إجبار إيقافها؟ [Y/n]: " FORCE_KILL
    FORCE_KILL=${FORCE_KILL:-Y}
    
    if [[ "$FORCE_KILL" =~ ^[Yy]$ ]]; then
        for pid in $REMAINING_PIDS; do
            kill -9 "$pid" 2>/dev/null || true
            echo "  ✅ تم إجبار إيقاف: $pid"
        done
    fi
else
    echo "✅ لا توجد عمليات نشطة"
fi

# التحقق من بقاء أي ملفات
REMAINING_FILES=0
if [ -d "$INSTALL_DIR" ]; then
    REMAINING_FILES=$(find "$INSTALL_DIR" -type f 2>/dev/null | wc -l || echo 0)
fi

REMAINING_SERVICES=0
if command -v systemctl >/dev/null 2>&1; then
    REMAINING_SERVICES=$(systemctl --user list-unit-files | grep -c "gt-salat" 2>/dev/null || echo 0)
fi

# ---------- المرحلة 8: التقرير النهائي ----------
echo ""
echo "════════════════════════════════════════════════════════"
echo "📊 تقرير الإزالة النهائي"
echo "════════════════════════════════════════════════════════"

echo ""
echo "✅ المهام المكتملة:"
echo "════════════════════════════════════════════════════════"
echo "• إيقاف جميع الخدمات والعمليات"
echo "• إزالة ملفات التشغيل التلقائي"
echo "• تنظيف إعدادات الطرفية"
echo "• إزالة الرابط من PATH"
echo "• تنظيف الملفات المؤقتة"
echo "════════════════════════════════════════════════════════"

echo ""
echo "📊 الحالة الحالية:"
echo "════════════════════════════════════════════════════════"
if [ "$REMAINING_FILES" -gt 0 ]; then
    echo "⚠️  الملفات المتبقية: $REMAINING_FILES ملف في $INSTALL_DIR"
else
    echo "✅ لا توجد ملفات متبقية"
fi

if [ "$REMAINING_SERVICES" -gt 0 ]; then
    echo "⚠️  الخدمات المتبقية: $REMAINING_SERVICES خدمة systemd"
else
    echo "✅ لا توجد خدمات systemd متبقية"
fi

if [ -n "$(pgrep -f "gt-salat-dikr\|gt-tray.py" 2>/dev/null || true)" ]; then
    echo "⚠️  لا تزال هناك عمليات تعمل"
else
    echo "✅ لا توجد عمليات نشطة"
fi

if [[ "$BACKUP" =~ ^[Yy]$ ]] && [ -d "$BACKUP_DIR" ]; then
    echo "📁 النسخة الاحتياطية: $BACKUP_DIR"
fi

echo "📋 سجل الإزالة: $LOG_FILE"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🎉 تمت الإزالة بنجاح!"
echo ""
echo "ملاحظات:"
echo "════════════════════════════════════════════════════════"
echo "• قد تحتاج إلى إعادة تشغيل الطرفية لتطبيق التغييرات"
echo "• إذا أردت إعادة التثبيت لاحقاً، استخدم install.sh"
echo "• يمكنك حذف النسخة الاحتياطية يدوياً إذا لم تعد تحتاجها"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔄 لإعادة التثبيت:"
echo "════════════════════════════════════════════════════════"
echo "git clone https://github.com/SalehGNUTUX/GT-salat-dikr.git"
echo "cd GT-salat-dikr"
echo "bash install.sh"
echo "════════════════════════════════════════════════════════"

log "اكتملت عملية الإزالة بنجاح"

exit 0
