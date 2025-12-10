#!/bin/bash
#
# GT-salat-dikr Complete Uninstall Script - v3.2.3
# إزالة كاملة مع دعم إزالة السكربت نفسه
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
SCRIPT_SELF="$0"

# ---------- دالة لتحديد إذا كان السكربت يعمل من مجلد التثبيت ----------
is_running_from_install_dir() {
    local script_dir=$(dirname "$(realpath "$SCRIPT_SELF")")
    local install_dir_real=$(realpath "$INSTALL_DIR" 2>/dev/null || echo "")
    
    if [ -n "$install_dir_real" ] && [ "$script_dir" = "$install_dir_real" ]; then
        return 0  # يعمل من مجلد التثبيت
    else
        return 1  # يعمل من مكان آخر
    fi
}

# ---------- دالة نسخ السكربت إلى موقع مؤقت (فقط إذا كان في مجلد التثبيت) ----------
copy_self_to_temp_if_needed() {
    # فقط إذا كان السكربت يعمل من مجلد التثبيت
    if is_running_from_install_dir; then
        local temp_script="/tmp/gt-salat-uninstall-$$.sh"
        
        echo "📋 نسخ سكربت الإزالة إلى موقع مؤقت..."
        
        # نسخ محتوى السكربت الحالي بدون السطر الذي يسبب الحلقة
        sed '/exec.*gt-salat-uninstall/d' "$SCRIPT_SELF" > "$temp_script"
        chmod +x "$temp_script"
        
        # تشغيل النسخة المؤقتة ونخرج
        echo "🔄 تشغيل النسخة المؤقتة..."
        exec "$temp_script" "$@"
    fi
}

# ---------- دالة التسجيل ----------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

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

# ---------- نسخ السكربت إلى موقع مؤقت إذا لزم الأمر ----------
copy_self_to_temp_if_needed "$@"

# ---------- إنشاء مجلد اللوغ إذا لم يكن موجودًا ----------
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ---------- إنشاء نسخة احتياطية إذا طلب المستخدم ----------
if [[ "$BACKUP" =~ ^[Yy]$ ]]; then
    BACKUP_DIR="$HOME/gt-salat-dikr-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    log "إنشاء نسخة احتياطية في: $BACKUP_DIR"
    
    # نسخ الملفات المهمة
    if [ -d "$INSTALL_DIR" ]; then
        echo "📁 جاري إنشاء نسخة احتياطية..."
        
        # إنشاء قائمة الملفات المهمة
        IMPORTANT_FILES=(
            "settings.conf"
            "azkar.txt"
            "notify.log"
            "timetable.json"
        )
        
        for file in "${IMPORTANT_FILES[@]}"; do
            if [ -f "$INSTALL_DIR/$file" ]; then
                cp "$INSTALL_DIR/$file" "$BACKUP_DIR/" 2>/dev/null || true
                echo "  📄 تم نسخ: $file"
            fi
        done
        
        # نسخ مجلد الجداول الشهرية
        if [ -d "$INSTALL_DIR/monthly_timetables" ]; then
            cp -r "$INSTALL_DIR/monthly_timetables" "$BACKUP_DIR/" 2>/dev/null || true
            echo "  📁 تم نسخ: monthly_timetables/"
        fi
        
        # نسخ الأيقونات
        if [ -d "$INSTALL_DIR/icons" ]; then
            mkdir -p "$BACKUP_DIR/icons"
            cp -r "$INSTALL_DIR/icons/"*.png "$BACKUP_DIR/icons/" 2>/dev/null || true
            echo "  🖼️  تم نسخ: icons/"
        fi
        
        echo "✅ تم إنشاء نسخة احتياطية في: $BACKUP_DIR"
        echo ""
        echo "📊 محتويات النسخة الاحتياطية:"
        ls -la "$BACKUP_DIR/" 2>/dev/null || echo "  (لا توجد ملفات)"
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
    
    # قائمة الخدمات المحتملة
    USER_SERVICES_DIR="$HOME/.config/systemd/user"
    
    if [ -d "$USER_SERVICES_DIR" ]; then
        for service_file in "$USER_SERVICES_DIR"/gt-salat-*.service; do
            if [ -f "$service_file" ]; then
                service_name=$(basename "$service_file")
                log "معالجة خدمة: $service_name"
                
                # إيقاف الخدمة
                systemctl --user stop "$service_name" 2>/dev/null || true
                systemctl --user disable "$service_name" 2>/dev/null || true
                
                echo "  ✅ تم إيقاف: $service_name"
            fi
        done
    fi
    
    systemctl --user daemon-reload 2>/dev/null || true
fi

# إيقاف عمليات sysvinit/autostart
echo "🔧 إيقاف عمليات التشغيل التلقائي..."

