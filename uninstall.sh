#!/bin/bash
#
# GT-salat-dikr Uninstall Script (2025)
#BY GNUTUX

set -e

echo "════════════════════════════════════════════════════════"
echo "  إزالة تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  لا تشغل هذا السكربت بصلاحيات root."
    exit 1
fi

INSTALL_DIR="$HOME/.GT-salat-dikr"
CONFIG_FILE="$INSTALL_DIR/settings.conf"

# تحميل الإعدادات إذا وجدت
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل."
read -p "هل أنت متأكد؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🛑 إيقاف جميع الخدمات والإشعارات..."

# إيقاف جميع عمليات البرنامج
echo "⏹️  إيقاف عمليات البرنامج..."
pkill -f "gt-salat-dikr" 2>/dev/null || true
pkill -f "adhan-player" 2>/dev/null || true
pkill -f "approaching-player" 2>/dev/null || true
pkill -f "gtsalat" 2>/dev/null || true

# إعطاء وقت للإيقاف
sleep 2

# إجبار إيقاف أي عمليات متبقية
pkill -9 -f "gt-salat-dikr" 2>/dev/null || true
pkill -9 -f "adhan-player" 2>/dev/null || true

# إزالة خدمات systemd
echo "⏹️  إزالة خدمات systemd..."
if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
    systemctl --user stop gt-salat-dikr.service
    systemctl --user disable gt-salat-dikr.service
    echo "✅ تم إيقاف خدمة systemd."
fi

if [ -f "$HOME/.config/systemd/user/gt-salat-dikr.service" ]; then
    rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "✅ تم إزالة خدمة systemd."
fi

# إزالة autostart
echo "⏹️  إزالة autostart..."
if [ -f "$HOME/.config/autostart/gt-salat-dikr.desktop" ]; then
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop"
    echo "✅ تم إزالة autostart."
fi

# إزالة الرابط الرمزي
echo "⏹️  إزالة الرابط الرمزي..."
if [ -L "$HOME/.local/bin/gtsalat" ]; then
    rm -f "$HOME/.local/bin/gtsalat"
    echo "✅ تم إزالة الرابط الرمزي gtsalat."
fi

# إزالة أي روابط أخرى محتملة
rm -f "/usr/local/bin/gtsalat" 2>/dev/null || true
rm -f "/usr/bin/gtsalat" 2>/dev/null || true

echo "✅ تم إيقاف جميع الخدمات والإشعارات."

echo ""
echo "📁 اختيار ملفات الإبقاء:"
echo "1) حذف كل شيء بما فيهم ملفات التثبيت والإزالة"
echo "2) الإبقاء على ملفات التثبيت والإزالة فقط (موصى به للنسخ المستقبلية)"
read -p "اختر الخيار [2]: " keep_choice
keep_choice=${keep_choice:-2}

if [ "$keep_choice" = "1" ]; then
    echo "🗑️  حذف جميع الملفات..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        echo "✅ تم حذف مجلد التثبيت بالكامل."
    else
        echo "ℹ️  مجلد التثبيت غير موجود."
    fi
else
    echo "💾 الإبقاء على ملفات التثبيت الأساسية..."
    
    if [ -d "$INSTALL_DIR" ]; then
        # حذف جميع الملفات باستثناء الأساسية
        cd "$INSTALL_DIR"
        
        # قائمة الملفات للحفظ
        files_to_keep=("install.sh" "uninstall.sh" "adhan.ogg" "short_adhan.ogg" "prayer_approaching.ogg")
        
        # حذف جميع الملفات ما عدا المحددة
        for file in *; do
            if [ -f "$file" ]; then
                keep=false
                for keep_file in "${files_to_keep[@]}"; do
                    if [ "$file" = "$keep_file" ]; then
                        keep=true
                        break
                    fi
                done
                if [ "$keep" = "false" ]; then
                    rm -f "$file"
                    echo "  🗑️  حذف: $file"
                else
                    echo "  💾 احتفظ: $file"
                fi
            fi
        done
        
        # حذف الملفات المخفية
        rm -f .gt-salat-dikr-notify.pid 2>/dev/null || true
        rm -f .last-prayer-notified 2>/dev/null || true
        rm -f .last-preprayer-notified 2>/dev/null || true
        
        echo "✅ تم حذف ملفات التشغيل مع الإبقاء على ملفات التثبيت."
    else
        echo "ℹ️  مجلد التثبيت غير موجود."
    fi
fi

# تنظيف ملفات النظام المؤقتة
echo "🧹 تنظيف الملفات المؤقتة..."
rm -f "/tmp/gt-adhan-player-"* 2>/dev/null || true
rm -f "/tmp/gt-approaching-"* 2>/dev/null || true
rm -f "/tmp/gt-salat-dikr-"* 2>/dev/null || true

echo "✅ تم تنظيف الملفات المؤقتة."

echo ""
echo "🔍 التحقق من الإزالة النهائية..."

# التحقق النهائي من العمليات
if pgrep -f "gt-salat-dikr" >/dev/null 2>&1; then
    echo "❌ لا يزال هناك عمليات نشطة:"
    pgrep -f "gt-salat-dikr" | xargs ps -p 2>/dev/null || true
else
    echo "✅ لا توجد عمليات نشطة."
fi

# التحقق من الإزالة
if [ "$keep_choice" = "1" ]; then
    if [ -d "$INSTALL_DIR" ]; then
        echo "❌ فشل في حذف مجلد التثبيت: $INSTALL_DIR"
    else
        echo "✅ تم حذف مجلد التثبيت بنجاح."
    fi
else
    if [ -d "$INSTALL_DIR" ]; then
        echo "✅ تم الاحتفاظ بمجلد التثبيت مع حذف ملفات التشغيل."
    fi
fi

if [ -f "$HOME/.local/bin/gtsalat" ]; then
    echo "❌ فشل في إزالة الرابط الرمزي."
else
    echo "✅ تم إزالة الرابط الرمزي بنجاح."
fi

# تنظيف إعدادات الطرفية
echo ""
echo "🧹 تنظيف إعدادات الطرفية..."
# إزالة أي أثار من ملفات البيئة
for shell_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$shell_file" ]; then
        if grep -q "gtsalat\|GT-salat-dikr" "$shell_file" 2>/dev/null; then
            sed -i '/gtsalat/d' "$shell_file" 2>/dev/null || true
            sed -i '/GT-salat-dikr/d' "$shell_file" 2>/dev/null || true
            echo "✅ تم تنظيف $shell_file"
        fi
    fi
done

echo "✅ تم تنظيف إعدادات الطرفية."

echo ""
echo "💡 ملاحظات:"
if [ "$keep_choice" = "2" ] && [ -d "$INSTALL_DIR" ]; then
    echo "   - تم الإبقاء على ملفات التثبيت في: $INSTALL_DIR"
    echo "   - يمكنك إعادة التثبيت لاحقًا عن طريق:"
    echo "     cd $INSTALL_DIR && bash install.sh"
else
    echo "   - تم إزالة البرنامج بالكامل"
    echo "   - يمكنك إعادة التثبيت لاحقًا عن طريق:"
    echo "     bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
fi

echo ""
echo "🎉 تمت إزالة التثبيت بالكامل!"
