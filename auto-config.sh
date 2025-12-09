#!/bin/bash
# auto-config.sh - تفعيل الإعدادات الافتراضية تلقائياً

set -e

echo "⚙️  تطبيق الإعدادات الافتراضية التلقائية..."

# تحديد مسار التثبيت
if [ -d "/opt/gt-salat-dikr" ]; then
    CONFIG_DIR="/opt/gt-salat-dikr"
elif [ -d "$HOME/.GT-salat-dikr" ]; then
    CONFIG_DIR="$HOME/.GT-salat-dikr"
else
    CONFIG_DIR="$HOME/.GT-salat-dikr"
fi

# إنشاء دليل التهيئة
mkdir -p "$CONFIG_DIR/config"

# 1. تحديد نظام الإشعارات الافتراضي بناءً على التوزيعة
echo "🔔 تحديد نظام الإشعارات الافتراضي..."

if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
    NOTIFY_SYSTEM="systemd"
elif command -v initctl >/dev/null 2>&1; then
    NOTIFY_SYSTEM="upstart"
elif [ -d "/etc/init.d" ]; then
    NOTIFY_SYSTEM="sysvinit"
else
    NOTIFY_SYSTEM="systemd"  # الافتراضي
fi

# 2. إنشاء ملف التكوين الرئيسي مع الإعدادات المفعلة
echo "📝 إنشاء ملف التكوين التلقائي..."

cat > "$CONFIG_DIR/config/auto-config.json" << EOF
{
    "settings": {
        "auto_start": true,
        "notifications_enabled": true,
        "auto_update_timetables": true,
        "offline_mode": true,
        "auto_update_program": false,
        "reminder_before_prayer": 15,
        "azkar_interval": 10,
        "adhan_type": "full",
        "notify_system": "$NOTIFY_SYSTEM",
        "enable_terminal_notify": true,
        "enable_gui_notify": true,
        "enable_sound": true,
        "enable_approaching_notify": true
    },
    "location": {
        "auto_detect": true,
        "manual_override": false
    },
    "calculation_method": {
        "method": "UmmAlQura",
        "auto_select": true
    },
    "storage": {
        "cache_duration": 90,
        "auto_cleanup": true
    }
}
EOF

# 3. إنشاء ملفات الخدمة التلقائية
echo "🛠️  إعداد خدمات التشغيل التلقائي..."

# لـ systemd
if [ "$NOTIFY_SYSTEM" = "systemd" ]; then
    cat > /tmp/gt-salat-dikr.service << EOF
[Unit]
Description=GT-salat-dikr Prayer Notifications
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/gtsalat --notify-start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/gt-salat-dikr.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable gt-salat-dikr.service
    echo "✅ تم تفعيل خدمة systemd"
fi

# لـ sysvinit
if [ "$NOTIFY_SYSTEM" = "sysvinit" ]; then
    cat > /etc/init.d/gt-salat-dikr << EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          gt-salat-dikr
# Required-Start:    \$local_fs \$network
# Required-Stop:     \$local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: GT-salat-dikr Prayer Notifications
# Description:       Islamic prayer times and azkar notifications
### END INIT INFO

case "\$1" in
    start)
        /usr/local/bin/gtsalat --notify-start &
        ;;
    stop)
        /usr/local/bin/gtsalat --notify-stop
        ;;
    restart)
        /usr/local/bin/gtsalat --notify-stop
        sleep 2
        /usr/local/bin/gtsalat --notify-start &
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
EOF
    
    chmod +x /etc/init.d/gt-salat-dikr
    update-rc.d gt-salat-dikr defaults
    echo "✅ تم تفعيل خدمة sysvinit"
fi

# 4. إنشاء سكريبت تحديث شامل
echo "📦 إنشاء سكريبت التحديث الشامل..."

cat > "$CONFIG_DIR/update-all.sh" << 'EOF'
#!/bin/bash
# تحديث شامل لجميع مكونات GT-salat-dikr

set -e

echo "🔄 بدء التحديث الشامل..."

# تحديث البرنامج الرئيسي
if command -v gtsalat >/dev/null 2>&1; then
    echo "📦 تحديث البرنامج الرئيسي..."
    gtsalat --self-update
fi

# تحديث ملفات Python
echo "🐍 تحديث ملفات Python..."
if [ -f "/opt/gt-salat-dikr/gt-tray.py" ]; then
    curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/gt-tray.py" \
        -o "/opt/gt-salat-dikr/gt-tray.py"
fi

# تحديث سكريبتات التثبيت
echo "🔧 تحديث سكريبتات التثبيت..."
SCRIPTS=("install.sh" "uninstall.sh" "install-python-deps.sh" "install-system-tray.sh")
for script in "${SCRIPTS[@]}"; do
    curl -fsSL "https://raw.githubusercontent.com/SalehGNUTUX/GT-salat-dikr/main/$script" \
        -o "/tmp/$script"
    if [ -f "/tmp/$script" ]; then
        chmod +x "/tmp/$script"
        sudo mv "/tmp/$script" "/opt/gt-salat-dikr/$script"
    fi
done

# تحديث مواقيت الصلاة
echo "🕌 تحديث مواقيت الصلاة..."
if command -v gtsalat >/dev/null 2>&1; then
    gtsalat --update-timetables
fi

# تحديث الأذكار
echo "📖 تحديث الأذكار..."
if command -v gtsalat >/dev/null 2>&1; then
    gtsalat --update-azkar
fi

echo "✅ تم التحديث الشامل بنجاح!"
EOF

chmod +x "$CONFIG_DIR/update-all.sh"

# 5. إنشاء ملف تهيئة للمستخدم
echo "👤 إنشاء إعدادات أولية للمستخدم..."

cat > "$HOME/.gt-salat-dikr-user" << EOF
# إعدادات المستخدم لـ GT-salat-dikr
# تم إنشاؤها تلقائياً في $(date)

USER_INITIAL_SETUP=true
FIRST_RUN_COMPLETED=false
LOCATION_CONFIRMED=false
METHOD_SELECTED=false

# سيتم تحديث هذه القيم تلقائياً عند:
# 1. تأكيد الموقع
# 2. اختيار طريقة الحساب
EOF

echo ""
echo "✅ تم تطبيق الإعدادات التلقائية بنجاح!"
echo ""
echo "📋 ملخص الإعدادات المفعّلة تلقائياً:"
echo "   ✓ نظام إشعارات: $NOTIFY_SYSTEM"
echo "   ✓ التشغيل التلقائي عند بدء النظام"
echo "   ✓ التحديث التلقائي لمواقيت الصلاة (مع وضع عدم الاتصال)"
echo "   ✓ فاصل الأذكار: 10 دقائق"
echo "   ✓ تنبيه قبل الصلاة: 15 دقيقة"
echo "   ✓ تفعيل جميع أنواع الإشعارات"
echo "   ✓ تحديث البرنامج: معطل (يمكن تفعيله يدوياً)"
echo ""
echo "📍 الخطوات التالية:"
echo "   1. تشغيل gtsalat لتأكيد الموقع"
echo "   2. اختيار طريقة الحساب المناسبة"
echo ""
echo "🔧 للتحديث الشامل:"
echo "   bash $CONFIG_DIR/update-all.sh"