# أولاً: البحث عن عمليات النظام الأساسية
echo "🔍 البحث عن عمليات نشطة..."
MAIN_PROCESSES=$(pgrep -f "gt-salat-dikr" 2>/dev/null || true)
TRAY_PROCESSES=$(pgrep -f "gt-tray.py" 2>/dev/null || true)

ALL_PIDS=""
if [ -n "$MAIN_PROCESSES" ]; then
    ALL_PIDS="$MAIN_PROCESSES"
fi
if [ -n "$TRAY_PROCESSES" ]; then
    ALL_PIDS="$ALL_PIDS $TRAY_PROCESSES"
fi

if [ -n "$ALL_PIDS" ]; then
    log "عمليات مكتشفة: $ALL_PIDS"
    for pid in $ALL_PIDS; do
        if ps -p "$pid" >/dev/null 2>&1; then
            echo "  🔴 إيقاف العملية: $pid"
            kill "$pid" 2>/dev/null || true
            sleep 0.5
            if ps -p "$pid" >/dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
                echo "  ⚠️  تم إجبار إيقاف: $pid"
            else
                echo "  ✅ تم إيقاف: $pid"
            fi
        fi
    done
else
    echo "  ℹ️  لا توجد عمليات نشطة"
fi

# ثانياً: البحث عن عمليات الخلفية
sleep 1
REMAINING_PROCESSES=$(pgrep -f "gt-salat-dikr\|gt-tray.py\|autostart-manager" 2>/dev/null || true)

if [ -n "$REMAINING_PROCESSES" ]; then
    echo "🔍 عمليات متبقية: $REMAINING_PROCESSES"
    for pid in $REMAINING_PROCESSES; do
        kill -9 "$pid" 2>/dev/null || true
        echo "  ✅ تم إزالة العملية المتبقية: $pid"
    done
fi

# تأخير للتأكد من توقف العمليات
sleep 2

# ---------- المرحلة 3: إزالة ملفات التشغيل التلقائي ----------
echo ""
echo "🗑️  إزالة ملفات التشغيل التلقائي..."

# إزالة ملفات desktop autostart
AUTOSTART_DIR="$HOME/.config/autostart"
if [ -d "$AUTOSTART_DIR" ]; then
    echo "🔧 تنظيف مجلد autostart..."
    
    AUTOSTART_FILES=(
        "gt-salat-dikr.desktop"
        "gt-salat-tray.desktop"
        "gt-salat-dikr-autostart.desktop"
        "gt-salat-dikr-full.desktop"
    )
    
    for file in "${AUTOSTART_FILES[@]}"; do
        if [ -f "$AUTOSTART_DIR/$file" ]; then
            rm -f "$AUTOSTART_DIR/$file"
            log "إزالة ملف autostart: $file"
            echo "  ✅ تم إزالة: $file"
        fi
    done
fi

# إزالة إعدادات Plasma (KDE)
if [ -d "$HOME/.config/plasma-workspace/env" ]; then
    echo "🔧 تنظيف إعدادات KDE Plasma..."
    rm -f "$HOME/.config/plasma-workspace/env/gt-salat-dikr.sh" 2>/dev/null || true
    echo "  ✅ تم تنظيف إعدادات KDE"
fi

# إزالة إعدادات XFCE
XFCE_AUTOSTART="$HOME/.config/xfce4/autostart"
if [ -d "$XFCE_AUTOSTART" ]; then
    echo "🔧 تنظيف إعدادات XFCE..."
    rm -f "$XFCE_AUTOSTART/gt-salat-dikr.desktop" 2>/dev/null || true
    echo "  ✅ تم تنظيف إعدادات XFCE"
fi

# إزالة إعدادات LXDE/LXQt
LXDE_AUTOSTART="$HOME/.config/lxsession/LXDE/autostart"
if [ -f "$LXDE_AUTOSTART" ]; then
    echo "🔧 تنظيف إعدادات LXDE/LXQt..."
    grep -v "gt-salat-dikr" "$LXDE_AUTOSTART" > "${LXDE_AUTOSTART}.tmp" 2>/dev/null || true
    mv "${LXDE_AUTOSTART}.tmp" "$LXDE_AUTOSTART" 2>/dev/null || true
    echo "  ✅ تم تنظيف إعدادات LXDE"
fi

# إزالة ملف التطبيق من القائمة
APPLICATIONS_DIR="$HOME/.local/share/applications"
if [ -d "$APPLICATIONS_DIR" ]; then
    rm -f "$APPLICATIONS_DIR/gt-salat-dikr.desktop" 2>/dev/null || true
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
    fi
    echo "✅ تم تنظيف قائمة التطبيقات"
fi

