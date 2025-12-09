#!/bin/bash
# تثبيت تبعيات Python لأيقونة System Tray
# يدعم التشغيل عن بعد ومحلياً

set -e  # إيقاف عند أي خطأ

echo "🔍 الكشف عن توزيعة النظام..."

# دالة لفحص وتثبيت Python
install_python_if_needed() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "📦 تثبيت Python3..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3 python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm python python-pip
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3 python3-pip
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y python3 python3-pip
        else
            echo "⚠️  لم يتم العثور على مدير حزم معروف"
            echo "📦 سيتم استخدام pip مباشرة..."
        fi
    fi
}

# دالة تثبيت المكتبات بناءً على التوزيعة
install_dependencies() {
    local distro=$1
    
    echo "📦 تثبيت مكتبات Python لـ $distro..."
    
    case $distro in
        arch|manjaro|endeavouros)
            sudo pacman -Sy --noconfirm python-pystray python-pillow python-requests
            ;;
        debian|ubuntu|linuxmint|pop|zorin|elementary)
            sudo apt update
            sudo apt install -y python3-pystray python3-pil python3-requests
            ;;
        fedora|rhel|centos|almalinux|rocky)
            sudo dnf install -y python3-pystray python3-pillow python3-requests
            ;;
        opensuse*|suse)
            sudo zypper install -y python3-pystray python3-Pillow python3-requests
            ;;
        *)
            echo "📦 استخدام pip للتثبيت..."
            pip3 install --user pystray pillow requests
            ;;
    esac
}

# الكشف عن التوزيعة
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
elif type lsb_release >/dev/null 2>&1; then
    DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
else
    DISTRO=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

echo "📦 التوزيعة المكتشفة: $DISTRO"

# تثبيت Python إذا لم يكن موجوداً
install_python_if_needed

# تثبيت التبعيات
install_dependencies "$DISTRO"

# التحقق من التثبيت
echo "🔍 التحقق من التثبيت..."
if python3 -c "import pystray, PIL, requests" 2>/dev/null; then
    echo "✅ تم تثبيت جميع المكتبات بنجاح"
else
    echo "⚠️  محاولة التثبيت عبر pip..."
    pip3 install --user pystray pillow requests
fi

echo "✅ تم إعداد بيئة Python بنجاح!"
