#!/usr/bin/env python3
"""
GT-salat-dikr - System Tray Icon المحسن
إصدار يعمل بكفاءة مع جميع البيئات
"""

import os
import sys
import subprocess
import threading
import time
import tempfile
from pathlib import Path

# إضافة المسار للوحدات
INSTALL_DIR = os.path.expanduser("~/.GT-salat-dikr")
sys.path.insert(0, INSTALL_DIR)

try:
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    LIBRARIES_AVAILABLE = True
except ImportError as e:
    print(f"❌ المكتبات المطلوبة غير مثبتة: {e}")
    print("\n💡 قم بتثبيت الحزم المطلوبة:")
    print("   pip install --user pystray pillow")
    LIBRARIES_AVAILABLE = False
    sys.exit(1)

class PrayerTray:
    def __init__(self):
        self.icon = None
        self.install_dir = INSTALL_DIR
        self.main_script = os.path.join(self.install_dir, "gt-salat-dikr.sh")
        self.icon_dir = os.path.join(self.install_dir, "icons")
        
    def run_cmd_direct(self, cmd):
        """تشغيل أمر مباشر وعرض النتيجة"""
        try:
            result = subprocess.run(
                cmd, 
                shell=True, 
                cwd=self.install_dir,
                capture_output=True, 
                text=True,
                timeout=10
            )
            
            if result.stdout:
                print("=" * 50)
                print(result.stdout)
                print("=" * 50)
            
            return True
        except Exception as e:
            print(f"⚠️  خطأ: {e}")
            return False
    
    def run_cmd_in_terminal(self, cmd, title="GT-salat-dikr"):
        """تشغيل أمر في terminal جديد"""
        try:
            # إنشاء سكربت مؤقت
            script_content = f"""#!/bin/bash
echo "{title}"
echo "══════════════════════════════════════════════════"
cd "{self.install_dir}"
{cmd}
echo ""
echo "══════════════════════════════════════════════════"
read -p "اضغط Enter للإغلاق... "
"""
            
            script_file = tempfile.NamedTemporaryFile(
                mode='w', 
                suffix='.sh', 
                delete=False
            )
            script_file.write(script_content)
            script_file.close()
            os.chmod(script_file.name, 0o755)
            
            # تشغيل في terminal
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
            subprocess.Popen(['bash', script_file.name], start_new_session=True)
            return True
            
        except Exception as e:
            print(f"❌ خطأ في فتح terminal: {e}")
            # محاولة مباشرة
            return self.run_cmd_direct(cmd)
    
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
    
    def load_icon(self):
        """تحميل الأيقونة"""
        icon_paths = [
            os.path.join(self.icon_dir, "prayer-icon-32.png"),
            os.path.join(self.icon_dir, "prayer-icon-64.png"),
            os.path.join(self.icon_dir, "icon.png"),
        ]
        
        for path in icon_paths:
            if os.path.exists(path):
                try:
                    return Image.open(path)
                except:
                    continue
        
        # إنشاء أيقونة افتراضية
        img = Image.new('RGBA', (32, 32), (255, 255, 255, 0))
        draw = ImageDraw.Draw(img)
        
        # تصميم بسيط
        draw.rectangle([8, 20, 24, 26], fill=(46, 125, 50))
        draw.rectangle([10, 14, 22, 20], fill=(56, 142, 60))
        draw.ellipse([10, 6, 22, 14], fill=(33, 97, 140))
        draw.arc([14, 8, 18, 12], 30, 150, fill=(255, 235, 59), width=2)
        
        return img
    
    def create_menu(self):
        """إنشاء القائمة - إصدار مبسط"""
        next_prayer = self.get_next_prayer()
        
        menu_items = []
        
        # العنوان
        menu_items.append(MenuItem("🕌 GT-salat-dikr", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        
        # الصلاة القادمة
        menu_items.append(MenuItem(f"⏰ {next_prayer}", None, enabled=False))
        menu_items.append(MenuItem("", None, enabled=False))
        
        # الأوامر الأساسية
        menu_items.append(MenuItem("📊 مواقيت اليوم", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --show-timetable", "مواقيت الصلاة")))
        
        menu_items.append(MenuItem("🕊️  إظهار ذكر", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh", "ذكر اليوم")))
        
        menu_items.append(MenuItem("📈 حالة البرنامج", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --status", "حالة البرنامج")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        
        # التحكم
        menu_items.append(MenuItem("⚙️  الإعدادات", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --settings", "الإعدادات")))
        
        menu_items.append(MenuItem("🔄 تحديث المواقيت", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --update-timetables", "تحديث المواقيت")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        
        # الإشعارات
        menu_items.append(MenuItem("🔔 الإشعارات:", None, enabled=False))
        menu_items.append(MenuItem("  ▶️  تشغيل", 
            lambda: self.run_cmd_direct("./gt-salat-dikr.sh --notify-start")))
        menu_items.append(MenuItem("  ⏸️  إيقاف", 
            lambda: self.run_cmd_direct("./gt-salat-dikr.sh --notify-stop")))
        
        menu_items.append(MenuItem("", None, enabled=False))
        
        # إدارة الأيقونة
        menu_items.append(MenuItem("🖥️  الأيقونة:", None, enabled=False))
        menu_items.append(MenuItem("  🔄 إعادة تشغيل", lambda: self.restart()))
        menu_items.append(MenuItem("  ❌ إغلاق", lambda: self.icon.stop()))
        
        menu_items.append(MenuItem("", None, enabled=False))
        menu_items.append(MenuItem("══════════════════", None, enabled=False))
        menu_items.append(MenuItem("❓ المساعدة", 
            lambda: self.run_cmd_in_terminal("./gt-salat-dikr.sh --help", "مساعدة")))
        
        return Menu(*menu_items)
    
    def restart(self):
        """إعادة تشغيل الأيقونة"""
        print("🔄 إعادة تشغيل الأيقونة...")
        if self.icon:
            self.icon.stop()
        time.sleep(1)
        os.execv(sys.executable, [sys.executable] + sys.argv)
    
    def update_tooltip(self):
        """تحديث التلميح"""
        while True:
            if self.icon and hasattr(self.icon, 'visible') and self.icon.visible:
                try:
                    prayer = self.get_next_prayer()
                    self.icon.title = f"GT-salat-dikr\n{prayer}"
                except:
                    pass
            time.sleep(30)
    
    def run(self):
        """تشغيل الأيقونة"""
        print("🚀 بدء أيقونة System Tray...")
        print("📌 الأيقونة في شريط المهام")
        print("🖱️  انقر بزر الماوس الأيمن للقائمة")
        
        icon_image = self.load_icon()
        self.icon = Icon(
            "gt_salat_dikr",
            icon_image,
            "GT-salat-dikr - تذكير الصلاة والأذكار",
            self.create_menu()
        )
        
        updater = threading.Thread(target=self.update_tooltip, daemon=True)
        updater.start()
        
        try:
            self.icon.run()
        except KeyboardInterrupt:
            print("\n✅ تم الإغلاق")
        except Exception as e:
            print(f"❌ خطأ: {e}")

def main():
    if not LIBRARIES_AVAILABLE:
        print("❌ لا يمكن تشغيل System Tray - المكتبات غير مثبتة")
        return 1
    
    if not os.path.exists(os.path.expanduser("~/.GT-salat-dikr/gt-salat-dikr.sh")):
        print("❌ البرنامج الرئيسي غير مثبت")
        print("💡 قم بتشغيل install.sh أولاً")
        return 1
    
    tray = PrayerTray()
    tray.run()
    return 0

if __name__ == "__main__":
    sys.exit(main())