# ---------- المرحلة 4: إزالة إعدادات الطرفية ----------
echo ""
echo "🔧 تنظيف إعدادات الطرفية..."

clean_shell_config() {
    local shell_file="$1"
    local shell_name="$2"
    
    if [ -f "$shell_file" ]; then
        echo "🔧 تنظيف: $shell_name"
        
        # إنشاء نسخة احتياطية قبل التعديل
        backup_file="${shell_file}.backup-before-gt-uninstall"
        if [ ! -f "$backup_file" ]; then
            cp "$shell_file" "$backup_file" 2>/dev/null || true
        fi
        
        # إنشاء ملف مؤقت نظيف
        temp_file="${shell_file}.tmp"
        
        # إزالة كتل GT-salat-dikr
        grep -v -E "(gtsalat|gt-salat-dikr|GT-salat-dikr|alias.*gtsalat|~/.GT-salat-dikr|~/.local/bin/gtsalat)" "$shell_file" > "$temp_file" 2>/dev/null || {
            # إذا فشل grep، استخدم cat بسيط
            cat "$shell_file" | grep -v "gtsalat" | grep -v "gt-salat-dikr" | grep -v "GT-salat-dikr" > "$temp_file" 2>/dev/null || true
        }
        
        # نسخ الملف المؤقت إلى الأصلي
        if [ -s "$temp_file" ]; then
            mv "$temp_file" "$shell_file"
            echo "  ✅ تم تنظيف: $shell_name"
        else
            rm -f "$temp_file"
            echo "  ℹ️  لا توجد إعدادات لتنظيفها في: $shell_name"
        fi
        
        log "تنظيف ملف: $shell_file"
    fi
}

# تنظيف ملفات shell المختلفة
clean_shell_config "$HOME/.bashrc" ".bashrc"
clean_shell_config "$HOME/.bash_profile" ".bash_profile"
clean_shell_config "$HOME/.zshrc" ".zshrc"
clean_shell_config "$HOME/.profile" ".profile"

# إزالة الرابط من PATH
if [ -L "$HOME/.local/bin/gtsalat" ]; then
    rm -f "$HOME/.local/bin/gtsalat"
    echo "✅ تم إزالة الرابط من PATH"
fi

# إزالة مجلد .local/bin إذا كان فارغاً
if [ -d "$HOME/.local/bin" ] && [ -z "$(ls -A "$HOME/.local/bin" 2>/dev/null)" ]; then
    rmdir "$HOME/.local/bin" 2>/dev/null || true
    echo "🗑️  تم إزالة مجلد .local/bin الفارغ"
fi

# ---------- المرحلة 5: إزالة مجلد التثبيت ----------
echo ""
echo "🗑️  إزالة مجلد التثبيت..."

if [ -d "$INSTALL_DIR" ]; then
    # حساب حجم المجلد
    folder_size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1) || folder_size="غير معروف"
    
    echo "📊 حجم مجلد التثبيت: $folder_size"
    echo "📁 المحتويات الرئيسية:"
    ls -la "$INSTALL_DIR/" 2>/dev/null | head -10 || echo "  (غير قابل للقراءة)"
    
    echo ""
    read -p "هل تريد حذف مجلد التثبيت بالكامل؟ [Y/n]: " DELETE_DIR
    DELETE_DIR=${DELETE_DIR:-Y}
    
    if [[ "$DELETE_DIR" =~ ^[Yy]$ ]]; then
        echo "🗑️  جاري حذف مجلد التثبيت..."
        
        # محاولة حذف المجلد
        if rm -rf "$INSTALL_DIR"; then
            log "حذف مجلد التثبيت: $INSTALL_DIR"
            echo "✅ تم حذف مجلد التثبيت بنجاح"
        else
            # محاولة حذف خطوة بخطوة
            echo "⚠️  تعذر الحذف المباشر، جاري الحذف التدريجي..."
            
            # حذف الملفات أولاً
            find "$INSTALL_DIR" -type f -delete 2>/dev/null || true
            
            # حذف المجلدات الفرعية
            find "$INSTALL_DIR" -mindepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
            
            # حذف المجلد الرئيسي
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

# إزالة ملفات PID والقفل
echo "🗑️  حذف ملفات PID والقفل..."
rm -f /tmp/gt-*.pid 2>/dev/null || true
rm -f /tmp/gt-salat-*.lock 2>/dev/null || true
rm -f /tmp/dbus-*/gt-* 2>/dev/null || true

# إزالة ملفات السكربتات المؤقتة
echo "🗑️  حذف السكربتات المؤقتة..."
rm -f /tmp/gt-salat-uninstall-*.sh 2>/dev/null || true
rm -f /tmp/gt-salat-install-*.sh 2>/dev/null || true

