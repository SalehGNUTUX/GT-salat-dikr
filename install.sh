#!/bin/bash
#
# GT-salat-dikr Enhanced Installation Script
# يدعم جميع توزيعات Linux وبيئات سطح المكتب
#

set -e

echo "════════════════════════════════════════════════════════"
echo "  تثبيت GT-salat-dikr - نظام إشعارات الصلاة والأذكار"
echo "════════════════════════════════════════════════════════"
echo ""

# التحقق من الصلاحيات
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  تحذير: لا تشغل هذا السكربت بصلاحيات root"
    echo "   استخدم حساب المستخدم العادي."
    exit 1
fi

# المتغيرات
INSTALL_DIR="$HOME/.GT-salat-dikr"
REPO_BASE="https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main"
MAIN_SCRIPT="gt-salat-dikr.sh"

# التحقق من الأدوات المطلوبة
echo "🔍 فحص المتطلبات..."
MISSING_TOOLS=()

if ! command -v curl >/dev/null 2>&1; then
    MISSING_TOOLS+=("curl")
else
    echo "  ✓ curl متوفر"
fi

if ! command -v jq >/dev/null 2>&1; then
    MISSING_TOOLS+=("jq")
else
    echo "  ✓ jq متوفر"
fi

if ! command -v notify-send >/dev/null 2>&1; then
    MISSING_TOOLS+=("libnotify (notify-send)")
else
    echo "  ✓ libnotify متوفر"
fi

# اكتشاف الأدوات الرسومية
GUI_FOUND=0
if command -v zenity >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ zenity متوفر"
elif command -v yad >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ yad متوفر"
elif command -v kdialog >/dev/null 2>&1; then
    GUI_FOUND=1
    echo "  ✓ kdialog متوفر"
fi

if [ $GUI_FOUND -eq 0 ]; then
    echo "  ⚠️ لم يتم العثور على أداة رسومية (zenity/yad/kdialog)"
    echo "     سيتم استخدام إشعارات بسيطة فقط"
fi

# اكتشاف مشغلات الصوت
AUDIO_FOUND=0
if command -v mpv >/dev/null 2>&1; then
    AUDIO_FOUND=1
    echo "  ✓ mpv متوفر"
elif command -v ffplay >/dev/null 2>&1; then
    AUDIO_FOUND=1
    echo "  ✓ ffplay متوفر"
elif command -v paplay >/dev/null 2>&1; then
    AUDIO_FOUND=1
    echo "  ✓ paplay متوفر"
elif command -v ogg123 >/dev/null 2>&1; then
    AUDIO_FOUND=1
    echo "  ✓ ogg123 متوفر"
fi

if [ $AUDIO_FOUND -eq 0 ]; then
    echo "  ⚠️ لم يتم العثور على مشغل صوت"
    echo "     الأذان والإشعارات الصوتية لن تعمل"
fi

