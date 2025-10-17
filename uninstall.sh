#!/bin/bash
#
# GT-salat-dikr Uninstall Script (2025)
#

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
MAIN_SCRIPT="$INSTALL_DIR/gt-salat-dikr.sh"

# تحميل الإعدادات إذا وجدت
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE" 2>/dev/null || true
fi

echo "⚠️  هذا الإجراء سيزيل GT-salat-dikr بالكامل."
read -p "هل أنت متأكد؟ [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "تم إلغاء الإزالة."
    exit 0
fi

echo ""
echo "🛑 إيقاف جميع الخدمات والإشعارات..."

# 1. محاولة استخدام السكربت نفسه للإيقاف إذا كان موجوداً
if [ -f "$MAIN_SCRIPT" ]; then
    echo "⏹️  استخدام السكربت الرسمي للإيقاف..."
    "$MAIN_SCRIPT" --notify-stop 2>/dev/null || true
    sleep 2
else
    echo "ℹ️  الملف الرئيسي غير موجود، تخطي الإيقاف الرسمي..."
fi

# 2. إيقاف جميع العمليات المرتبطة (يعمل حتى بدون الملف الرئيسي)
echo "⏹️  إيقاف عمليات البرنامج..."
pkill -f "gt-salat-dikr" 2>/dev/null || true
pkill -f "adhan-player" 2>/dev/null || true
pkill -f "approaching-player" 2>/dev/null || true
pkill -f "gtsalat" 2>/dev/null || true

sleep 2

# 3. إجبار إيقاف العمليات المتبقية
echo "⏹️  إجبار إيقاف العمليات المتبقية..."
pkill -9 -f "gt-salat-dikr" 2>/dev/null || true
pkill -9 -f "adhan-player" 2>/dev/null || true
pkill -9 -f "approaching-player" 2>/dev/null || true

# 4. إزالة خدمات systemd
echo "⏹️  إزالة خدمات systemd..."
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active gt-salat-dikr.service >/dev/null 2>&1; then
        systemctl --user stop gt-salat-dikr.service
        systemctl --user disable gt-salat-dikr.service
        echo "✅ تم إيقاف خدمة systemd."
    fi
    
    if [ -f "$HOME/.config/systemd/user/gt-salat-dikr.service" ]; then
        rm -f "$HOME/.config/systemd/user/gt-salat-dikr.service"
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user reset-failed 2>/dev/null || true
        echo "✅ تم إزالة خدمة systemd."
    fi
fi

# 5. إزالة autostart
echo "⏹️  إزالة autostart..."
if [ -f "$HOME/.config/autostart/gt-salat-dikr.desktop" ]; then
    rm -f "$HOME/.config/autostart/gt-salat-dikr.desktop"
    echo "✅ تم إزالة autostart."
fi

# 6. إزالة الروابط الرمزية
echo "⏹️  إزالة الروابط الرمزية..."
if [ -L "$HOME/.local/bin/gtsalat" ] || [ -f "$HOME/.local/bin/gtsalat" ]; then
    rm -f "$HOME/.local/bin/gtsalat"
    echo "✅ تم إزالة الرابط الرمزي من ~/.local/bin/gtsalat"
fi

# من مسارات system-wide
rm -f "/usr/local/bin/gtsalat" 2>/dev/null || true
rm -f "/usr/bin/gtsalat" 2>/dev/null || true

echo "✅ تم إيقاف جميع الخدمات والإشعارات."

echo ""
echo "📁 اختيار ملفات الإبقاء:"
echo "1) حذف كل شيء بما فيهم ملفات التثبيت والإزالة"
echo "2) الإبقاء على ملفات التثبيت والإزالة فقط (موصى به - يمكن إعادة التثبيت)"
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
        # الملفات التي يجب الاحتفاظ بها (بما في ذلك الملف الرئيسي إذا كان موجوداً)
        keep_files=("install.sh" "uninstall.sh" "adhan.ogg" "short_adhan.ogg" "prayer_approaching.ogg")
        
        # إذا كان الملف الرئيسي موجوداً، أضفه إلى قائمة الاحتفاظ
        if [ -f "$MAIN_SCRIPT" ]; then
            keep_files+=("gt-salat-dikr.sh")
        fi
        
        # حذف جميع الملفات ما عدا المحددة
        cd "$INSTALL_DIR"
        for file in * .*; do
            if [ "$file" != "." ] && [ "$file" != ".." ]; then
                if [ -f "$file" ]; then
                    should_keep=false
                    for keep_file in "${keep_files[@]}"; do
                        if [ "$file" == "$keep_file" ]; then
                            should_keep=true
                            break
                        fi
                    done
                    
                    if [ "$should_keep" = "false" ]; then
                        rm -f "$file"
                        echo "  🗑️  حذف: $file"
                    else
                        echo "  💾 احتفظ: $file"
                    fi
                fi
            fi
        done
        
        echo "✅ تم حذف ملفات التشغيل مع الإبقاء على ملفات التثبيت."
    else
        echo "ℹ️  مجلد التثبيت غير موجود."
    fi
