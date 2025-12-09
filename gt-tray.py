#!/usr/bin/env python3
"""
GT-salat-dikr - System Tray Icon النسخة المحسنة
إصدار يعمل بكفاءة مع جميع بيئات سطح المكتب
"""

import os
import sys
import subprocess
import threading
import time
import tempfile
from datetime import datetime
from pathlib import Path

# إضافة المسار للوحدات
INSTALL_DIR = os.path.expanduser("~/.GT-salat-dikr")
sys.path.insert(0, INSTALL_DIR)

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw, ImageFont
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"❌ المكتبات المطلوبة غير مثبتة: {e}")
    print("\n💡 قم بتثبيت الحزم المطلوبة:")
    print("   Arch: sudo pacman -S python-pystray python-pillow")
    print("   Ubuntu: sudo apt install python3-pystray python3-pil")
    print("   أو باستخدام pip: pip install --user pystray pillow")
    LIBRARIES_AVAILABLE = False
    sys.exit(1)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = INSTALL_DIR
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")
        self.icon_dir = os.path.join(self.install_dir, "icons")
        
        # إعدادات
        self.config_file = os.path.join(self.install_dir, "settings.conf")
        self.config = self.load_config()
    
    def load_config(self):
        """تحميل الإعدادات من الملف"""
        config = {}
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        # إزالة الاقتباس
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1]
                        config[key] = value
        except:
            pass
        return config
    
    def run_command(self, cmd, use_terminal=True):
        """تشغيل أمر"""
        try:
            if use_terminal:
                # إنشاء سكربت مؤقت
                script_content = f"""#!/bin/bash
cd "{self.install_dir}"
echo "════════════════════════════════════════════════════════"
echo "   GT-salat-dikr - تشغيل من System Tray"
echo "════════════════════════════════════════════════════════"
echo ""
{cmd}
echo ""
echo "════════════════════════════════════════════════════════"
read -p "اضغط Enter للإغلاق... "
"""
                
                script_file = tempfile.NamedTemporaryFile(
                    mode='w', 
                    suffix='.sh', 
                    delete=False,
                    encoding='utf-8'
                )
                script_file.write(script_content)
                script_file.close()
                os.chmod(script_file.name, 0o755)
                
                # محاولة استخدام terminal متوفر
                terminals = [
                    ('gnome-terminal', ['--', 'bash', script_file.name]),
                    ('konsole', ['-e', 'bash', script_file.name]),
                    ('xfce4-terminal', ['-e', 'bash', script_file.name]),
                    ('mate-terminal', ['-e', 'bash', script_file.name]),
                    ('xterm', ['-e', 'bash', script_file.name]),
                    ('terminator', ['-e', 'bash', script_file.name]),
                ]
                
                for terminal, args in terminals:
                    if subprocess.run(['which', terminal], capture_output=True).returncode == 0:
                        subprocess.Popen([terminal] + args, start_new_session=True)
                        return True
                
                # إذا لم يعثر على terminal، تشغيل مباشر
                result = subprocess.run(['bash', script_file.name], capture_output=True, text=True)
                if result.stdout:
                    print(result.stdout)
                return True
                
            else:
                # تشغيل في الخلفية بدون terminal
                subprocess.Popen(cmd, shell=True, start_new_session=True, cwd=self.install_dir)
                return True
                
        except Exception as e:
            print(f"⚠️  خطأ في تشغيل الأمر: {e}")
            return False
    
    def get_prayer_times(self):
        """الحصول على مواقيت الصلاة"""
        try:
            result = subprocess.run(
                [self.main_script, "--show-timetable"],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            if result.returncode == 0:
                return result.stdout
        except:
            pass
        return "مواقيت الصلاة اليوم:\nالفجر: 06:00\nالظهر: 12:00\nالعصر: 15:00\nالمغرب: 18:00\nالعشاء: 19:00"
    
    def get_next_prayer(self):
        """الحصول على الصلاة القادمة"""
        try:
            result = subprocess.run(
                [self.main_script],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=self.install_dir
            )
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'الصلاة القادمة:' in line:
                        return line.strip()
        except:
            pass
        return "الصلاة القادمة: جاري التحديث..."
    
    def get_location_info(self):
        """الحصول على معلومات الموقع"""
        city = self.config.get('CITY', 'غير محدد')
        country = self.config.get('COUNTRY', 'غير محدد')
        return f"{city}, {country}"
    
    def load_icon_image(self):
        """تحميل صورة الأيقونة"""
        # محاولة تحميل الأيقونة المحفوظة
        icon_sizes = [32, 64, 128]
        
        for size in icon_sizes:
            icon_path = os.path.join(self.icon_dir, f"prayer-icon-{size}.png")
            if os.path.exists(icon_path):
                try:
                    img = Image.open(icon_path)
                    # تغيير الحجم إذا لزم
                    if img.size[0] != 32 or img.size[1] != 32:
                        img = img.resize((32, 32), Image.Resampling.LANCZOS)
                    return img
                except Exception as e:
                    print(f"⚠️  خطأ في تحميل الأيقونة {icon_path}: {e}")
                    continue
        
        # إنشاء أيقونة افتراضية
        print("🔨 إنشاء أيقونة افتراضية...")
        image = Image.new('RGBA', (32, 32), (255, 255, 255, 0))
        draw = ImageDraw.Draw(image)
        
        # ألوان جميلة
        green_dark = (46, 125, 50)
        green_light = (56, 142, 60)
        blue = (33, 97, 140)
        yellow = (255, 235, 59)
        
        # رسم تصميم جميل
        # قاعدة المسجد
        draw.rectangle([8, 20, 24, 26], fill=green_dark)
        # جدار المسجد
        draw.rectangle([10, 14, 22, 20], fill=green_light)
        # قبة المسجد
        draw.ellipse([10, 6, 22, 14], fill=blue)
        # هلال
        draw.arc([14, 8, 18, 12], 30, 150, fill=yellow, width=2)
        # نجمة صغيرة
        draw.regular_polygon((16, 12), 3, 4, fill=yellow, rotation=30)
        
        return image
    
    def create_menu(self):
        """إنشاء قائمة النظام"""
        next_prayer = self.get_next_prayer()
        location = self.get_location_info()
        
        menu_items = []
        
        # معلومات البرنامج
        menu_items.append(MenuItem("🕌 GT-salat-dikr v3.2", None, enabled=False))
        menu_items.append(MenuItem(f"📍 {location}", None, enabled=False))
        menu_items.append(MenuItem("══════════════════════", None, enabled=False))
        
        # الصلاة القادمة
        menu_items.append(MenuItem(f"⏰ {next_prayer}", None, enabled=False))
        menu_items.append(MenuItem("", None, enabled=False))
        
        # الأوامر الأساسية
        menu_items.append(MenuItem("📊 مواقيت اليوم", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --show-timetable")))
        
        menu_items.append(MenuItem("🕊️  إظهار ذكر", 
            lambda: self.run_command(f"./gt-salat-dikr.sh")))
        
        menu_items.append(MenuItem("📈 حالة البرنامج", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --status")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════════", None, enabled=False))
        
        # التحكم
        menu_items.append(MenuItem("⚙️  الإعدادات", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --settings")))
        
        menu_items.append(MenuItem("🔄 تحديث المواقيت", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --update-timetables")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        
        # الإشعارات
        menu_items.append(MenuItem("🔔 التحكم بالإشعارات:", None, enabled=False))
        menu_items.append(MenuItem("  ▶️  تشغيل الإشعارات", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --notify-start", False)))
        menu_items.append(MenuItem("  ⏸️  إيقاف الإشعارات", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --notify-stop", False)))
        
        menu_items.append(MenuItem("", None, enabled=False))
        
        # إدارة الأيقونة
        menu_items.append(MenuItem("🖥️  إدارة الأيقونة:", None, enabled=False))
        menu_items.append(MenuItem("  🔄 إعادة تشغيل الأيقونة", lambda: self.restart_tray()))
        menu_items.append(MenuItem("  ❌ إغلاق الأيقونة", lambda: self.icon.stop()))
        
        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════════", None, enabled=False))
        menu_items.append(MenuItem("❓ المساعدة", 
            lambda: self.run_command(f"./gt-salat-dikr.sh --help")))
        
        return Menu(*menu_items)
    
    def restart_tray(self):
        """إعادة تشغيل الأيقونة"""
        print("🔄 إعادة تشغيل الأيقونة...")
        if self.icon:
            self.icon.stop()
        time.sleep(1)
        os.execv(sys.executable, [sys.executable] + sys.argv)
    
    def update_tooltip(self):
        """تحديث التلميح تلقائياً"""
        while True:
            if self.icon and hasattr(self.icon, 'visible') and self.icon.visible:
                try:
                    next_prayer = self.get_next_prayer()
                    location = self.get_location_info()
                    self.icon.title = f"GT-salat-dikr\n{location}\n{next_prayer}"
                except:
                    pass
            time.sleep(60)  # تحديث كل دقيقة
    
    def run(self):
        """تشغيل الأيقونة"""
        print("🚀 تشغيل أيقونة شريط المهام...")
        print("📌 الأيقونة في منطقة الإشعارات (بجانب الساعة)")
        print("🖱️  انقر بزر الماوس الأيمن للقائمة الكاملة")
        print("💡 قد يستغرق ظهور الأيقونة بضع ثواني")
        
        # تحميل الأيقونة
        icon_image = self.load_icon_image()
        
        # إنشاء الأيقونة
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr - تذكير الصلاة والأذكار",
            self.create_menu()
        )
        
        # بدء تحديث التلميح
        updater = threading.Thread(target=self.update_tooltip, daemon=True)
        updater.start()
        
        # تشغيل الأيقونة
        try:
            self.icon.run()
        except KeyboardInterrupt:
            print("\n✅ تم الإغلاق بواسطة المستخدم")
        except Exception as e:
            print(f"❌ خطأ في تشغيل الأيقونة: {e}")

def main():
    """الدالة الرئيسية"""
    if not LIBRARIES_AVAILABLE:
        print("❌ لا يمكن تشغيل System Tray - المكتبات غير مثبتة")
        print("💡 قم بتثبيت المكتبات أولاً")
        return 1
    
    # التأكد من وجود البرنامج الرئيسي
    if not os.path.exists(os.path.expanduser("~/.GT-salat-dikr/gt-salat-dikr.sh")):
        print("❌ البرنامج الرئيسي غير مثبت")
        print("💡 قم بتشغيل install.sh أولاً")
        return 1
    
    # تشغيل الأيقونة
    tray = PrayerTray()
    tray.run()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