# عرض الأدوات الناقصة
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "❌ الأدوات التالية مفقودة:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "📦 يرجى تثبيتها أولاً:"
    
    # اكتشاف مدير الحزم
    if command -v apt >/dev/null 2>&1; then
        echo "  sudo apt update && sudo apt install ${MISSING_TOOLS[*]//libnotify (notify-send)/libnotify-bin}"
    elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install ${MISSING_TOOLS[*]//libnotify (notify-send)/libnotify}"
    elif command -v yum >/dev/null 2>&1; then
        echo "  sudo yum install ${MISSING_TOOLS[*]//libnotify (notify-send)/libnotify}"
    elif command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S ${MISSING_TOOLS[*]//libnotify (notify-send)/libnotify}"
    elif command -v zypper >/dev/null 2>&1; then
        echo "  sudo zypper install ${MISSING_TOOLS[*]//libnotify (notify-send)/libnotify}"
    else
        echo "  ⚠️ لم يتم التعرف على مدير الحزم - يرجى تثبيت الأدوات يدوياً"
    fi
    
    echo ""
    read -p "هل تريد المتابرة رغم ذلك؟ [y/N]: " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "✅ جميع المتطلبات الأساسية متوفرة"

# إنشاء مجلد التثبيت
echo ""
echo "📁 إنشاء مجلد التثبيت..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# تحميل الملفات الأساسية
echo ""
echo "⬇️  تحميل الملفات الأساسية..."

download_file() {
    local file="$1"
    local url="$REPO_BASE/$file"
    echo "  تحميل: $file"
    if curl -fsSL "$url" -o "$file"; then
        echo "  ✓ تم تحميل $file"
        return 0
    else
        echo "  ❌ فشل تحميل $file"
        return 1
    fi
}

# تحميل السكربت الرئيسي
if ! download_file "$MAIN_SCRIPT"; then
    echo "❌ فشل تحميل السكربت الرئيسي"
    exit 1
fi

# تحميل ملفات إضافية
FILES=("azkar.txt" "adhan.ogg" "short_adhan.ogg" "prayer_approaching.ogg")
for file in "${FILES[@]}"; do
    download_file "$file" || echo "  ⚠️ سيتم إنشاء $file لاحقاً"
done

# جعل السكربت قابلاً للتنفيذ
chmod +x "$MAIN_SCRIPT"

# إنشاء رابط رمزي في المسار
echo ""
echo "🔗 إعداد المسار..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/$MAIN_SCRIPT" "$HOME/.local/bin/gtsalat" 2>/dev/null || true

# التأكد من وجود ~/.local/bin في PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo "  إضافة ~/.local/bin إلى PATH..."
    
    # إضافة إلى ملفات shell المختلفة
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            if ! grep -q '.local/bin' "$rc_file"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
                echo "  ✓ تم الإضافة إلى $rc_file"
            fi
        fi
    done
    
    # إضافة إلى fish shell
    if [ -d "$HOME/.config/fish" ]; then
        local fish_config="$HOME/.config/fish/config.fish"
        if [ -f "$fish_config" ]; then
            if ! grep -q '.local/bin' "$fish_config"; then
                echo 'set -gx PATH $HOME/.local/bin $PATH' >> "$fish_config"
                echo "  ✓ تم الإضافة إلى $fish_config"
            fi
        fi
    fi
    
    export PATH="$HOME/.local/bin:$PATH"
fi

# إعداد autostart لأنظمة سطح المكتب
echo ""
echo "🚀 إعداد التشغيل التلقائي..."

setup_autostart() {
    # XDG autostart
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/gt-salat-dikr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GT-salat-dikr Notifications
Name[ar]=إشعارات الصلاة والأذكار
Exec=bash -c 'sleep 10 && export DISPLAY=:0 && export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus && $INSTALL_DIR/$MAIN_SCRIPT --notify-start'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-MATE-Autostart-enabled=true
X-XFCE-autostart-enabled=true
X-LXQt-Need-Tray=false
StartupNotify=false
Terminal=false
Icon=preferences-system-time
Comment=Start prayer times and azkar notifications automatically
Comment[ar]=بدء إشعارات أوقات الصلاة والأذكار تلقائياً
Categories=Utility;
EOF
    echo "  ✓ تم إنشاء XDG autostart"
}

setup_systemd_service() {
    # systemd user service
    if command -v systemctl >/dev/null 2>&1; then
        mkdir -p "$HOME/.config/systemd/user"
        cat > "$HOME/.config/systemd/user/gt-salat-dikr.service" <<EOF
[Unit]
Description=GT-salat-dikr Prayer Times and Azkar Notifications
After=graphical-session.target default.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$MAIN_SCRIPT --child-notify
Restart=always
RestartSec=10
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
Environment="DISPLAY=:0"
Environment="XDG_RUNTIME_DIR=/run/user/%U"

[Install]
WantedBy=default.target
EOF
        
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable gt-salat-dikr.service 2>/dev/null || true
        echo "  ✓ تم إنشاء systemd service"
    fi
}

setup_wm_autostart() {
    # Window Managers autostart
    local wm_configs=(
        "$HOME/.config/i3/config:i3"
        "$HOME/.config/sway/config:Sway" 
        "$HOME/.config/openbox/autostart:Openbox"
        "$HOME/.config/awesome/rc.lua:Awesome"
        "$HOME/.config/bspwm/bspwmrc:bspwm"
        "$HOME/.xinitrc:Xinit"
        "$HOME/.xsession:Xsession"
    )
    
    for config in "${wm_configs[@]}"; do
        local file="${config%%:*}"
        local name="${config#*:}"
        
        case "$name" in
            "i3"|"Sway")
                if [ -f "$file" ]; then
                    if ! grep -q "GT-salat-dikr" "$file"; then
                        echo "" >> "$file"
                        echo "# GT-salat-dikr autostart" >> "$file"
                        if [ "$name" = "i3" ]; then
                            echo "exec --no-startup-id $INSTALL_DIR/$MAIN_SCRIPT --notify-start" >> "$file"
                        else
                            echo "exec $INSTALL_DIR/$MAIN_SCRIPT --notify-start" >> "$file"
                        fi
                        echo "  ✓ تم الإضافة إلى $name"
                    fi
                fi
                ;;
            "Openbox"|"Xsession")
                if [ -f "$file" ]; then
                    if ! grep -q "GT-salat-dikr" "$file"; then
                        echo "" >> "$file"
                        echo "# GT-salat-dikr autostart" >> "$file"
                        echo "$INSTALL_DIR/$MAIN_SCRIPT --notify-start &" >> "$file"
                        echo "  ✓ تم الإضافة إلى $name"
                    fi
                fi
                ;;
            "Awesome")
                if [ -f "$file" ]; then
                    if ! grep -q "GT-salat-dikr" "$file"; then
                        echo "" >> "$file"
                        echo "-- GT-salat-dikr autostart" >> "$file"
                        echo "awful.spawn.with_shell(\"$INSTALL_DIR/$MAIN_SCRIPT --notify-start\")" >> "$file"
                        echo "  ✓ تم الإضافة إلى $name"
                    fi
                fi
                ;;
            "bspwm")
                if [ -f "$file" ]; then
                    if ! grep -q "GT-salat-dikr" "$file"; then
                        echo "" >> "$file"
                        echo "# GT-salat-dikr autostart" >> "$file"
                        echo "$INSTALL_DIR/$MAIN_SCRIPT --notify-start &" >> "$file"
                        echo "  ✓ تم الإضافة إلى $name"
                    fi
                fi
                ;;
            "Xinit")
                if [ -f "$file" ]; then
                    if ! grep -q "GT-salat-dikr" "$file"; then
                        echo "" >> "$file"
                        echo "# GT-salat-dikr autostart" >> "$file"
                        echo "$INSTALL_DIR/$MAIN_SCRIPT --notify-start &" >> "$file"
                        echo "  ✓ تم الإضافة إلى $name"
                    fi
                fi
                ;;
        esac
    done
    
    # LXDE/LXQt
    for lxde_file in "$HOME/.config/lxsession/LXDE/autostart" \
                     "$HOME/.config/lxsession/Lubuntu/autostart" \
                     "$HOME/.config/lxqt/session.conf"; do
        if [ -f "$lxde_file" ]; then
            if ! grep -q "GT-salat-dikr" "$lxde_file"; then
                echo "" >> "$lxde_file"
                echo "@$INSTALL_DIR/$MAIN_SCRIPT --notify-start" >> "$lxde_file"
                echo "  ✓ تم الإضافة إلى LXDE/LXQt"
                break
            fi
        fi
    done
}