fi

# تنظيف الملفات المؤقتة
echo ""
echo "🧹 تنظيف الملفات المؤقتة..."
rm -f "/tmp/gt-adhan-player-"* 2>/dev/null || true
rm -f "/tmp/gt-approaching-"* 2>/dev/null || true
rm -f "/tmp/gt-salat-dikr-"* 2>/dev/null || true
rm -f "/tmp/gt-*-player-*.pid" 2>/dev/null || true

echo "✅ تم تنظيف الملفات المؤقتة."

echo ""
echo "🔍 التحقق من الإزالة النهائية..."

# التحقق من العمليات المتبقية
remaining_pids=$(pgrep -f "gt-salat-dikr\|gtsalat" 2>/dev/null || true)
if [ -n "$remaining_pids" ]; then
    echo "❌ لا يزال هناك عمليات نشطة (PIDs): $remaining_pids"
    echo "$remaining_pids" | xargs kill -9 2>/dev/null || true
    sleep 1
else
    echo "✅ لا توجد عمليات نشطة."
fi

# التحقق من الملفات المتبقية
echo ""
echo "📊 تقرير الإزالة النهائي:"

if [ "$keep_choice" = "1" ]; then
    if [ -d "$INSTALL_DIR" ]; then
        echo "❌ فشل في حذف مجلد التثبيت"
    else
        echo "✅ تم حذف مجلد التثبيت بنجاح"
    fi
else
    if [ -d "$INSTALL_DIR" ]; then
        if [ -f "$MAIN_SCRIPT" ]; then
            echo "✅ تم الاحتفاظ بالملف الرئيسي (يمكن إعادة التثبيت)"
        else
            echo "⚠️  مجلد التثبيت محفوظ ولكن الملف الرئيسي مفقود"
        fi
    fi
fi

if [ -f "$HOME/.local/bin/gtsalat" ]; then
    echo "❌ فشل في إزالة الرابط الرمزي"
else
    echo "✅ تم إزالة الرابط الرمزي بنجاح"
fi

# تنظيف إعدادات الطرفية
echo ""
echo "🧹 تنظيف إعدادات الطرفية..."
cleaned_files=0
for shell_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$shell_file" ]; then
        if grep -q "gtsalat\|GT-salat-dikr" "$shell_file" 2>/dev/null; then
            sed -i '/gtsalat/d; /GT-salat-dikr/d' "$shell_file" 2>/dev/null || true
            echo "✅ تم تنظيف $shell_file"
            cleaned_files=$((cleaned_files + 1))
        fi
    fi
done

if [ $cleaned_files -eq 0 ]; then
    echo "✅ لا توجد إعدادات طرفية تحتاج تنظيف"
fi

echo ""
echo "💡 ملاحظات:"
if [ "$keep_choice" = "2" ] && [ -d "$INSTALL_DIR" ]; then
    if [ -f "$MAIN_SCRIPT" ]; then
        echo "   - تم الإبقاء على جميع ملفات التثبيت في: $INSTALL_DIR"
        echo "   - لإعادة التثبيت: cd $INSTALL_DIR && bash install.sh"
    else
        echo "   - تم الإبقاء على مجلد التثبيت ولكن الملف الرئيسي مفقود"
        echo "   - لتحميل الملفات من جديد:"
        echo "     bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
    fi
else
    echo "   - تم إزالة البرنامج بالكامل"
    echo "   - لإعادة التثبيت عن بُعد:"
    echo "     bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/install.sh)\""
fi

echo ""
echo "🎉 تمت إزالة التثبيت بالكامل!"
