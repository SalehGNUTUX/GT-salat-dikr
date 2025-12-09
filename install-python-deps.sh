#!/bin/bash
# تثبيت تبعيات Python لأيقونة System Tray

echo "🔍 الكشف عن توزيعة النظام..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO=$(uname -s)
fi

echo "📦 التوزيعة: $DISTRO"

case $DISTRO in
    arch|manjaro)
        echo "🔧 تثبيت الحزم لـ Arch/Manjaro..."
        sudo pacman -Sy --noconfirm python-pystray python-pillow
        ;;
    debian|ubuntu|linuxmint)
        echo "🔧 تثبيت الحزم لـ Debian/Ubuntu..."
        sudo apt update
        sudo apt install -y python3-pystray python3-pil
        ;;
    fedora|rhel|centos)
        echo "🔧 تثبيت الحزم لـ Fedora/RHEL..."
        sudo dnf install -y python3-pystray python3-pillow
        ;;
    *)
        echo "⚠️  توزيعة غير معروفة، استخدام pip..."
        pip install --user pystray pillow
        ;;
esac

echo "✅ تم التثبيت"