setup_autostart
setup_systemd_service
setup_wm_autostart

# إعداد عرض الذكر عند فتح الطرفية
echo ""
echo "📝 إعداد عرض الذكر عند فتح الطرفية..."

setup_shell_integration() {
    local added=false
    
    # دعم Shells المختلفة
    add_to_shell() {
        local rc_file="$1"
        local line="$2"
        
        if [ -f "$rc_file" ]; then
            if ! grep -Fq "$INSTALL_DIR/$MAIN_SCRIPT" "$rc_file"; then
                echo "" >> "$rc_file"
                echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$rc_file"
                echo "$line" >> "$rc_file"
                added=true
                echo "  ✓ تم الإضافة إلى $rc_file"
            fi
        fi
    }
    
    # Bash, Zsh, Ksh, etc.
    add_to_shell "$HOME/.bashrc" "\"$INSTALL_DIR/$MAIN_SCRIPT\""
    add_to_shell "$HOME/.zshrc" "\"$INSTALL_DIR/$MAIN_SCRIPT\""
    add_to_shell "$HOME/.profile" "\"$INSTALL_DIR/$MAIN_SCRIPT\""
    add_to_shell "$HOME/.kshrc" "\"$INSTALL_DIR/$MAIN_SCRIPT\""
    
    # C Shell
    if [ -f "$HOME/.cshrc" ]; then
        if ! grep -q "GT-salat-dikr" "$HOME/.cshrc"; then
            echo "" >> "$HOME/.cshrc"
            echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$HOME/.cshrc"
            echo "\"$INSTALL_DIR/$MAIN_SCRIPT\"" >> "$HOME/.cshrc"
            added=true
            echo "  ✓ تم الإضافة إلى .cshrc"
        fi
    fi
    
    # Fish Shell
    if [ -d "$HOME/.config/fish" ]; then
        local fish_config="$HOME/.config/fish/config.fish"
        if [ -f "$fish_config" ]; then
            if ! grep -q "GT-salat-dikr" "$fish_config"; then
                echo "" >> "$fish_config"
                echo "# GT-salat-dikr: ذكر وصلاة عند فتح الطرفية" >> "$fish_config"
                echo "if test -f \$HOME/.GT-salat-dikr/gt-salat-dikr.sh" >> "$fish_config"
                echo "    \$HOME/.GT-salat-dikr/gt-salat-dikr.sh 2>/dev/null" >> "$fish_config"
                echo "end" >> "$fish_config"
                added=true
                echo "  ✓ تم الإضافة إلى Fish shell"
            fi
        fi
    fi
    
    if [ "$added" = true ]; then
        echo "  ✅ تم إضافة عرض الذكر ووقت الصلاة عند فتح الطرفية"
    fi
}