# إزالة ملفات القفل في مجلد cache
echo "🗑️  حذف ملفات cache..."
rm -f "$HOME/.cache/gt-salat-*" 2>/dev/null || true
rm -f "$HOME/.cache/gt-*" 2>/dev/null || true

echo "✅ تم تنظيف الملفات المؤقتة"

# ---------- المرحلة 7: التحقق النهائي ----------
echo ""
echo "🔍 التحقق النهائي..."

# التحقق من بقاء أي عمليات
REMAINING_PIDS=$(pgrep -f "gt-salat-dikr\|gt-tray.py" 2>/dev/null || true)
if [ -n "$REMAINING_PIDS" ]; then
    echo "⚠️  لا تزال هناك عمليات تعمل:"
    for pid in $REMAINING_PIDS; do
        echo "  🔴 PID: $pid"
    done
    
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
if [ -d "$INSTALL_DIR" ]; then
    REMAINING_FILES=$(find "$INSTALL_DIR" -type f 2>/dev/null | wc -l)
    echo "⚠️  مجلد التثبيت لا يزال موجودًا ويحتوي على $REMAINING_FILES ملف"
else
    echo "✅ مجلد التثبيت تم إزالته"
fi

# ---------- المرحلة 8: التقرير النهائي ----------
echo ""
echo "════════════════════════════════════════════════════════"
echo "📊 تقرير الإزالة النهائي"
echo "════════════════════════════════════════════════════════"

echo ""
echo "✅ المهام المكتملة:"
echo "════════════════════════════════════════════════════════"
echo "• إيقاف جميع الخدمات والعمليات ✓"
echo "• إزالة ملفات التشغيل التلقائي ✓"
echo "• تنظيف إعدادات الطرفية ✓"
echo "• إزالة الرابط من PATH ✓"
echo "• تنظيف الملفات المؤقتة ✓"
echo "════════════════════════════════════════════════════════"

echo ""
echo "📊 الحالة النهائية:"
echo "════════════════════════════════════════════════════════"

# التحقق من وجود مجلد التثبيت
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  مجلد التثبيت لا يزال موجودًا: $INSTALL_DIR"
    echo "   يمكنك حذفه يدويًا باستخدام: rm -rf $INSTALL_DIR"
else
    echo "✅ مجلد التثبيت تم إزالته"
fi

# التحقق من وجود عمليات نشطة
if pgrep -f "gt-salat-dikr\|gt-tray.py" >/dev/null 2>&1; then
    echo "⚠️  لا تزال هناك عمليات نشطة"
    echo "   يمكنك إيقافها باستخدام: pkill -f 'gt-salat-dikr\|gt-tray.py'"
else
    echo "✅ لا توجد عمليات نشطة"
fi

# التحقق من وجود ملفات autostart
AUTOSTART_REMAINING=$(find "$HOME/.config/autostart" -name "*gt-salat*" 2>/dev/null | wc -l)
if [ "$AUTOSTART_REMAINING" -gt 0 ]; then
    echo "⚠️  توجد $AUTOSTART_REMAINING ملفات autostart متبقية"
else
    echo "✅ تم تنظيف ملفات autostart"
fi

if [[ "$BACKUP" =~ ^[Yy]$ ]] && [ -d "$BACKUP_DIR" ]; then
    echo "📁 النسخة الاحتياطية: $BACKUP_DIR"
    echo "   يمكنك حذفها باستخدام: rm -rf $BACKUP_DIR"
fi

echo "════════════════════════════════════════════════════════"

echo ""
echo "🎉 تمت الإزالة بنجاح!"
echo ""
echo "ملاحظات:"
echo "════════════════════════════════════════════════════════"
echo "• قد تحتاج إلى إعادة تشغيل الطرفية لتطبيق التغييرات"
echo "• قد تحتاج إلى تسجيل الخروج والدخول لإزالة جميع الآثار"
echo "• إذا أردت إعادة التثبيت، استخدم install.sh من المستودع"
echo "════════════════════════════════════════════════════════"

echo ""
echo "🔄 لإعادة التثبيت:"
echo "════════════════════════════════════════════════════════"
echo "curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh | bash"
echo "أو"
echo "git clone https://github.com/SalehGNUTUX/GT-salat-dikr.git"
echo "cd GT-salat-dikr"
echo "bash install.sh"
echo "════════════════════════════════════════════════════════"

# تسجيل اكتمال العملية
if [ -d "$(dirname "$LOG_FILE")" ]; then
    log "اكتملت عملية الإزالة بنجاح"
fi

# تنظيف النسخة المؤقتة من السكربت (إن وجدت)
rm -f "/tmp/gt-salat-uninstall-$$.sh" 2>/dev/null || true

exit 0