setup_shell_integration

# تشغيل الإعداد الأولي
echo ""
echo "⚙️  تشغيل الإعداد الأولي..."

# استخدام السكربت الرئيسي للإعداد
if "$INSTALL_DIR/$MAIN_SCRIPT" --settings; then
    echo "  ✅ تم الإعداد بنجاح"
else
    echo "  ⚠️  حدث خطأ أثناء الإعداد - يمكنك تشغيل 'gtsalat --settings' لاحقاً"
fi

# بدء الإشعارات
echo ""
echo "🔔 بدء الإشعارات..."
if "$INSTALL_DIR/$MAIN_SCRIPT" --notify-start; then
    echo "  ✅ تم بدء الإشعارات"
else
    echo "  ⚠️  فشل بدء الإشعارات - يمكنك تشغيل 'gtsalat --notify-start' لاحقاً"
fi

# عرض ملخص التثبيت
echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 تم تثبيت GT-salat-dikr بنجاح!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📁 مجلد التثبيت: $INSTALL_DIR"
echo "🔧 الأمر: gtsalat"
echo ""
echo "🚀 الميزات المثبتة:"
echo "   ✓ الإشعارات التلقائية للأذكار"
echo "   ✓ تنبيهات أوقات الصلاة"
echo "   ✓ الأذان عند دخول وقت الصلاة"
echo "   ✓ التشغيل التلقائي عند بدء النظام"
echo "   ✓ عرض الذكر ووقت الصلاة عند فتح الطرفية"
echo ""
echo "🔧 الأوامر المتاحة:"
echo "   gtsalat --help          عرض جميع الأوامر"
echo "   gtsalat --settings      تعديل الإعدادات"
echo "   gtsalat --status        عرض حالة البرنامج"
echo "   gtsalat --logs          عرض سجل التشغيل"
echo ""
echo "💡 سيبدأ البرنامج تلقائياً عند إعادة تشغيل النظام"
echo "   يمكنك إعادة فتح الطرفية لتطبيق التغييرات"
echo ""
echo "📖 للمساعدة: gtsalat --help"
echo "════════════════════════════════════════════════════════"

# اختبار التشغيل
echo ""
read -p "هل تريد اختبار التشغيل الآن؟ [Y/n]: " test_run
if [[ "${test_run:-Y}" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🧪 اختبار التشغيل..."
    if "$INSTALL_DIR/$MAIN_SCRIPT"; then
        echo "✅ الاختبار نجح!"
    else
        echo "⚠️  حدث خطأ أثناء الاختبار"
    fi
fi

echo ""
echo "✨ التثبيت اكتمل بنجاح!"
